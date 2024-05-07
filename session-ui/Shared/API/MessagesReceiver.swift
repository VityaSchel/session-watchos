import Foundation
import Sodium
import CoreData

enum MessagesReceiverError: Error {
  case noMnemonic
  case noSnodes
  case noSwarms
  case signingFailed
  case invalidMessage
  case noData
  case unsupportedEnvelopeType
  case decryptionFailed
  case invalidSignature
}

class MessagesReceiver {
  var snode: ServiceNode
  var swarm: Swarm
  var identity: (ed25519KeyPair: KeyPair, x25519KeyPair: KeyPair)
  var context: NSManagedObjectContext
  
  init(seed: Data, context: NSManagedObjectContext) async throws {
    let identity = try Identity.generate(from: seed)
    self.identity = identity
    let snodes = try await SeedNodes.getSnodes()
    guard let snode = snodes.randomElement() else {
      throw MessagesReceiverError.noSnodes
    }
    self.snode = snode
    let swarms = try await snode.getSwarmsFor(pubkey: identity.x25519KeyPair.hexEncodedPublicKey)
    guard let swarm = swarms.randomElement() else {
      throw MessagesReceiverError.noSwarms
    }
    self.swarm = swarm
    self.context = context
  }
  
  private func generateSignature(timestamp: UInt64, namespace: Namespace) throws -> [UInt8] {
    let verificationBytes: [UInt8] = "retrieve".bytes
      .appending(contentsOf: namespace.verificationString.bytes)
      .appending(contentsOf: String(timestamp).data(using: .ascii)?.bytes)
    
    let sodium = Sodium()
    
    guard
      let signatureBytes: [UInt8] = sodium.sign.signature(
        message: verificationBytes,
        secretKey: self.identity.ed25519KeyPair.secretKey
      )
    else {
      throw MessagesReceiverError.signingFailed
    }
    
    return signatureBytes
  }
  
  func poll() async throws -> Bool {
    let namespace = Namespace.default
    let timestampMs: UInt64 = UInt64(Date().timeIntervalSince1970 * 1000)
    let signature = try self.generateSignature(timestamp: timestampMs, namespace: namespace)
    
    let messages = try await swarm.retrieveMessages(
      namespace: namespace,
      pubkey: self.identity.x25519KeyPair.hexEncodedPublicKey,
      pubkeyEd25519: self.identity.ed25519KeyPair.hexEncodedPublicKey.removingIdPrefixIfNeeded(),
      signature: signature.toBase64(),
      signatureTimestamp: timestampMs,
      lastHash: nil
    )
    messages.forEach({ message in
      let request: NSFetchRequest<SeenMessage> = SeenMessage.fetchSeenPolled()
      if let seenMessage = try! context.fetch(request).first {} else {
        do {
          try handleNewMessage(message)
        } catch let error {
          print("Error while parsing new message", error)
        }
      }
    })
    return true
  }
  
  private func handleNewMessage(_ receivedMessage: PolledMessage) throws {
    print("New message!", receivedMessage.hash)
    
    let seenMessage = SeenMessage(context: context)
    seenMessage.messageHash = receivedMessage.hash
    seenMessage.timestamp = Int64(Date().timeIntervalSince1970 * 1000)
    saveContext(context: context)
    
    guard let dataBytes = Data(base64Encoded: receivedMessage.data) else {
      throw MessagesReceiverError.invalidMessage
    }
    guard let envelope = try SNProtoEnvelope.from(dataBytes) else {
      throw MessagesReceiverError.invalidMessage
    }
    guard let ciphertext = envelope.content else {
      throw MessagesReceiverError.noData
    }
    
    var plaintext: Data
    var sender: String
    
    switch envelope.type {
    case .sessionMessage:
      // Default to 'standard' as the old code didn't seem to require an `envelope.source`
      switch (SessionId.Prefix(from: envelope.source) ?? .standard) {
      case .standard, .unblinded:
        let userX25519KeyPair = self.identity.x25519KeyPair
        (plaintext, sender) = try MessagesReceiver.decryptWithSessionProtocol(ciphertext: ciphertext, using: userX25519KeyPair)
        
      case .blinded15, .blinded25:
        throw MessagesReceiverError.unsupportedEnvelopeType
        //        guard let otherBlindedPublicKey: String = otherBlindedPublicKey else {
        //          throw MessageSenderError.noData
        //        }
        //        guard let openGroupServerPublicKey: String = openGroupServerPublicKey else {
        //          throw MessageReceiverError.invalidGroupPublicKey
        //        }
        //        guard let userEd25519KeyPair: KeyPair = Identity.fetchUserEd25519KeyPair(db) else {
        //          throw MessageReceiverError.noUserED25519KeyPair
        //        }
        
        //        (plaintext, sender) = try decryptWithSessionBlindingProtocol(
        //          data: ciphertext,
        //          isOutgoing: (isOutgoing == true),
        //          otherBlindedPublicKey: otherBlindedPublicKey,
        //          with: openGroupServerPublicKey,
        //          userEd25519KeyPair: userEd25519KeyPair,
        //          using: dependencies
        //        )
        
      case .group:
        print("Ignoring message with invalid sender")
        throw MessagesReceiverError.unsupportedEnvelopeType
      }
    default:
      throw MessagesReceiverError.unsupportedEnvelopeType
    }
    
    let proto: SNProtoContent
    
    do {
      proto = try SNProtoContent.parseData(plaintext.removePadding())
    } catch {
      print("Couldn't parse proto")
      throw error
    }
    
    if let dataMessage = proto.dataMessage {
      let message = Message(context: context)
      message.isIncoming = true
      message.status = .Sent
      message.id = UUID()
      message.textContent = dataMessage.body
      message.timestamp = Int64(envelope.timestamp)
      
      let conversation: Conversation
      let request: NSFetchRequest<Conversation> = Conversation.fetchBySessionID(sessionID: sender)
      if let existingConvo = try context.fetch(request).first {
        conversation = existingConvo
      } else {
        conversation = Conversation(context: context)
        conversation.sessionID = sender
        conversation.id = UUID()
      }
      if let newDisplayName = dataMessage.profile?.displayName {
        conversation.displayName = newDisplayName
      }
      conversation.lastMessage = ConversationLastMessage(isIncoming: true, textContent: dataMessage.body ?? "")
    }
    
    saveContext(context: context)
  }
  
  static func decryptWithSessionProtocol(
    ciphertext: Data,
    using x25519KeyPair: KeyPair
  ) throws -> (plaintext: Data, senderX25519PublicKey: String) {
    let sodium = Sodium()
    let recipientX25519PrivateKey: Bytes = x25519KeyPair.secretKey
    let recipientX25519PublicKey: Bytes = x25519KeyPair.publicKey
    let signatureSize: Int = sodium.sign.Bytes
    let ed25519PublicKeySize: Int = sodium.sign.PublicKeyBytes
    
    // 1. ) Decrypt the message
    guard
      let plaintextWithMetadata = sodium.box.open(
        anonymousCipherText: Bytes(ciphertext),
        recipientPublicKey: Box.PublicKey(Bytes(recipientX25519PublicKey)),
        recipientSecretKey: Bytes(recipientX25519PrivateKey)
      ),
      plaintextWithMetadata.count > (signatureSize + ed25519PublicKeySize)
    else {
      throw MessagesReceiverError.decryptionFailed
    }
    
    // 2. ) Get the message parts
    let signature = Bytes(plaintextWithMetadata[plaintextWithMetadata.count - signatureSize ..< plaintextWithMetadata.count])
    let senderED25519PublicKey = Bytes(plaintextWithMetadata[plaintextWithMetadata.count - (signatureSize + ed25519PublicKeySize) ..< plaintextWithMetadata.count - signatureSize])
    let plaintext = Bytes(plaintextWithMetadata[0..<plaintextWithMetadata.count - (signatureSize + ed25519PublicKeySize)])
    
    // 3. ) Verify the signature
    let verificationData = plaintext + senderED25519PublicKey + recipientX25519PublicKey
    
    guard
      sodium.sign.verify(
        message: verificationData, publicKey: senderED25519PublicKey, signature: signature
      )
    else { throw MessagesReceiverError.invalidSignature }
    
    // 4. ) Get the sender's X25519 public key
    guard
      let senderX25519PublicKey = sodium.sign.toX25519(ed25519PublicKey: senderED25519PublicKey)
    else { throw MessagesReceiverError.decryptionFailed }
    
    return (Data(plaintext), SessionId(.standard, publicKey: senderX25519PublicKey).hexString)
  }
}

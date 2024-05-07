import Foundation
import Sodium
import CoreData

enum MessagesReceiverError: Error {
  case noMnemonic
  case noSnodes
  case noSwarms
  case signingFailed
  case invalidMessage
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
    
    let dataBytes = Data(base64Encoded: receivedMessage.data)
    guard let envelope = SNProtoEnvelope.from(receivedMessage) else {
      throw MessagesReceiverError.invalidMessage
    }
    
    let message = Message(context: context)
    message.isIncoming = true
    message.status = .Sent
    message.id = UUID()
    message.conversation
    message.textContent
    message.timestamp
    saveContext(context: context)
  }
}

import SignalCoreKit
import Sodium

enum SendingError: Error {
  case noMnemonic
  case noPlaindata
  case noSnodes
  case noSwarms
  case invalidMessage
  case noHashInResponse
}

class MessagesSender {
  public static func storeMessage(_ message: Message, recipientPubKey: String) async throws -> (String, String) {
    guard let mnemonic = KeychainHelper.load(key: "mnemonic") else {
      throw SendingError.noMnemonic
    }
    let identity = try Identity.generate(from: mnemonic)
    let messageHash = try await self.send(message, ourEd25519KeyPair: identity.ed25519KeyPair, ourPubKey: identity.x25519KeyPair.hexEncodedPublicKey, recipientPubKey: recipientPubKey)
    let syncMessageHash = try await self.send(message, ourEd25519KeyPair: identity.ed25519KeyPair, ourPubKey: identity.x25519KeyPair.hexEncodedPublicKey, recipientPubKey: recipientPubKey, syncMessage: true)
    print("Stored message hash", messageHash)
    print("Stored sync message hash", syncMessageHash)
    return (messageHash, syncMessageHash)
  }
  
  internal static func send(
      _ message: Message,
      ourEd25519KeyPair: KeyPair, 
      ourPubKey: String,
      recipientPubKey: String,
      syncMessage: Bool = false
  ) async throws -> String {
    let proto: SNProtoContent?
    if(syncMessage) {
      proto = ProtoBuilder(sender: nil).syncMessage(message, recipient: recipientPubKey)
    } else {
      proto = ProtoBuilder(sender: LoggedUserProfile.shared.currentProfile).visibleMessage(message)
    }
    guard let messageProto = proto else {
      throw SendingError.invalidMessage
    }
    let messagePadded = try messageProto.serializedData().paddedMessageBody()
    let messageEncrypted = try encryptWithSessionProtocol(
      userEd25519KeyPair: ourEd25519KeyPair,
      plaintext: messagePadded,
      for: syncMessage ? ourPubKey : recipientPubKey
    )
    let messageWrapped = try MessageWrapper.wrap(
      type: .sessionMessage,
      timestamp: UInt64(message.timestamp),
      senderPublicKey: recipientPubKey,
      base64EncodedContent: messageEncrypted.base64EncodedString()
    )
    let messageBase64EncodedData = messageWrapped.base64EncodedString()
    let snodes = try await SeedNodes.getSnodes()
    if snodes.isEmpty {
      throw SendingError.noSnodes
    }
    let snode = snodes.randomElement()!
    let swarms = try await snode.getSwarmsFor(pubkey: syncMessage ? ourPubKey : recipientPubKey)
    if swarms.isEmpty {
      throw SendingError.noSwarms
    }
    let swarm = swarms.randomElement()!
    let result = try await swarm.storeMessage(
      data: messageBase64EncodedData,
      pubkey: syncMessage ? ourPubKey : recipientPubKey,
      timestamp: Int(message.timestamp),
      ttl: 14 * 24 * 60 * 60 * 1000
    )
    guard let hash = result["hash"] as? String else {
      throw SendingError.noHashInResponse
    }
    return hash
  }
  
  internal static func encryptWithSessionProtocol(
    userEd25519KeyPair: KeyPair,
    plaintext: Data,
    for recipientHexEncodedX25519PublicKey: String
  ) throws -> Data {
    let recipientX25519PublicKey = Data(hex: recipientHexEncodedX25519PublicKey.removingIdPrefixIfNeeded())
    
    let verificationData = plaintext + Data(userEd25519KeyPair.publicKey) + recipientX25519PublicKey
    let sodium = Sodium()
    guard
      let signature = sodium.sign.signature(message: Bytes(verificationData), secretKey: userEd25519KeyPair.secretKey)
    else { throw MessageSenderError.signingFailed }
    
    let plaintextWithMetadata = plaintext + Data(userEd25519KeyPair.publicKey) + Data(signature)
    guard
      let ciphertext = sodium.box.seal(
        message: Bytes(plaintextWithMetadata),
        recipientPublicKey: Bytes(recipientX25519PublicKey)
      )
    else { throw MessageSenderError.encryptionFailed }
    
    return Data(ciphertext)
  }
}

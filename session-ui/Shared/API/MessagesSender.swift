import SignalCoreKit
import Sodium

enum SendingError: Error {
  case noMnemonic
  case noPlaindata
  case noSnodes
  case noSwarms
  case invalidMessage
}

class MessagesSender {
  public static func storeMessage(_ message: Message, recipientPubKey: String) async {
    do {
      guard let mnemonic = KeychainHelper.load(key: "mnemonic") else {
        throw SendingError.noMnemonic
      }
      let identity = try Identity.generate(from: mnemonic)
      guard let proto = ProtoBuilder(sender: LoggedUserProfile.shared.currentProfile).visibleMessage(message) else {
        throw SendingError.invalidMessage
      }
      let paddedMessage = try proto.serializedData().paddedMessageBody()
      let encrypted = try encryptWithSessionProtocol(
        userEd25519KeyPair: identity.ed25519KeyPair,
        plaintext: paddedMessage,
        for: recipientPubKey
      )
      let wrappedMessage = try MessageWrapper.wrap(
        type: .sessionMessage,
        timestamp: UInt64(message.timestamp),
        senderPublicKey: recipientPubKey,
        base64EncodedContent: encrypted.base64EncodedString()
      )
      let base64EncodedData = wrappedMessage.base64EncodedString()
      let snodes = try await SeedNodes.getSnodes()
      if snodes.isEmpty {
        throw SendingError.noSnodes
      }
      let snode = snodes.randomElement()!
      print("snode", snode.ip, snode.port)
      let swarms = try await snode.getSwarmsFor(pubkey: recipientPubKey)
      if swarms.isEmpty {
        throw SendingError.noSwarms
      }
      let swarm = swarms.randomElement()!
      print("swarm for", recipientPubKey, "is", swarm.ip, swarm.port)
      let result = try await swarm.storeMessage(
        data: base64EncodedData,
        pubkey: recipientPubKey,
        timestamp: Int(message.timestamp),
        ttl: 14 * 24 * 60 * 60 * 1000
      )
      print("result", result["hash"])
    } catch let error {
      print(error)
      message.status = .Errored
    }
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

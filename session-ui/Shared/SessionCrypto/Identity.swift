import Sodium

public class Identity {
  static func generate(from seed: Data) throws -> (ed25519KeyPair: KeyPair, x25519KeyPair: KeyPair) {
    guard (seed.count == 16) else { throw GeneralError.invalidSeed }
    
    let padding = Data(repeating: 0, count: 16)
    
    guard
      let ed25519KeyPair = Sodium().sign.keyPair(seed: (seed + padding).bytes),
      let x25519PublicKey = Sodium().sign.toX25519(ed25519PublicKey: ed25519KeyPair.publicKey),
      let x25519SecretKey = Sodium().sign.toX25519(ed25519SecretKey: ed25519KeyPair.secretKey)
    else {
      throw GeneralError.keyGenerationFailed
    }
    
    return (
      ed25519KeyPair: KeyPair(
        publicKey: ed25519KeyPair.publicKey,
        secretKey: ed25519KeyPair.secretKey
      ),
      x25519KeyPair: KeyPair(
        publicKey: x25519PublicKey,
        secretKey: x25519SecretKey
      )
    )
  }
}

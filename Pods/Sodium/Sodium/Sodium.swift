import Foundation
import Clibsodium

public struct Sodium {
    public let box = Box()
    public let secretBox = SecretBox()
    public let genericHash = GenericHash()
    public let pwHash = PWHash()
    public let randomBytes = RandomBytes()
    public let shortHash = ShortHash()
    public let sign = Sign()
    public let utils = Utils()
    public let keyExchange = KeyExchange()
    public let auth = Auth()
    public let stream = Stream()
    public let keyDerivation = KeyDerivation()
    public let secretStream = SecretStream()
    public let aead = Aead()
    public let version = Version()

    public init() {
        _ = Sodium.once
    }

    public static func lib_crypto_core_ed25519_scalar_mul(_ z: UnsafeMutablePointer<UInt8>, _ x: UnsafePointer<UInt8>, _ y: UnsafePointer<UInt8>) {
        crypto_core_ed25519_scalar_mul(z, x, y)
    }
    
    public static func lib_crypto_core_ed25519_scalar_add(_ z: UnsafeMutablePointer<UInt8>, _ x: UnsafePointer<UInt8>, _ y: UnsafePointer<UInt8>) {
        crypto_core_ed25519_scalar_add(z, x, y)
    }
    
    public static func lib_crypto_scalarmult_ed25519_noclamp(_ q: UnsafeMutablePointer<UInt8>, _ n: UnsafePointer<UInt8>, _ p: UnsafePointer<UInt8>) -> Int32 {
        return crypto_scalarmult_ed25519_noclamp(q, n, p)
    }
    
    public static func lib_crypto_core_ed25519_scalar_reduce(_ r: UnsafeMutablePointer<UInt8>, _ s: UnsafePointer<UInt8>) {
        crypto_core_ed25519_scalar_reduce(r, s)
    }
    
    public static func lib_crypto_scalarmult_ed25519_bytes() -> Int {
        return crypto_scalarmult_ed25519_bytes()
    }
    
    public static func lib_crypto_sign_ed25519_seed_keypair(_ pk: UnsafeMutablePointer<UInt8>, _ sk: UnsafeMutablePointer<UInt8>, _ seed: UnsafePointer<UInt8>) -> Int32 {
        return crypto_sign_ed25519_seed_keypair(pk, sk, seed)
    }
}

extension Sodium {
    private static let once: Void = {
        guard sodium_init() >= 0 else {
            fatalError("Failed to initialize libsodium")
        }
    }()
}

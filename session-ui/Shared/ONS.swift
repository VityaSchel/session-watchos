import Foundation
import Sodium

let ED25519_PUBLIC_KEY_LENGTH = 32
let SESSION_PUBLIC_KEY_BINARY_LENGTH = 1 + ED25519_PUBLIC_KEY_LENGTH

public enum ONSResolveError: Error {
  case notFound
}

public class ONS {
  private static func onsToNameHash(ons: String) -> String {
    return try! BLAKE2b.hash(data: ons.data(using: .utf8)!, digestLength: 32).base64EncodedString()
  }
  
  private static func resolveNameHash(nameHash: String, completion: @escaping (Result<String, Error>) -> Void) {
    let url = URL(string: "http://public-eu.optf.ngo:22023/json_rpc")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let body: [String: Any] = [
      "jsonrpc": "2.0",
      "id": "0",
      "method": "ons_resolve",
      "params": [
        "name_hash": nameHash,
        "type": 0
      ]
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    
    URLSession.shared.dataTask(with: request) { data, response, error in
      if let error = error {
        completion(.failure(error))
        return
      }
      guard let data = data else {
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
        return
      }
      do {
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let result = json["result"] as? [String: Any] {
          if let encryptedValue = result["encrypted_value"] as? String,
            let nonce = result["nonce"] as? String {
            completion(.success(encryptedValue + nonce))
          } else {
            completion(.failure(ONSResolveError.notFound))
          }
        } else {
          completion(.failure(NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])))
        }
      } catch {
        completion(.failure(error))
      }
    }.resume()
  }
  
  public static func resolveOns(ons: String) async throws -> String {
    let nameHash = onsToNameHash(ons: ons)
    let encryptedResult = try await withCheckedThrowingContinuation { continuation in
      resolveNameHash(nameHash: nameHash) { result in
        switch result {
        case .success(let encryptedValue):
          continuation.resume(returning: encryptedValue)
        case .failure(let error):
          continuation.resume(throwing: error)
        }
      }
    }
    return try await decryptONSValue(value: encryptedResult, unhashedName: ons)
  }
  
  private static func splitEncryptedValue(encryptedValue: Bytes, legacyFormat: Bool) -> ([UInt8], [UInt8]) {
    let sodium = Sodium()
    if legacyFormat {
      return (encryptedValue, Array(repeating: 0, count: Int(sodium.secretBox.NonceBytes)))
    } else {
      let nonceSize = Int(sodium.aead.xchacha20poly1305ietf.NonceBytes)
      let messageLength = encryptedValue.count - nonceSize
      let nonce = Array(encryptedValue[messageLength..<encryptedValue.count])
      let message = Array(encryptedValue[0..<messageLength])
      return (message, nonce)
    }
  }
  
  private static func decryptXChachaWithKey(message: Bytes, nonce: Bytes, key: Bytes) throws -> String {
    let sodium = Sodium()
    if let decrypted = sodium.aead.xchacha20poly1305ietf.decrypt(authenticatedCipherText: message, secretKey: key, nonce: nonce) {
      if let hex = sodium.utils.bin2hex(decrypted) {
        return hex
      }
    }
    throw GeneralError.decryptionFailed
  }
  
  private static func decryptSecretboxWithKey(message: Bytes, nonce: Bytes, key: Bytes) throws -> String {
    let sodium = Sodium()
    if let decrypted = sodium.secretBox.open(authenticatedCipherText: message, secretKey: key, nonce: nonce) {
      if let hex = sodium.utils.bin2hex(decrypted) {
        return hex
      }
    }
    throw GeneralError.decryptionFailed
  }
  
  private enum Algorithm {
    case blake2b
    case argon2id13
  }
  
  private static func generateKey(unhashedName: String, algorithm: Algorithm) async throws -> Bytes {
    let sodium = Sodium()
    let enc = Array(unhashedName.utf8)
    switch algorithm {
    case .blake2b:
      if let key = sodium.genericHash.hash(message: enc, outputLength: 32),
         let finalKey = sodium.genericHash.hash(message: enc, key: key, outputLength: 32) {
        return finalKey
      } else {
        throw GeneralError.keyGenerationFailed
      }
    case .argon2id13:
      let salt = sodium.randomBytes.buf(length: sodium.pwHash.SaltBytes)!
      if let result = sodium.pwHash.hash(outputLength: sodium.aead.xchacha20poly1305ietf.KeyBytes, passwd: enc, salt: salt, opsLimit: sodium.pwHash.OpsLimitModerate, memLimit: sodium.pwHash.MemLimitModerate) {
        return result
      } else {
        throw GeneralError.keyGenerationFailed
      }
    }
  }
  
  private static func decryptONSValue(value: String, unhashedName: String) async throws -> String {
    let sodium = Sodium()
    guard let encryptedValue = sodium.utils.hex2bin(value) else {
      throw GeneralError.decryptionFailed
    }
    let legacyFormat = encryptedValue.count == SESSION_PUBLIC_KEY_BINARY_LENGTH + sodium.secretBox.MacBytes
    let key = try await generateKey(unhashedName: unhashedName, algorithm: legacyFormat ? .argon2id13 : .blake2b)
    let (message, nonce) = splitEncryptedValue(encryptedValue: encryptedValue, legacyFormat: false)
    if legacyFormat {
      return try decryptSecretboxWithKey(message: message, nonce: nonce, key: key)
    } else {
      return try decryptXChachaWithKey(message: message, nonce: nonce, key: key)
    }
  }
}

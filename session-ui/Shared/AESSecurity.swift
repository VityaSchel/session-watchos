//
//  AESSecurity.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 13.03.2024.
//

import Foundation
import Security

func generateAESKey() -> String? {
  var ivBytes = [UInt8](repeating: 0, count: 16)
  let iv = SecRandomCopyBytes(kSecRandomDefault, 16, &ivBytes)
  guard iv == errSecSuccess else {
    fatalError("Failed to generate random iv bytes")
  }

  var keyBytes = [UInt8](repeating: 0, count: 32)
  let key = SecRandomCopyBytes(kSecRandomDefault, 32, &keyBytes)
  guard key == errSecSuccess else {
    fatalError("Failed to generate random key bytes")
  }
    
  return Data(ivBytes + keyBytes).base64EncodedString()
}

func decryptAesCbc(encryptedBase64: String, AesKeyBase64: String) {
  guard let AesKey = Data(base64Encoded: AesKeyBase64) else {
    fatalError("Failed to decode AES key base64")
  }
  guard let encrypted = Data(base64Encoded: encryptedBase64) else {
    fatalError("Failed to decode encrypted data base64")
  }
  let iv = AesKey.subdata(in: 0..<16)
  let key = AesKey.subdata(in: 16..<AesKey.endIndex)
  
  var buffer = Data(count: encrypted.count + kCCBlockSizeAES128)
  var numBytesDecrypted = 0
  
  let status = encrypted.withUnsafeBytes { dataPtr in
    key.withUnsafeBytes { keyPtr in
      iv.withUnsafeBytes { ivPtr in
        buffer.withUnsafeMutableBytes { bufferPtr in
          CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
                  CCOptions(kCCOptionPKCS7Padding), keyPtr.baseAddress, key.count,
                  ivPtr.baseAddress, dataPtr.baseAddress, data.count,
                  bufferPtr.baseAddress, buffer.count, &numBytesDecrypted)
        }
      }
    }
  }

  guard status == kCCSuccess else {
    print("Decryption failed")
    return nil
  }

  buffer.removeSubrange(numBytesDecrypted..<buffer.count) // Trim unused buffer space
  return buffer
}

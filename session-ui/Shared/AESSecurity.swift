//
//  AESSecurity.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 13.03.2024.
//

import Foundation
import Security
import CryptoSwift

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

func decryptAesCbc(encryptedBase64: String, AesKeyBase64: String) throws -> String {
  guard let AesKey = Data(base64Encoded: AesKeyBase64) else {
    throw SessionUiError.runtimeError(message: "Failed to decode AES key base64")
  }
  guard let encrypted = Data(base64Encoded: encryptedBase64) else {
    throw SessionUiError.runtimeError(message: "Failed to decode encrypted data base64")
  }
  let iv = AesKey.subdata(in: 0..<16)
  let key = AesKey.subdata(in: 16..<AesKey.endIndex)
  
  do {
    let aes = try AES(key: key.bytes, blockMode: CBC(iv: iv.bytes), padding: .pkcs7)
    let decryptedBytes = try aes.decrypt(encrypted.bytes)
    let decryptedData = Data(decryptedBytes)
    return String(decoding: decryptedData, as: UTF8.self)
  } catch {
    fatalError("Failed to decrypt data with AES")
  }
}

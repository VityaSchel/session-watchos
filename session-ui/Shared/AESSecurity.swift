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

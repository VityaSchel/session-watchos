//
//  AESSecurity.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 13.03.2024.
//

import Foundation

func generateAESKey() -> Data? {
    var keyData = Data(count: 32)
    let result = keyData.withUnsafeMutableBytes {
        SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
    }
    if result == errSecSuccess {
        return keyData
    } else {
        print("Error generating key: \(result)")
        return nil
    }
}

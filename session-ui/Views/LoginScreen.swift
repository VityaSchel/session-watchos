//
//  LoginScreen.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 12.03.2024.
//

import Foundation
import SwiftUI

struct LoginScreen: View {
  @State private var qrCodeImage: UIImage?
  @State private var isLoading = true
  
  var body: some View {
    VStack {
      ZStack {
        if isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
        } else {
          Image(uiImage: qrCodeImage ?? UIImage())
            .resizable()
            .interpolation(.none)
            .scaledToFit()
        }
      }
      
      Text("Scan to continue")
    }
    .onAppear {
//      DispatchQueue.global(qos: .background).async {
//        let id = UUID().uuidString
//        if let secretKeyData = generateAESKey() {
//          let secretKey = secretKeyData.base64EncodedString()
//          let generatedQRCode = generateQRCode(from: "https://watchos-session-login.sessionbots.directory/" + id + "#" + secretKey)
//          
//          DispatchQueue.main.async {
//            self.qrCodeImage = generatedQRCode
//            self.isLoading = false
//          }
//        } else {
//          print("Error: Secret key data could not be generated.")
//        }
//      }
    }
  }
}


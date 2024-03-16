//
//  LoginScreen.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 12.03.2024.
//

import Foundation
import SwiftUI

struct SigninScreen: View {
  @StateObject private var viewModel = SigninViewModel()
  
  var body: some View {
    VStack(spacing: 7) {
      ZStack {
        if viewModel.isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
        } else {
          Image(uiImage: viewModel.qrCodeImage ?? UIImage())
            .resizable()
            .interpolation(.none)
            .scaledToFit()
        }
      }
      
      Text("Scan to continue")
        .font(.system(size: 14))
    }
    .onAppear {
      DispatchQueue.global(qos: .background).async {
        APIStartLoginFlow { result in
            switch result {
            case .success(let flowID):
              if let secretKey = generateAESKey() {
                let generatedQRCode = generateQRCode(href: ApiUrl + "/login/" + flowID + "#" + secretKey)
                
                DispatchQueue.main.async {
                  viewModel.qrCodeImage = generatedQRCode
                  viewModel.isLoading = false
                }
              } else {
                viewModel.alertMessage = "Error: Secret key data could not be generated."
                viewModel.showAlert = true
              }
            case .failure(let error):
              viewModel.alertMessage = "An error occurred: \(error.localizedDescription)"
              viewModel.showAlert = true
            }
        }
      }
    }
    .alert(isPresented: $viewModel.showAlert) {
      Alert(title: Text("Error"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
    }
  }
}

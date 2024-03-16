//
//  LoginScreenModel.swift
//  session-ui
//
//  Created by Виктор Щелочков on 16.03.2024.
//

import Foundation
import SwiftUI

class SigninViewModel: ObservableObject {
    @Published var qrCodeImage: UIImage?
    @Published var isLoading = true
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private var checkServerTimer: Timer?
    
    func startLoginFlow() {
        isLoading = true
        APIStartLoginFlow { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let flowID):
                    if let secretKey = generateAESKey() {
                        let generatedQRCode = generateQRCode(href: ApiUrl + "/login/" + flowID + "#" + secretKey)
                        self?.qrCodeImage = generatedQRCode
                        self?.isLoading = false
                        self?.startCheckingServer(flowID: flowID)
                    } else {
                        self?.alertMessage = "Error: Secret key data could not be generated."
                        self?.showAlert = true
                        self?.isLoading = false
                    }
                case .failure(let error):
                    self?.alertMessage = "An error occurred: \(error.localizedDescription)"
                    self?.showAlert = true
                    self?.isLoading = false
                }
            }
        }
    }
    
    func startCheckingServer(flowID: String) {
        checkServerTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { [weak self] _ in
          APICheckLoginFlow(flowID: flowID) { result in
            switch result {
            case .success(let result):
              DispatchQueue.main.async {
                self?.checkServerTimer?.invalidate()
              }
            case .failure(let error):
              print("An error occurred: \(error.localizedDescription)")
            }
          }
        }
    }
    
    func stopCheckingServer() {
        checkServerTimer?.invalidate()
    }
    
    deinit {
        checkServerTimer?.invalidate()
    }
}

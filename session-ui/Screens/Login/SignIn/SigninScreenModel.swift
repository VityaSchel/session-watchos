import Foundation
import SwiftUI

class SigninViewModel: ObservableObject {
  @EnvironmentObject var navigationModel: NavigationModel
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
            let generatedQRCode = generateQRCode(content: ApiUrl + "/login/" + flowID + "#" + secretKey)
            self?.qrCodeImage = generatedQRCode
            self?.isLoading = false
            self?.startCheckingServer(flowID: flowID, completion: { encryptedPhrase in
              do {
                let decryptedPhrase = try decryptAesCbc(encryptedBase64: encryptedPhrase, AesKeyBase64: secretKey)
                let seed = decryptedPhrase.data(using: .utf8)!
                let identity = try Identity.generate(from: seed)
                self?.navigationModel.path.append(AuthRoutes.LoginSuccess(LoginSuccessScreenDetails(
                  sessionID: identity.ed25519KeyPair.hexEncodedPublicKey,
                  seed: seed
                )))
              } catch {
                self?.alertMessage = "Something went wrong"
                self?.showAlert = true
              }
            })
          } else {
            self?.alertMessage = "Error: Secret key data could not be generated."
            self?.showAlert = true
            self?.isLoading = false
          }
        case .failure(let error):
          self?.alertMessage = error.localizedDescription
          self?.showAlert = true
          self?.isLoading = false
        }
      }
    }
  }
    
  func startCheckingServer(flowID: String, completion: @escaping (String) -> Void) {
    checkServerTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
      APICheckLoginFlow(flowID: flowID) { result in
        switch result {
        case .success(let result):
          if let encryptedPhrase = result {
            self.stopCheckingServer()
            completion(encryptedPhrase)
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

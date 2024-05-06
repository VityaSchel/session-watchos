import Foundation
import SwiftUI

class AccountContext: ObservableObject {
  @Published var authorized = false
  @Published var mnemonic: String?
  
  private func seedToMnemonic(seed: Data) -> String {
    return Mnemonic.encode(hexEncodedString: seed.toHexString())
  }
  
  init() {
    if let seedData = KeychainHelper.load(key: "mnemonic") {
      mnemonic = seedToMnemonic(seed: seedData)
      authorized = true
    } else {
      mnemonic = nil
    }
  }
  
  func login(seed: Data) {
    KeychainHelper.save(key: "mnemonic", data: seed)
    mnemonic = seedToMnemonic(seed: seed)
    authorized = true
  }
  
  func logout() {
    KeychainHelper.delete(key: "mnemonic")
    LoggedUserProfile.shared.unsetCurrentUser()
    mnemonic = nil
    authorized = false
  }
}

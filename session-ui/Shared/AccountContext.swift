import Foundation
import SwiftUI

class AccountContext: ObservableObject {
  @Published var authorized = false
  @Published var mnemonic: String?
  
  private func seedToMnemonic(seed: Data) -> String {
    return Mnemonic.encode(hexEncodedString: seed.toHexString())
  }
  
  init() {
    let seedData = KeychainHelper.load(key: "mnemonic")
    if seedData != nil {
      mnemonic = seedToMnemonic(seed: seedData!)
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
    mnemonic = nil
    authorized = false
  }
}

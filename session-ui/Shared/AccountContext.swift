import Foundation
import SwiftUI
import CoreData

class AccountContext: ObservableObject {
  @Published var authorized = false
  @Published var mnemonic: String?
  
  private func seedToMnemonic(seed: Data) -> String {
    return Mnemonic.encode(hexEncodedString: seed.toHexString())
  }
  
  init(context: NSManagedObjectContext) {
    if let seedData = KeychainHelper.load(key: "mnemonic") {
      mnemonic = seedToMnemonic(seed: seedData)
      let identity = try! Identity.generate(from: seedData)
      if let ourProfile: Account = {
        let request: NSFetchRequest<Account> = Account.fetchBySessionID(sessionID: identity.x25519KeyPair.hexEncodedPublicKey)
        return try! context.fetch(request).first
      }() {
        LoggedUserProfile.shared.loadCurrentUser(ourProfile)
      }
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

import Foundation
import SwiftUI
import CoreData

struct LoginSuccessScreen: View {
  @EnvironmentObject var account: AccountContext
  @EnvironmentObject var navigation: NavigationModel
  @Environment(\.managedObjectContext) var context
  var sessionID: String
  var seed: Data
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        Text(NSLocalizedString("loginSuccessIntro", comment: "After user signup or signin"))
          .font(.caption2)
          .frame(maxWidth: .infinity)
          .multilineTextAlignment(.center)
          .padding(.top, 5)
          .foregroundColor(Color.brand)
        
        Text(sessionID)
          .font(.system(size: 13.3, design: .monospaced))
          .frame(maxWidth: .infinity)
          .multilineTextAlignment(.center)
          .padding(.top, 5)
          .padding(.bottom, 5)
          .foregroundColor(Color.brand)
        
        
        Button(action: {
          account.login(seed: seed)
          if let ourProfile: Account = {
            let request: NSFetchRequest<Account> = Account.fetchBySessionID(sessionID: sessionID)
            return try! context.fetch(request).first
          }() {
            LoggedUserProfile.shared.loadCurrentUser(ourProfile)
          } else {
            let newAccount = Account(context: context)
            newAccount.sessionID = sessionID
            saveContext(context: context)
            LoggedUserProfile.shared.loadCurrentUser(newAccount)
          }
          navigation.path = NavigationPath()
        }) {
          Text(NSLocalizedString("confirm", comment: "Confirm"))
        }
      }
      .padding(.horizontal, 5)
    }
    .padding(.top, 50)
    .ignoresSafeArea()
  }
}

struct LoginSuccessScreen_Previews: PreviewProvider {
  static var previews: some View {
    LoginSuccessScreen(sessionID: "057aeb66e45660c3bdfb7c62706f6440226af43ec13f3b6f899c1dd4db1b8fce5b", seed: Data())
      .background(Color.grayBackground)
  }
}

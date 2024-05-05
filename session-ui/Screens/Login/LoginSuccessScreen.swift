import Foundation
import SwiftUI

struct LoginSuccessScreen: View {
  @EnvironmentObject var account: AccountContext
  @EnvironmentObject var navigation: NavigationModel
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

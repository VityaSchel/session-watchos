import Foundation
import SwiftUI

struct LoginScreen: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading) {
        SessionLogo()
          .fill(Color.brand)
          .frame(width: 20, height: 20)
          .padding(.leading, 10)
        
        Text(NSLocalizedString("welcome", comment: "Login screen"))
          .font(.subheadline)
          .fontWeight(.bold)
          .padding(.leading, 10)
          .padding(.top, 5)
          .padding(.bottom, 10)
          .foregroundColor(Color.brand)
        
        
        NavigationLink(value: AuthRoutes.SignIn) {
          Text(NSLocalizedString("signInButton", comment: "Login screen"))
            .font(.system(size: 15))
        }
        NavigationLink(value: AuthRoutes.SignUp) {
          Text(NSLocalizedString("signUpButton", comment: "Login screen"))
            .font(.system(size: 15))
        }
      }
      .padding(.horizontal, 5)
      .padding(.bottom, 20)
    }
    .padding(.top, 40)
    .ignoresSafeArea()
  }
}

struct LoginScreen_Previews: PreviewProvider {
  static var previews: some View {
    LoginScreen()
      .background(Color.grayBackground)
  }
}

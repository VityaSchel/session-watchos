import Foundation
import SwiftUI

struct LoginScreen: View {
  var body: some View {
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
      
      List {
        NavigationLink(destination: SigninScreen()) {
          Text(NSLocalizedString("signInButton", comment: "Login screen"))
            .font(.system(size: 15))
        }
        NavigationLink(destination: SignupScreen()) {
          Text(NSLocalizedString("signUpButton", comment: "Login screen"))
            .font(.system(size: 15))
        }
      }
      .padding(.horizontal, 5)
    }
    .padding(.top, 30)
    .ignoresSafeArea()
  }
}

struct LoginScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      LoginScreen()
        .background(Color.grayBackground)
    }
  }
}

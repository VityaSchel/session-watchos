import Foundation
import SwiftUI

struct SignupScreen: View {
  @State private var displayName = ""
  @State private var showAlert = false
  @State private var alertMessage = ""
  @EnvironmentObject var navigationModel: NavigationModel
  
    var body: some View {
      VStack(spacing: 10) {
        TextField(NSLocalizedString("signUpDisplayName", comment: "Sign up profile name"), text: $displayName)
        
        Button(action: {
          do {
            let seed = try Randomness.generateRandomBytes(numberBytes: 16)
            let (ed25519KeyPair, x25519KeyPair) = try Identity.generate(from: seed)
            let sessionID = x25519KeyPair.hexEncodedPublicKey
            let profileName = displayName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if profileName.isEmpty {
              return
            }
            if profileName.utf8.count > MAX_USERNAME_BYTES {
              showAlert = true
              alertMessage = NSLocalizedString("displayNameTooLong", comment: "When user inputs too long display name")
              return
            }
            
            navigationModel.path.append(AuthRoutes.LoginSuccess(LoginSuccessScreenDetails(
              sessionID: sessionID,
              displayName: displayName,
              seed: seed
            )))
          } catch {
            showAlert = true
            alertMessage = "Couldn't generate key pair"
          }
        }) {
            HStack {
              Text(NSLocalizedString("signUp", comment: "Sign up button text"))
                .fontWeight(.bold)
                .foregroundColor(Color.background)
              Image(systemName: "arrow.right")
                .foregroundColor(Color.background)
            }
        }
        .tint(Color.brand)
        .buttonStyle(.borderedProminent)
      }
      .alert(isPresented: $showAlert) {
        Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
      }
      .padding(.horizontal, 5)
    }
}

struct SignupScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      SignupScreen()
        .environmentObject(NavigationModel())
        .background(Color.grayBackground)
    }
  }
}

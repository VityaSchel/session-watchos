import Foundation
import SwiftUI

struct SettingsDisplayNameScreen: View {
  @State private var recipient = ""
  
  var body: some View {
    VStack(spacing: 10) {
      TextField(NSLocalizedString("displayName", comment: "Placeholder for recipient input"), text: $recipient, onCommit: {
        recipient = ""
      })
      .frame(maxWidth: .infinity)
      Button(action: {
        
      }) {
        HStack(spacing: 10) {
          HStack {
            Text(NSLocalizedString("save", comment: "Save button"))
              .fontWeight(.bold)
              .foregroundColor(Color.background)
          }
        }
      }
      .tint(Color.brand)
      .buttonStyle(.borderedProminent)
    }
  }
}

struct SettingsDisplayName_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      SettingsDisplayNameScreen()
        .background(Color.grayBackground)
    }
  }
}

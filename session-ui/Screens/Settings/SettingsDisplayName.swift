import Foundation
import SwiftUI

struct SettingsDisplayNameScreen: View {
  var onClose: () -> Void
  @State private var displayName = ""
  
  var body: some View {
    VStack(spacing: 10) {
      TextField(NSLocalizedString("displayName", comment: "Placeholder for recipient input"), text: $displayName)
      .frame(maxWidth: .infinity)
      Button(action: {
        onClose()
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
    .navigationTitle(NSLocalizedString("displayName", comment: "Settings button"))
  }
}

struct SettingsDisplayName_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      SettingsDisplayNameScreen(onClose: {})
        .background(Color.grayBackground)
    }
  }
}

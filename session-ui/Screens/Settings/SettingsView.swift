import Foundation
import SwiftUI

enum ModalType: Identifiable {
  case displayNameChange
  
  var id: Int {
    hashValue
  }
}

struct SettingsScreen: View {
  @State private var modalType: ModalType?
  
  var body: some View {
    VStack {
      List {
        Button(action: {
          
        }) {
          HStack {
            Image(systemName: "ipad.and.arrow.forward")
              .frame(width: 30)
            Text(NSLocalizedString("signOut", comment: "Settings button"))
          }
        }
        Button(action: {
          modalType = .displayNameChange
        }) {
          HStack {
            Text(NSLocalizedString("displayName", comment: "Settings button"))
          }
        }
        Button(action: {
          WKExtension.shared().openSystemURL(URL(string: "https://hloth.dev")!)
        }) {
          HStack {
            Text(NSLocalizedString("author", comment: "Link in settings"))
          }
        }
      }
    }
    .navigationTitle(NSLocalizedString("settingsTitle", comment: "Title of Settings screen"))
    .sheet(item: $modalType) { type in
      switch type {
      case .displayNameChange:
        SettingsDisplayNameScreen()
      }
    }
  }
}

struct SettingsScreen_Previews: PreviewProvider {
  static var previews: some View {
    SettingsScreen()
      .background(Color.grayBackground)
  }
}

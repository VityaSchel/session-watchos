import Foundation
import SwiftUI
import CoreData

enum ModalType: Identifiable {
  case displayNameChange
  case mnemonicQrCode
  
  var id: Int {
    hashValue
  }
}

struct SettingsScreen: View {
  @State private var modalType: ModalType?
  @State private var signOutConfirmationDialog = false
  @EnvironmentObject var account: AccountContext
  @EnvironmentObject var navigation: NavigationModel
  @Environment(\.managedObjectContext) var context
  
  var body: some View {
    VStack {
      List {
        Button(action: {
          modalType = .displayNameChange
        }) {
          HStack {
            Image(systemName: "character.cursor.ibeam")
              .frame(width: 30)
            Text(NSLocalizedString("displayName", comment: "Settings button"))
          }
        }
        Button(action: {
          modalType = .mnemonicQrCode
        }) {
          HStack {
            Image(systemName: "doc.on.doc")
              .frame(width: 30)
            Text(NSLocalizedString("copyMnemonic", comment: "Settings button"))
          }
        }
        Button(action: {
          signOutConfirmationDialog = true
        }) {
          HStack {
            Image(systemName: "ipad.and.arrow.forward")
              .frame(width: 30)
            Text(NSLocalizedString("signOut", comment: "Settings button"))
          }
          .foregroundColor(Color.red)
        }
        .confirmationDialog(NSLocalizedString("signOutWarning", comment: "Sign out confirmation dialog text"), isPresented: $signOutConfirmationDialog) {
          Button("OK", role: .destructive) {
            do {
              signOutConfirmationDialog = false
              account.logout()
              
              let storeContainer =
              PersistenceController.shared.container.persistentStoreCoordinator
              
              for store in storeContainer.persistentStores {
                try storeContainer.destroyPersistentStore(
                  at: store.url!,
                  ofType: store.type,
                  options: nil
                )
              }
              
              navigation.path = NavigationPath()
            } catch {
              print("Could not erase database", error)
            }
          }
        }
        Button(action: {
          WKExtension.shared().openSystemURL(URL(string: "https://hloth.dev")!)
        }) {
          Text(NSLocalizedString("author", comment: "Link in settings"))
        }
        .buttonStyle(.borderless)
        .listRowPlatterColor(.clear)
      }
    }
    .navigationTitle(NSLocalizedString("settingsTitle", comment: "Title of Settings screen"))
    .sheet(item: $modalType) { type in
      switch type {
      case .displayNameChange:
        SettingsDisplayNameScreen(onClose: {
          modalType = nil
        })
      case .mnemonicQrCode:
        SettingsMnemonicQrCodeScreen()
      }
    }
  }
  
  func deleteAllObjects(entity: String, context: NSManagedObjectContext) {
    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entity)
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
    
    do {
      try context.execute(deleteRequest)
    } catch let error as NSError {
      print("Could not delete all objects: \(error), \(error.userInfo)")
    }
  }
}

struct SettingsScreen_Previews: PreviewProvider {
  static var previews: some View {
    SettingsScreen()
      .background(Color.grayBackground)
  }
}

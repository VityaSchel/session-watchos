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
  @EnvironmentObject var dataController: DataController
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
            signOutConfirmationDialog = false
            account.logout()
            
            context.perform {
              do {
                let entities = ["DirectMessagesConversation","Message","SeenMessage","Account"]
                for entity in entities {
                  print(entity)
                  
                  let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entity)
                  let batchDeleteRequest = NSBatchDeleteRequest.init(fetchRequest: fetchRequest)
                  
                  batchDeleteRequest.resultType = .resultTypeObjectIDs
                  
                  do {
                    let batchDelete = try context.persistentStoreCoordinator?.execute(batchDeleteRequest, with: context) as? NSBatchDeleteResult
  
                    guard let deleteResult = batchDelete?.result
                            as? [NSManagedObjectID]
                    else { return }
  
                    let deletedObjects: [AnyHashable: Any] = [
                      NSDeletedObjectsKey: deleteResult
                    ]
  
                    NSManagedObjectContext.mergeChanges(
                      fromRemoteContextSave: deletedObjects,
                      into: [context]
                    )
                  } catch let error as NSError {
                    print("Error while deleting", entity, error)
                  }
                }
                
                try context.save()
                context.reset()
              } catch let error {
                print("Error while deleting objects", error)
              }
            }
            
            navigation.path = NavigationPath()
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
}

struct SettingsScreen_Previews: PreviewProvider {
  static var previews: some View {
    SettingsScreen()
      .background(Color.grayBackground)
  }
}

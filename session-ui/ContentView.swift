import SwiftUI
import CoreData

enum AuthRoutes: Hashable {
  case SignIn
  case SignUp
  case LoginSuccess(LoginSuccessScreenDetails)
}
enum Routes: Hashable {
  case Settings
  case NewConversation
  case Conversation(ConversationScreenDetails)
}

struct ConversationScreenDetails: Hashable {
  var title: String
  var uuid: UUID
  var cdObjectId: NSManagedObjectID
}

struct LoginSuccessScreenDetails: Hashable {
  var sessionID: String
  var seed: Data
}

class NavigationModel: ObservableObject {
  @Published var path = NavigationPath()
}

struct ContentView: View {
  @EnvironmentObject var navigationModel: NavigationModel
  @EnvironmentObject var account: AccountContext
  @State private var authorizationLoaded = false
  
  var body: some View {
    NavigationStack(path: $navigationModel.path) {
      if account.authorized {
        HomeScreen()
          .navigationDestination(for: Routes.self) { route in
            switch route {
            case Routes.Settings:
              SettingsScreen()
            case Routes.NewConversation:
              NewConversationScreen()
            case Routes.Conversation(let details):
              ConversationScreen(conversation: details)
            }
          }
      } else {
        LoginScreen()
          .navigationDestination(for: AuthRoutes.self) { route in
            switch route {
            case AuthRoutes.SignIn:
              SigninScreen()
            case AuthRoutes.SignUp:
              SignupScreen()
            case AuthRoutes.LoginSuccess(let details):
              LoginSuccessScreen(sessionID: details.sessionID, seed: details.seed)
            }
          }
      }
    }
    .background(Color.grayBackground)
    .ignoresSafeArea()
  }
}

#Preview {
  ContentView()
    .environmentObject(NavigationModel())
    .environmentObject(AccountContext())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

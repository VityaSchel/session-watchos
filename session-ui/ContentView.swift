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
  var displayName: String?
  var seed: Data
}

class NavigationModel: ObservableObject {
  @Published var path = NavigationPath()
}

struct ContentView: View {
  @Environment(\.managedObjectContext) var context
  @EnvironmentObject var navigationModel: NavigationModel
  @EnvironmentObject var account: AccountContext
  @State private var pollingManager: PollingManager?
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
              ConversationScreen(details)
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
              LoginSuccessScreen(sessionID: details.sessionID, displayName: details.displayName, seed: details.seed)
            }
          }
      }
    }
    .background(Color.grayBackground)
    .ignoresSafeArea()
    .onAppear {
      if pollingManager == nil {
        Task {
          do {
            pollingManager = try await PollingManager(accountContext: account, context: context)
          } catch let error {
            print("Could not initialize polling", error)
          }
        }
      }
    }
    .onDisappear {
      pollingManager?.stopPolling()
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(NavigationModel())
    .environmentObject(AccountContext(context: PersistenceController.preview.container.viewContext))
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

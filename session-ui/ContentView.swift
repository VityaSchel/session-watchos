import SwiftUI

enum AuthRoutes: Hashable {
  case SignIn
  case SignUp
}
enum Routes: Hashable {
  case Settings
  case NewConversation
  case Conversation(ConversationScreenDetails)
}

struct ConversationScreenDetails: Hashable {
  var title: String
  var uuid: UUID
}

class NavigationModel: ObservableObject {
  @Published var path = NavigationPath()
}

struct ContentView: View {
  @EnvironmentObject var navigationModel: NavigationModel
  @State private var loginMenuActive = false
  
  var body: some View {
    NavigationStack(path: $navigationModel.path) {
      if loginMenuActive {
        LoginScreen()
          .navigationDestination(for: AuthRoutes.self) { route in
            switch route {
            case AuthRoutes.SignIn:
              SigninScreen()
            case AuthRoutes.SignUp:
              SignupScreen()
            }
          }
      } else {
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
      }
    }
    .background(Color.grayBackground)
    .ignoresSafeArea()
  }
}

#Preview {
  ContentView()
    .environmentObject(NavigationModel())
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

import Foundation
import SwiftUI
import WatchKit

struct NewDirectMessagesConversationScreen: View {
  @Environment(\.managedObjectContext) var context
  @State private var recipient = ""
  var onCreated: (_: DirectMessagesConversation) -> Void
  
  @State private var showAlert = false
  @State private var alertMessage: String = ""
  @State private var loading: Bool = false
  
  var body: some View {
    if loading {
      ProgressView()
    } else {
      VStack(spacing: 10) {
        TextField(NSLocalizedString("recipientInputPlaceholder", comment: "Placeholder for recipient input"), text: $recipient, onCommit: {
          recipient = ""
        })
        .frame(maxWidth: .infinity)
        Button(action: {
          if recipient.isEmpty {
            return
          }
          if recipient.test("^[0-9a-f]{66}$") {
            createConversation(sessionID: recipient)
          } else if recipient.test("^[0-9a-zA-Z-]{1,64}$") {
            loading = true
            Task {
              do {
                createConversation(sessionID: try await ONS.resolveOns(ons: recipient))
              } catch {
                showAlert = true
                if error is ONSResolveError {
                  alertMessage = NSLocalizedString("couldntResolveONS", comment: "Could not resolve ONS name")
                } else {
                  alertMessage = error.localizedDescription
                }
              }
              loading = false
            }
          } else {
            showAlert = true
            alertMessage = NSLocalizedString("invalidRecipient", comment: "User inputted invalid recipient when creating new conversation")
          }
        }) {
          HStack(spacing: 10) {
            HStack {
              Text(NSLocalizedString("create", comment: "Create conversation"))
                .fontWeight(.bold)
                .foregroundColor(Color.background)
              Image(systemName: "arrow.right")
                .foregroundColor(Color.background)
            }
          }
        }
        .alert(isPresented: $showAlert) {
          Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .tint(Color.brand)
        .buttonStyle(.borderedProminent)
      }
    }
  }
  
  private func createConversation(sessionID: String) {
    let newConvo = DirectMessagesConversation(context: context)
    newConvo.id = UUID()
    newConvo.sessionID = sessionID
    saveContext(context: context)
    onCreated(newConvo)
  }
}

struct NewDirectMessagesConversationScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NewDirectMessagesConversationScreen(onCreated: { conversation in })
        .background(Color.grayBackground)
    }
  }
}

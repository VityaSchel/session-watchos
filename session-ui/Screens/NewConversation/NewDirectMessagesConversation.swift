import Foundation
import SwiftUI
import WatchKit

struct NewDirectMessagesConversationScreen: View {
  @Environment(\.managedObjectContext) var context
  @State private var recipient = "057aeb66e45660c3bdfb7c62706f6440226af43ec13f3b6f899c1dd4db1b8fce5b"
  var onCreated: (_: DirectMessagesConversation) -> Void
  
  @State private var showAlert = false
  @State private var alertMessage: String = ""
  
  var body: some View {
    VStack(spacing: 10) {
      TextField(NSLocalizedString("recipientInputPlaceholder", comment: "Placeholder for recipient input"), text: $recipient, onCommit: {
        recipient = ""
      })
        .frame(maxWidth: .infinity)
      Button(action: {
        var sessionID: String? {
          if recipient.isEmpty {
            return nil
          }
          if recipient.test("^[0-9a-f]{66}$") {
            return recipient
          } else if recipient.test("^[0-9a-zA-Z-]{1,64}$") {
            showAlert = true
            alertMessage = NSLocalizedString("couldntResolveONS", comment: "Could not resolve ONS name")
            return nil
          } else {
            showAlert = true
            alertMessage = NSLocalizedString("invalidRecipient", comment: "User inputted invalid recipient when creating new conversation")
            return nil
          }
        }
        if sessionID == nil {
          return
        }
        let newConvo = DirectMessagesConversation(context: context)
        newConvo.id = UUID()
        newConvo.sessionID = sessionID!
        saveContext(context: context)
        onCreated(newConvo)
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

struct NewDirectMessagesConversationScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NewDirectMessagesConversationScreen(onCreated: { conversation in })
        .background(Color.grayBackground)
    }
  }
}

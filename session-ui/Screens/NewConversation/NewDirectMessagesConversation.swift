import Foundation
import SwiftUI

struct NewDirectMessagesConversationScreen: View {
  @State private var recipient = ""
  
  var body: some View {
    VStack(spacing: 10) {
      TextField(NSLocalizedString("recipientInputPlaceholder", comment: "Placeholder for recipient input"), text: $recipient, onCommit: {
        recipient = ""
      })
        .frame(maxWidth: .infinity)
      Button(action: {
        
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
      .tint(Color.brand)
      .buttonStyle(.borderedProminent)
    }
  }
}

struct NewDirectMessagesConversationScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NewDirectMessagesConversationScreen()
        .background(Color.grayBackground)
    }
  }
}

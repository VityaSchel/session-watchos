import Foundation
import SwiftUI

struct MessageInput: View {
  @Environment(\.managedObjectContext) var context
  @State private var message = "❤️"
  var onSubmit: (_: String) -> Void
  
  var body: some View {
    TextField(NSLocalizedString("messageInputPlaceholder", comment: "Conversation input placeholder"), text: $message)
      .submitLabel(.send)
    .onSubmit {
      onSubmit(message)
      message = ""
    }
    .frame(maxWidth: .infinity)
  }
}

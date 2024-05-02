import Foundation
import SwiftUI

struct SessionConversationMessage: Identifiable {
  let id: String
  let text: String
  let from: String
}

struct ConversationMessage: View {
  let message: SessionConversationMessage
  let maxWidth: CGFloat
  
  var body: some View {
    HStack {
      if(message.from == "me") {
        Spacer()
      }
      
      HStack {
        if(message.from == "me") {
          Spacer()
        }
        Text(message.text)
          .padding(.horizontal, 7)
          .padding(.vertical, 5)
          .background(message.from == "me" ? Color.brand : Color.receivedBubble)
          .foregroundColor(message.from == "me" ? Color.black : Color.white)
          .cornerRadius(8)
          .frame(alignment: .leading)
          .font(.system(size: 14))
      }
      .frame(maxWidth: maxWidth, alignment: message.from == "me" ? .trailing : .leading)
      
      if(message.from != "me") {
        Spacer()
      }
    }
    .frame(maxWidth: .infinity)
    .edgesIgnoringSafeArea(.horizontal)
  }
}

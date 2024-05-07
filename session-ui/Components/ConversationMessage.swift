import Foundation
import SwiftUI
import CoreData

struct ConversationMessage: View {
  @ObservedObject var message: Message
  let maxWidth: CGFloat
  
  var body: some View {
    HStack {
      if(!message.isIncoming) {
        Spacer()
      }
      
      HStack(alignment: .bottom, spacing: 0) {
        if(!message.isIncoming) {
          Spacer()
        }
        if(message.status == .Sending) {
          ProgressView()
            .controlSize(.small)
            .frame(width: 12, height: 12)
            .padding(.bottom, 3)
            .padding(.trailing, 5)
        }
        if(message.status == .Errored) {
          Image(systemName: "exclamationmark.triangle.fill")
            .resizable().scaledToFit()
            .frame(width: 10, height: 10)
            .foregroundColor(Color.yellow)
        }
        Text(message.textContent ?? "")
          .padding(.leading, message.isIncoming ? 13 : 10)
          .padding(.trailing, message.isIncoming ? 10 : 13)
          .padding(.vertical, 5)
          .background(message.isIncoming == false ? Color.brand : Color.receivedBubble)
          .foregroundColor(message.isIncoming == false ? Color.black : Color.white)
          .clipShape(BubbleShape(myMessage: !message.isIncoming))
          .frame(alignment: .leading)
          .font(.system(size: 14))
          .lineLimit(.max)
      }
      .frame(maxWidth: maxWidth, alignment: message.isIncoming == false ? .trailing : .leading)
      
      if(!message.isIncoming) {
        Spacer()
      }
    }
    .frame(maxWidth: .infinity, alignment: message.isIncoming == false ? .trailing : .leading)
    .edgesIgnoringSafeArea(.horizontal)
  }
}

struct ConversationMessage_Previews: PreviewProvider {
  static var previews: some View {
    let previewContext = PersistenceController.preview.container.viewContext
    struct Static {
      static var mocksInserted = false
      static var conversationId: UUID = UUID()
    }
    if !Static.mocksInserted {
      putMessagesMocks(into: previewContext, conversationId: Static.conversationId)
      Static.mocksInserted = true
    }
    var messages: [Message] {
      let request: NSFetchRequest<Message> = Message.fetchMessagesForConvoRequest(conversation: Static.conversationId)
      return try! previewContext.fetch(request)
    }
    return VStack {
      GeometryReader { geometry in
        ScrollView {
          Spacer(minLength: 20)
          ForEach(messages) { msg in
            ConversationMessage(message: msg, maxWidth: geometry.size.width * 0.8)
          }
          Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
        .edgesIgnoringSafeArea(.horizontal)
        .padding(.horizontal, 5)
        .defaultScrollAnchor(.bottom)
      }
    }
    .frame(maxWidth: .infinity)
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(AccountContext(context: PersistenceController.preview.container.viewContext))
    .environmentObject(NavigationModel())
    .background(Color.grayBackground)
    .ignoresSafeArea()
  }
}

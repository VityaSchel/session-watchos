import Foundation
import SwiftUI
import CoreData

struct ConversationMessage: View {
  let message: Message
  let maxWidth: CGFloat
  
  var body: some View {
    HStack {
      if(!message.isIncoming) {
        Spacer()
      }
      
      HStack {
        if(!message.isIncoming) {
          Spacer()
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
    .frame(maxWidth: .infinity)
    .edgesIgnoringSafeArea(.horizontal)
  }
}

struct ConversationMessage_Previews: PreviewProvider {
  static var previews: some View {
    let previewContext = PersistenceController.preview.container.viewContext
    struct Static {
      static var mocksInserted = false
    }
    if !Static.mocksInserted {
      putMessagesMocks(into: previewContext)
      Static.mocksInserted = true
    }
    var messages: [Message] {
      let request: NSFetchRequest<Message> = Message.fetchRequest()
      return try! previewContext.fetch(request)
    }
    return GeometryReader { geometry in
      ScrollView {
        ForEach(messages) { msg in
          ConversationMessage(message: msg, maxWidth: geometry.size.width * 0.8)
        }
      }
      .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
      .environmentObject(NavigationModel())
      .background(Color.grayBackground)
      .ignoresSafeArea()
    }
  }
}

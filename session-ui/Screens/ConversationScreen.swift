import Foundation
import SwiftUI
import CoreData

struct ConversationScreen: View {
  @Environment(\.managedObjectContext) var context
  @State private var messages: [Message] = []
  var conversation: ConversationScreenDetails
  
  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 5) {
        ScrollView {
          if messages.isEmpty {
            Text(NSLocalizedString("emptyConversation", comment: "Conversation screen with no messages"))
              .foregroundColor(.gray)
              .multilineTextAlignment(.center)
          } else {
            ForEach(messages) { message in
              ConversationMessage(message: message, maxWidth: geometry.size.width * 0.8)
            }
          }
        }
        .frame(maxWidth: .infinity)
        .edgesIgnoringSafeArea(.horizontal)
        .padding(.horizontal, 5)
        .defaultScrollAnchor(.bottom)
        
        MessageInput(onSubmit: { text in
          guard let conversationObject = try! context.existingObject(with: conversation.cdObjectId) as? Conversation else {
            return
          }
          
          let newMessage = Message(context: context)
          newMessage.id = UUID()
          newMessage.textContent = text
          newMessage.conversation = conversation.uuid
          newMessage.isIncoming = false
          newMessage.status = .Sending
          newMessage.timestamp = Int64(Date().timeIntervalSince1970*1000)
          conversationObject.lastMessage = ConversationLastMessage(
            isIncoming: false,
            textContent: text
          )
          saveContext(context: context)
          
          messages.append(newMessage)
          Task {
            await MessagesSender.storeMessage(newMessage, recipientPubKey: conversationObject.sessionID)
          }
        })
      }
      .frame(maxWidth: .infinity)
      .background(Color.black)
      .navigationTitle(conversation.title)
      .navigationBarTitleDisplayMode(.inline)
    }
    .onAppear {
      fetchMessages()
    }
  }
  
  private func fetchMessages() {
    let request: NSFetchRequest<Message> = Message.fetchMessagesForConvoRequest(conversation: conversation.uuid)
    do {
      messages = try context.fetch(request)
    } catch {
      print("Error fetching conversations: \(error)")
    }
  }
}

struct ConversationScreen_Previews: PreviewProvider {
  let previewContext = PersistenceController.preview.container.viewContext
  static var previews: some View {
    ConversationScreen(conversation: ConversationScreenDetails(title: "hloth", uuid: UUID(), cdObjectId: NSManagedObjectID()))
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .frame(maxWidth: .infinity)
    .background(Color.black)
  }
}

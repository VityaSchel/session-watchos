import Foundation
import SwiftUI
import CoreData

struct ConversationScreen: View {
  @Environment(\.managedObjectContext) var context
  var conversation: ConversationScreenDetails
  
  @FetchRequest
  var messages: FetchedResults<Message>
  
  init(_ convo: ConversationScreenDetails) {
    conversation = convo
    _messages = FetchRequest(
      fetchRequest: Message.fetchMessagesForConvoRequest(conversation: convo.uuid),
      animation: .default
    )
  }
  
  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 5) {
        ScrollView {
          if messages.isEmpty {
            Spacer(minLength: 20)
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
          Task {
            do {
              let (storedMessageHash, syncMessageHash) = try await MessagesSender.storeMessage(newMessage, recipientPubKey: conversationObject.sessionID)
              newMessage.status = .Sent
              let seenMsg = SeenMessage(context: context)
              seenMsg.messageHash = storedMessageHash
              let seenSyncMsg = SeenMessage(context: context)
              seenSyncMsg.messageHash = syncMessageHash
            } catch let error {
              print("Error while sending message", error)
              newMessage.status = .Errored
            }
            saveContext(context: context)
          }
        })
      }
      .frame(maxWidth: .infinity)
      .background(Color.black)
      .navigationTitle(conversation.title)
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

struct ConversationScreen_Previews: PreviewProvider {
  let previewContext = PersistenceController.preview.container.viewContext
  static var previews: some View {
    ConversationScreen(ConversationScreenDetails(title: "hloth", uuid: UUID(), cdObjectId: NSManagedObjectID()))
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .frame(maxWidth: .infinity)
    .background(Color.black)
  }
}

import Foundation
import SwiftUI
import CoreData

enum ConversationType {
  case directMessages, closedGroup, openCommunity
}

typealias Conversation = DirectMessagesConversation

struct ConversationsList: View {
  var conversations: [DirectMessagesConversation]
  
  var body: some View {
    if conversations.isEmpty {
      InlineIconText(text: NSLocalizedString("noConversations", comment: "No conversations found in ConversationsList"), iconName: "square.and.pencil")
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
    } else {
      List(conversations, id: \.id) { conversation in
        ConversationLink(conversation: conversation)
      }
    }
  }
}

struct ConversationLink: View {
  var conversation: Conversation
  var title: String {
    conversation.displayName != nil
    ? conversation.displayName!
    : conversation.sessionID
  }
  
  var body: some View {
    NavigationLink(value: Routes.Conversation(ConversationScreenDetails(title: title, uuid: conversation.id))) {
      VStack {
        HStack(spacing: 10) {
          Avatar(avatar: conversation.avatar, title: title)
          Text(title)
            .font(.headline)
            .lineLimit(2)
        }
        if conversation.lastMessage != nil {
          LastMessage(lastMessage: conversation.lastMessage!)
        }
      }
    }
    .swipeActions(allowsFullSwipe: false) {
      Button(role: .destructive) {
        print("Awesome!")
      } label: {
        Label("Delete", systemImage: "trash")
      }
      .tint(.red)
    }
  }
}

struct Avatar: View {
  var avatar: Data?
  var title: String
  var avatarFallback: String {
    let words = title.split(separator: " ")
    if words.count >= 2 {
      return String(words[0].prefix(1) + words[1].prefix(1))
    } else {
      if title.starts(with: "05") && title.test("^[a-f0-9]{66}$") {
        return String(title[title.index(title.startIndex, offsetBy: 2)..<title.index(title.startIndex, offsetBy: 4)]) // я такой хуйни давно не видел
      } else {
        return String(title.prefix(2))
      }
    }
  }
  
  var body: some View {
    ZStack {
      if let data = avatar, let uiImage = UIImage(data: data) {
        Image(uiImage: uiImage)
      } else {
        Circle()
            .frame(width: 40, height: 40)
            .foregroundColor(Color.gray)
        Text(avatarFallback.uppercased(with: .none)).foregroundStyle(Color(UIColor.white))
      }
    }
    .frame(width: 40, height: 50)
  }
}

struct LastMessage: View {
  var lastMessage: ConversationLastMessage
  
  var body: some View {
    Text(lastMessage.textContent)
      .lineLimit(2)
      .padding(.bottom, 10)
  }
}

struct ConversationsList_Previews: PreviewProvider {
  static var previews: some View {
    let previewContext = PersistenceController.preview.container.viewContext
    struct Static {
      static var mocksInserted = false
    }
    if !Static.mocksInserted {
      putConversationsMocks(into: previewContext)
      Static.mocksInserted = true
    }
    var conversations: [DirectMessagesConversation] {
      let request: NSFetchRequest<DirectMessagesConversation> = DirectMessagesConversation.fetchRequest()
      return try! previewContext.fetch(request)
    }
    return VStack {
      Spacer()
        .frame(height: 60)
      ConversationsList(conversations: conversations)
    }
      .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
      .environmentObject(NavigationModel())
      .background(Color.grayBackground)
      .ignoresSafeArea()
  }
}

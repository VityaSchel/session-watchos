import Foundation
import SwiftUI
import CoreData

enum ConversationType {
  case directMessages, closedGroup, openCommunity
}

typealias Conversation = DirectMessagesConversation

struct ConversationsList: View {
  @EnvironmentObject var dataController: DataController
  @Environment(\.managedObjectContext) var context
  static var getConversationsFetchRequest: NSFetchRequest<Conversation> {
    let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
    request.sortDescriptors = []
    return request
  }
  @FetchRequest(fetchRequest: getConversationsFetchRequest)
  var conversations: FetchedResults<Conversation>

  
  var body: some View {
    if conversations.isEmpty {
      InlineIconText(text: NSLocalizedString("noConversations", comment: "No conversations found in ConversationsList"), iconName: "square.and.pencil")
        .foregroundColor(.gray)
        .multilineTextAlignment(.center)
    } else {
      Spacer()
        .frame(height: 60)
      List(conversations, id: \.id) { conversation in
        ConversationLink(conversation: conversation)
      }
      Spacer(minLength: 20)
    }
  }
}

struct ConversationLink: View {
  @Environment(\.managedObjectContext) var context
  
  var conversation: Conversation
  var title: String {
    conversation.displayName != nil
    ? conversation.displayName!
    : conversation.sessionID
  }
  
  var body: some View {
    NavigationLink(value: Routes.Conversation(ConversationScreenDetails(title: title, uuid: conversation.id, cdObjectId: conversation.objectID))) {
      VStack(alignment: .leading) {
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
        context.delete(conversation)
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
    HStack(alignment: .center, spacing: 0) {
      if !lastMessage.isIncoming {
        Text(NSLocalizedString("youPrefix", comment: "Conversations list last message preview"))
          .foregroundColor(Color.gray)
      }
      Text(lastMessage.textContent)
        .lineLimit(1)
        .multilineTextAlignment(.leading)
    }
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
    return VStack {
      ConversationsList()
    }
      .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
      .environmentObject(NavigationModel())
      .environmentObject(DataController())
      .background(Color.grayBackground)
      .ignoresSafeArea()
  }
}

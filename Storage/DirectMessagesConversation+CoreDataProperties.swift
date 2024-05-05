import Foundation
import CoreData

public class ConversationLastMessage: NSObject {
  var textContent: String
  
  init(textContent: String) {
    self.textContent = textContent
  }
}

extension DirectMessagesConversation {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<DirectMessagesConversation> {
        return NSFetchRequest<DirectMessagesConversation>(entityName: "DirectMessagesConversation")
    }

    @NSManaged public var displayName: String?
    @NSManaged public var id: UUID
    @NSManaged public var avatar: Data?
    @NSManaged public var lastMessage: ConversationLastMessage?
    @NSManaged public var sessionID: String
}

extension DirectMessagesConversation : Identifiable {

}

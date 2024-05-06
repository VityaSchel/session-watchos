import Foundation
import CoreData

public class ConversationLastMessage: NSObject {
  var isIncoming: Bool
  var textContent: String
  
  init(isIncoming: Bool, textContent: String) {
    self.isIncoming = isIncoming
    self.textContent = textContent
  }
}

extension DirectMessagesConversation {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<DirectMessagesConversation> {
    return NSFetchRequest<DirectMessagesConversation>(entityName: "DirectMessagesConversation")
  }
  
  @nonobjc public class func fetchByUuid(uuid: UUID) -> NSFetchRequest<DirectMessagesConversation> {
    let fetchRequest: NSFetchRequest<DirectMessagesConversation> = DirectMessagesConversation.fetchRequest()
    fetchRequest.predicate = NSPredicate(
      format: "id = %@", uuid as CVarArg
    )
    return fetchRequest
  }
  
  @NSManaged public var displayName: String?
  @NSManaged public var id: UUID
  @NSManaged public var avatar: Data?
  @NSManaged public var lastMessage: ConversationLastMessage?
  @NSManaged public var sessionID: String
}

extension DirectMessagesConversation : Identifiable {
  
}

import Foundation
import CoreData

extension Message {
  
  @nonobjc public class func fetchRequest() -> NSFetchRequest<Message> {
    return NSFetchRequest<Message>(entityName: "Message")
  }
  @nonobjc public class func fetchMessagesForConvoRequest(conversation: UUID) -> NSFetchRequest<Message> {
    let fetchRequest: NSFetchRequest<Message> = Message.fetchRequest()
    fetchRequest.predicate = NSPredicate(
      format: "conversation = %@", conversation as CVarArg
    )
    let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: true)
    fetchRequest.sortDescriptors = [sortDescriptor]
    return fetchRequest
  }
  
  @NSManaged public var textContent: String?
  @NSManaged public var id: UUID
  @NSManaged public var conversation: UUID
  @NSManaged public var isIncoming: Bool
  @NSManaged public var timestamp: Int64
  
}

extension Message : Identifiable {
  
}

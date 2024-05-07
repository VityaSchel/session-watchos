import Foundation
import CoreData

extension SeenMessage {
  @nonobjc public class func fetchRequest() -> NSFetchRequest<SeenMessage> {
    return NSFetchRequest<SeenMessage>(entityName: "SeenMessage")
  }
  
  @nonobjc public class func fetchSeenByHash(hash: String) -> NSFetchRequest<SeenMessage> {
    let fetchRequest: NSFetchRequest<SeenMessage> = SeenMessage.fetchRequest()
    fetchRequest.predicate = NSPredicate(
      format: "messageHash == %@", hash
    )
    return fetchRequest
  }
  
  @nonobjc public class func fetchSeenPolled() -> NSFetchRequest<SeenMessage> {
    let fetchRequest: NSFetchRequest<SeenMessage> = SeenMessage.fetchRequest()
    fetchRequest.predicate = NSPredicate(
      format: "polled == YES"
    )
    let sortDescriptor = NSSortDescriptor(key: "timestamp", ascending: false)
    fetchRequest.sortDescriptors = [sortDescriptor]
    return fetchRequest
  }
  
  @NSManaged public var messageHash: String
  @NSManaged public var timestamp: Int64
  @NSManaged public var polled: Bool
}

extension SeenMessage : Identifiable {
  
}

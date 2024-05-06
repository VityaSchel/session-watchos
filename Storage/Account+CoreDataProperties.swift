import Foundation
import CoreData


extension Account {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Account> {
        return NSFetchRequest<Account>(entityName: "Account")
    }
  
    @nonobjc public class func fetchBySessionID(sessionID: String) -> NSFetchRequest<Account> {
      let fetchRequest: NSFetchRequest<Account> = Account.fetchRequest()
      fetchRequest.predicate = NSPredicate(
        format: "sessionID = %@", sessionID as CVarArg
      )
      return fetchRequest
    }

    @NSManaged public var displayName: String?
    @NSManaged public var sessionID: String
    @NSManaged public var conversations: DirectMessagesConversation?

}

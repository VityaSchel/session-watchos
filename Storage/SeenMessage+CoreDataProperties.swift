import Foundation
import CoreData

extension SeenMessage {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SeenMessage> {
        return NSFetchRequest<SeenMessage>(entityName: "SeenMessage")
    }

    @NSManaged public var messageHash: String
}

extension SeenMessage : Identifiable {

}

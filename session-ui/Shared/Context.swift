import Foundation
import CoreData

func saveContext (context: NSManagedObjectContext) {
  if context.hasChanges {
    do {
      try context.save()
    } catch {
      context.rollback()
      let nserror = error as NSError
      fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
    }
  }
}

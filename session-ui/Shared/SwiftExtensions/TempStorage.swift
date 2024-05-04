import CoreData

extension NSPersistentContainer {
  static func temporaryInMemoryContainer() -> NSPersistentContainer {
    let container = NSPersistentContainer(name: "DirectMessagesConversation")
    let description = NSPersistentStoreDescription()
    description.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [description]
    container.loadPersistentStores { (storeDescription, error) in
      if let error = error {
        fatalError("Unresolved error \(error)")
      }
    }
    return container
  }
}

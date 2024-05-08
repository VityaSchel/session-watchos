import SwiftUI
import CoreData

class PersistenceController {
  static let shared = PersistenceController()
  var container: NSPersistentContainer
  var inMemory: Bool
  var dataController: DataController
  
  init(inMemory: Bool = false) {
    self.inMemory = inMemory
    self.container = PersistenceController.createContainer(inMemory: inMemory)
    self.dataController = DataController()
  }
  
  static func createContainer(inMemory: Bool) -> NSPersistentContainer {
    print("Initializing Storage container")
    let container = NSPersistentContainer(name: "Storage")
    if inMemory {
      let description = NSPersistentStoreDescription()
      description.type = NSInMemoryStoreType
      description.url = URL(fileURLWithPath: "/dev/null")
      container.persistentStoreDescriptions = [description]
    }
    
    container.loadPersistentStores { description, error in
      if let error = error {
        print("Unresolved error \(error.localizedDescription)")
      }
    }
    container.viewContext.automaticallyMergesChangesFromParent = true
    return container
  }
  
//  func deleteAllData() throws {
//    let backgroundContext = container.newBackgroundContext()
//    backgroundContext.perform {
//      do {
//        let entities = self.container.managedObjectModel.entities
//        
//        for entity in entities {
//          let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entity.name!)
//          let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
//          let objects = try container.viewContext.fetch(fetchRequest)
//          print("Deleting", objects.count, "entities")
//          for object in objects {
//            container.viewContext.delete(object as! NSManagedObject)
//          }
            
//          do {
//            let result = try container.persistentStoreCoordinator.execute(deleteRequest, with: container.viewContext) as? NSBatchDeleteResult
//            let objectIDArray = result?.result as? [NSManagedObjectID]
//            let changes = [NSDeletedObjectsKey : objectIDArray]
//            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes as [AnyHashable : Any], into: [container.viewContext])
//            container.viewContext.reset()
//          } catch let error as NSError {
//            print(error)
//          }
          
//          print("Deleted \(entity.name ?? "")")
//        }
//    
//        try container.viewContext.save()
//      } catch {
//        print("Error deleting data: \(error.localizedDescription)")
//      }
//    }
//  }
  
  static var preview: PersistenceController = {
    let controller = PersistenceController(inMemory: true)
    return controller
  }()
  
  func save() {
    let context = container.viewContext
    
    if context.hasChanges {
      do {
        try context.save()
      } catch {
        print("Error while saving data to Storage")
      }
    }
  }
}

class DataController: ObservableObject {
  @Published var refreshData: Bool = false
}

@main
struct SessionMessengerApp: App {
  let persistenceController = PersistenceController.shared
  @Environment(\.scenePhase) var scenePhase
  
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
        .environmentObject(AccountContext(context: persistenceController.container.viewContext))
        .environmentObject(NavigationModel())
        .environmentObject(PersistenceController.preview.dataController)
    }
    .onChange(of: scenePhase, {
      persistenceController.save()
    })
  }
}

struct SessionMessengerApp_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
      .environmentObject(AccountContext(context: PersistenceController.preview.container.viewContext))
      .environmentObject(NavigationModel())
      .environmentObject(PersistenceController.preview.dataController)
  }
}

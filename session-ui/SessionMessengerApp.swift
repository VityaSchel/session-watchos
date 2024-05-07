import SwiftUI
import CoreData

struct PersistenceController {
  static let shared = PersistenceController()
  let container: NSPersistentContainer
  
  static var preview: PersistenceController = {
    let controller = PersistenceController(inMemory: true)
    return controller
  }()
  
  init(inMemory: Bool = false) {
    container = NSPersistentContainer(name: "Storage")
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
  }
  
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
  }
}

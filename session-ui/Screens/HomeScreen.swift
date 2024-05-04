import Foundation
import SwiftUI
import WatchKit
import CoreData

struct HomeScreen: View {
  @Environment(\.managedObjectContext) var managedObjectContext
  @State private var conversations: [DirectMessagesConversation] = []
  
  var body: some View {
    VStack {
      if !conversations.isEmpty {
        Spacer()
          .frame(height: 60)
      }
      ConversationsList(conversations: conversations)
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        NavigationLink(value: Routes.NewConversation) {
          Image(systemName: "square.and.pencil")
            .frame(width: 30, height: 30)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.interactable)
        .foregroundColor(Color.brand)
        .cornerRadius(.infinity)
      }
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(value: Routes.Settings) {
          Image(systemName: "gear")
            .frame(width: 30, height: 30)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.interactable)
        .foregroundColor(Color.brand)
        .cornerRadius(.infinity)
      }
    }
    .ignoresSafeArea()
    .onAppear() {
      fetchConversations()
    }
  }
  
  private func fetchConversations() {
    let request: NSFetchRequest<DirectMessagesConversation> = DirectMessagesConversation.fetchRequest()
    do {
      conversations = try managedObjectContext.fetch(request)
    } catch {
      print("Error fetching conversations: \(error)")
    }
  }
}

struct HomeScreen_Previews: PreviewProvider {
  static var previews: some View {
    let previewContext = PersistenceController.preview.container.viewContext
    struct Static {
      static var mocksInserted = false
    }
    if !Static.mocksInserted {
      putConversationsMocks(into: previewContext)
      Static.mocksInserted = true
    }
    return HomeScreen()
      .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
      .environmentObject(NavigationModel())
      .background(Color.grayBackground)
      .ignoresSafeArea()
  }
}


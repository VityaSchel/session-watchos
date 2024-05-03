import Foundation
import SwiftUI

enum NewConversationType: Identifiable {
  case directMessages
  case closedGroup
  case joinCommunity
  
  var id: Int {
    hashValue
  }
}

struct NewConversationScreen: View {
  @State private var newConversationType: NewConversationType?
  
  var body: some View {
    VStack {
      List {
        Button(action: {
          newConversationType = .directMessages
        }) {
          HStack(spacing: 10) {
            Image(systemName: "message")
              .frame(width: 20)
            Text(NSLocalizedString("newDirectMessage", comment: "New conversation menu button"))
              .font(.system(size: 14))
          }
        }
        Button(action: {
          
        }) {
          HStack(spacing: 10) {
            Image(systemName: "person.2")
              .frame(width: 20)
            Text(NSLocalizedString("createClosedGroup", comment: "New conversation menu button"))
              .font(.system(size: 14))
          }
        }
        .disabled(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
        Button(action: {
          
        }) {
          HStack(spacing: 10) {
            Image(systemName: "globe")
              .frame(width: 20)
            Text(NSLocalizedString("joinCommunity", comment: "New conversation menu button"))
              .font(.system(size: 14))
          }
        }
        .disabled(/*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/)
      }
    }
    .navigationTitle(NSLocalizedString("newConversationTitle", comment: "Title of NewConversation screen"))
    .sheet(item: $newConversationType) { type in
      switch type {
//      case .directMessages:
      default:
        NewDirectMessagesConversationScreen()
      }
    }
  }
}

struct NewConversationScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      NewConversationScreen()
        .background(Color.grayBackground)
    }
  }
}

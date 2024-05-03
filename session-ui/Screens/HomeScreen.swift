import Foundation
import SwiftUI
import WatchKit

struct HomeScreen: View {
  var body: some View {
    VStack {
      Spacer()
        .frame(height: 60)
      List {
        NavigationLink(destination: ConversationScreen()) {
          Text("Conversation 1")
        }
        .background(Color.interactable)
        NavigationLink(destination: ConversationScreen()) {
          Text("Conversation 2")
        }
        .background(Color.interactable)
      }
    }
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        NavigationLink(destination: NewConversationScreen()) {
          Image(systemName: "plus")
            .frame(width: 30, height: 30)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.interactable)
        .foregroundColor(Color.brand)
        .cornerRadius(.infinity)
      }
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(destination: SettingsScreen()) {
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
  }
}

struct HomeScreen_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      HomeScreen()
    }
    .background(Color.grayBackground)
    .ignoresSafeArea()
  }
}


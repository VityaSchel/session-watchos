import Foundation
import SwiftUI

struct HomeScreen: View {
  var body: some View {
    VStack {
      HStack() {
        NavigationLink(destination: NewConversationScreen()) {
          Image(systemName: "plus")
            .frame(width: 30, height: 30)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.interactable)
        .foregroundColor(Color.brand)
        .cornerRadius(.infinity)
        
        Spacer()
        NavigationLink(destination: SettingsScreen()) {
          Image(systemName: "gear")
            .frame(width: 30, height: 30)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.interactable)
        .foregroundColor(Color.brand)
        .cornerRadius(.infinity)
        
      }
      .frame(height: 30)
      .padding(.top, 15)
      .padding(.horizontal, 15)
      .padding(.bottom, 10)
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


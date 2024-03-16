//
//  HomePage.swift
//  session-ui
//
//  Created by Виктор Щелочков on 16.03.2024.
//

import Foundation
import SwiftUI

struct HomePage: View {
  var body: some View {
    VStack {
      List {
        NavigationLink(destination: ConversationScreen()) {
          HStack {
              Image(systemName: "plus")
              Text("New conversation")
          }
        }
        NavigationLink(destination: ConversationScreen()) {
          Text("Conversation 1")
        }
        NavigationLink(destination: ConversationScreen()) {
          Text("Conversation 2")
        }
      }
    }
  }
}

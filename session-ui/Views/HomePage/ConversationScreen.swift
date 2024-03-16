//
//  ConversationScreen.swift
//  session-ui
//
//  Created by Виктор Щелочков on 16.03.2024.
//

import Foundation
import SwiftUI


struct ConversationScreen: View {
  let components: [SessionConversationMessage] = [
    SessionConversationMessage(id: "1", text: "Hello", from: "me"),
    SessionConversationMessage(id: "2", text: "World", from: "me"),
    SessionConversationMessage(id: "3", text: "Foobar foo bar foobarfoobarfoobarfoobar", from: "me"),
    SessionConversationMessage(id: "4", text: "Hello world!", from: "anotheruser"),
  ]
  
  var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 5) {
        ScrollView {
          ForEach(components) { component in
            ConversationMessage(message: component, maxWidth: geometry.size.width * 0.8)
          }
        }
        .frame(maxWidth: .infinity)
        .edgesIgnoringSafeArea(.horizontal)
        .padding(.horizontal, 5)
        
        MessageInput()
      }
      .frame(maxWidth: .infinity)
      .background(Color.black)
    }
  }
}


//
//  MessageInput.swift
//  session-ui
//
//  Created by Виктор Щелочков on 16.03.2024.
//

import Foundation
import SwiftUI

struct MessageInput: View {
  @State private var message = ""
  
  var body: some View {
    TextField("Type message...", text: $message, onCommit: {
      print("Hooray \(message)")
      message = ""
    })
    .frame(maxWidth: .infinity)
  }
}

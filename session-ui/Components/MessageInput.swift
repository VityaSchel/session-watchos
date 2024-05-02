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

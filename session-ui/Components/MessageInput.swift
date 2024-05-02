import Foundation
import SwiftUI

struct MessageInput: View {
  @State private var message = ""
  
  var body: some View {
    TextField("Type message...", text: $message, onCommit: {
      message = ""
    })
    .frame(maxWidth: .infinity)
  }
}

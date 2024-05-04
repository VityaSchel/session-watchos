import Foundation
import SwiftUI

struct InlineIconText: View {
  let text: String
  let iconName: String
  
  var body: some View {
    textComponents()
  }
  
  private func textComponents() -> Text {
    let components = text.components(separatedBy: "{icon}")
    var combinedText = Text("")
    
    for (index, component) in components.enumerated() {
      combinedText = combinedText + Text(component)
      if index < components.count - 1 {
        combinedText = combinedText + Text(Image(systemName: iconName)) + Text(" ")
      }
    }
    
    return combinedText
  }
}

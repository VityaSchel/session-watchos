import SwiftUI

struct ContentView: View {
  @State private var loginMenuActive = false
  
  var body: some View {
    NavigationView {
      if loginMenuActive {
        LoginMenu()
      } else {
        HomePage()
      }
    }
    .background(Color.background)
    .ignoresSafeArea()
  }
}

#Preview {
    ContentView()
}

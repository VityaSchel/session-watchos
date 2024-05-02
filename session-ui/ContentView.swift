import SwiftUI

struct ContentView: View {
  @State private var loginMenuActive = false
  
  var body: some View {
    NavigationView {
      if loginMenuActive {
        LoginScreen()
      } else {
        HomeScreen()
      }
    }
    .background(Color.grayBackground)
    .ignoresSafeArea()
  }
}

#Preview {
  ContentView()
}

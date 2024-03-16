//
//  ContentView.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 12.03.2024.
//

import SwiftUI

struct ContentView: View {
  @State private var loginMenuActive = true
  
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

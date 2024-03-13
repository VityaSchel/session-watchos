//
//  ContentView.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 12.03.2024.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    NavigationView {
      VStack(alignment: .leading) {
        SessionLogo()
        .fill(Color.brand)
        .frame(width: 20, height: 20)
        .padding(.leading, 10)
        
        Text("Welcome to Session")
        .font(.subheadline)
        .fontWeight(.bold)
        .padding(.leading, 10)
        .padding(.top, 5)
        .padding(.bottom, 10)
        .foregroundColor(Color.brand)
        
        List {
          NavigationLink(destination: LoginScreen()) {
            Text("Login with mnemonic")
            .font(.system(size: 16))
          }
          NavigationLink(destination: SignupScreen()) {
            Text("Create Session ID")
            .font(.system(size: 16))
          }
        }
        .padding(.horizontal, 5)
      }
    }
    .background(Color.background)
    .ignoresSafeArea()
  }
}

#Preview {
    ContentView()
}

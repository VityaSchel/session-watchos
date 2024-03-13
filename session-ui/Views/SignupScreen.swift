//
//  SignupScreen.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 12.03.2024.
//

import Foundation
import SwiftUI

struct SignupScreen: View {
  @State private var displayName = ""
  
    var body: some View {
      VStack(spacing: 10) {
        TextField("Your profile name", text: $displayName)
        
        Button(action: {
            print("Button with icon was tapped")
        }) {
            HStack {
              Text("Sign up")
                .fontWeight(.bold)
                .foregroundColor(Color.background)
              Image(systemName: "arrow.right")
                .foregroundColor(Color.background)
            }
        }
        .tint(Color.brand)
        .buttonStyle(.borderedProminent)
      }
      .padding(.horizontal, 5)
    }
}

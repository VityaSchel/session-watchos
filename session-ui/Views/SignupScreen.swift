//
//  SignupScreen.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 12.03.2024.
//

import Foundation
import SwiftUI
import SessionUtilitiesKit

struct SignupScreen: View {
  @State private var displayName = ""
  
    var body: some View {
      VStack(spacing: 10) {
        TextField("Your profile name", text: $displayName)
        
        Button(action: {
          let seed = Randomness.generateRandomBytes(numberBytes: 16)
          (ed25519KeyPair, x25519KeyPair) = try! Identity.generate(from: seed)
          print(ed25519KeyPair)
          print(x25519KeyPair)
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

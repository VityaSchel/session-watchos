//
//  SignupScreen.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 12.03.2024.
//

import Foundation
import SwiftUI
import SessionUtilitiesKit
import SessionMessagingKit
import SignalUtilitiesKit
import SessionSnodeKit

struct SignupScreen: View {
  @State private var displayName = ""
  @State private var showAlert = false
  @State private var alertMessage = ""
  
    var body: some View {
      VStack(spacing: 10) {
        TextField("Your profile name", text: $displayName)
        
        Button(action: {
          do {
            let seed = try Randomness.generateRandomBytes(numberBytes: 16)
            let (ed25519KeyPair, x25519KeyPair) = try Identity.generate(from: seed)
            print("Session ID \(x25519KeyPair.hexEncodedPublicKey)")
            let profileName = displayName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !ProfileManager.isToLong(profileName: displayName) else {
              showAlert = true
              alertMessage = "Profile name is too long"
            }
            ProfileManager.updateLocal(
                queue: .global(qos: .default),
                profileName: displayName
            )
            
            print("complete registration")
            
            Storage.shared.write { db in
                try Profile
                    .filter(id: getUserHexEncodedPublicKey(db))
                    .updateAllAndConfig(
                        db,
                        Profile.Columns.lastNameUpdate.set(to: Date().timeIntervalSince1970)
                    )
            }
            Identity.didRegister()
            GetSnodePoolJob.run()
          } catch {
            showAlert = true
            alertMessage = "Couldn't generate key pair"
          }
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
      .alert(isPresented: $showAlert) {
        Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
      }
      .padding(.horizontal, 5)
    }
}

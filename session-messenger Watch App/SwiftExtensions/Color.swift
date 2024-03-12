//
//  color.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 12.03.2024.
//

import Foundation
import SwiftUI

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let red = CGFloat((int >> 16) & 0xFF) / 255.0
    let green = CGFloat((int >> 8) & 0xFF) / 255.0
    let blue = CGFloat(int & 0xFF) / 255.0
    self.init(red: red, green: green, blue: blue)
  }
}

import Foundation
import SwiftUI

extension Color {
  static let background = Color("Background")
  static let brand = Color("Brand")
  static let receivedBubble = Color("receivedBubble")

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

extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 6 || hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    if hexColor.count == 8 {
                        r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                        g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                        b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                        a = CGFloat(hexNumber & 0x000000ff) / 255
                    } else { // Assume 6 character hex
                        r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                        g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                        b = CGFloat(hexNumber & 0x0000ff) / 255
                        a = 1.0 // default alpha value
                    }

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}

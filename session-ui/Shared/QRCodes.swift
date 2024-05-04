import Foundation
import QRCode
import SwiftUI
import UIKit

func generateQRCode(content: String, errorCorrection: QRCode.ErrorCorrection = .low, additionalQuietZonePixels: UInt = 4) -> UIImage? {
  let doc = QRCode.Document(
    utf8String: content, 
    errorCorrection: errorCorrection
  )
  doc.design.backgroundColor(UIColor(hex: "#121212")!.cgColor)
  doc.design.shape.eye = QRCode.EyeShape.RoundedOuter()
  doc.design.shape.onPixels = QRCode.PixelShape.Horizontal()
  doc.design.foregroundStyle(QRCode.FillStyle.Solid(UIColor(hex: "#00F782")!.cgColor))
  doc.design.additionalQuietZonePixels = additionalQuietZonePixels
  doc.design.style.backgroundFractionalCornerRadius = 3.0
  let generated = doc.cgImage(CGSize(width: 800, height: 800))
  return generated?.representation.uiImage()
}

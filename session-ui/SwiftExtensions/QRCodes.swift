//
//  QRCodes.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 13.03.2024.
//

import Foundation
//import EFQRCode
//import QRCode
import SwiftUI
import UIKit
import QRCode

func generateQRCode(href: String) -> UIImage? {
  // EFQRCODE (does not work)
//  if let image = EFQRCode.generate(
//      for: string,
//      backgroundColor: UIColor(Color.background).cgColor,
//      foregroundColor: UIColor(Color.brand).cgColor
//  ) {
//      return UIImage(cgImage: image)
//  } else {
//      return nil
//  }
  
  // QRCODE (does not work)
//  guard let url = URL(string: href) else { return nil }
//  guard let qrData = QRCode(url: url) else { return nil }
//  let qrImage: UIImage?
//  do {
//    qrImage = try qrData.image()
//    return qrImage
//  } catch {
//    return nil
//  }
  
  let doc = QRCode.Document(utf8String: href, errorCorrection: .high)
  let generated = doc.cgImage(CGSize(width: 800, height: 800))
  return generated?.representation.uiImage()
}

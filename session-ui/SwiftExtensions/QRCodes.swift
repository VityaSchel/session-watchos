//
//  QRCodes.swift
//  session-messenger Watch App
//
//  Created by Виктор Щелочков on 13.03.2024.
//

import Foundation
import EFQRCode
import SwiftUI

func generateQRCode(from string: String) -> UIImage? {
  if let image = EFQRCode.generate(
      for: string,
      backgroundColor: nil,//UIColor(Color.background).cgColor,
      foregroundColor: nil//UIColor(Color.brand).cgColor
  ) {
      return UIImage(cgImage: image)
  } else {
      return nil
  }
}

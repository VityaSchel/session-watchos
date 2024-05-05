// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation

public enum Hex {
  public static func isValid(_ string: String) -> Bool {
    let allowedCharacters = CharacterSet(charactersIn: "0123456789ABCDEF") // stringlint:disable
    
    return string.uppercased().unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
  }
}

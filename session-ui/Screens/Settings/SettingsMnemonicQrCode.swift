import Foundation
import SwiftUI

struct SettingsMnemonicQrCodeScreen: View {
  @EnvironmentObject var account: AccountContext
  var mnemonic: String { return account.mnemonic! }
  @State private var qrCode: UIImage?
  
  var body: some View {
    VStack {
      Text(mnemonic)
        .font(.system(size: 10, design: .monospaced))
        .multilineTextAlignment(.center)
      Image(uiImage: qrCode ?? UIImage())
        .resizable()
        .interpolation(.none)
        .scaledToFit()
    }
    .navigationTitle(NSLocalizedString("mnemonic", comment: "Settings title"))
    .onAppear(perform: {
      qrCode = generateQRCode(content: mnemonic, errorCorrection: .low, additionalQuietZonePixels: 1)
    })
  }
}

struct SettingsMnemonicQrCode_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      SettingsMnemonicQrCodeScreen()
        .background(Color.grayBackground)
    }
  }
}


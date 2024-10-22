import Foundation
import SwiftUI

struct SigninScreen: View {
  @StateObject private var viewModel = SigninViewModel()
  
  var body: some View {
    VStack(spacing: 7) {
      ZStack {
        if viewModel.isLoading {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
        } else {
          Image(uiImage: viewModel.qrCodeImage ?? UIImage())
            .resizable()
            .interpolation(.none)
            .scaledToFit()
        }
      }
      
      Text(NSLocalizedString("scanToContinue", comment: "Sign in screen"))
        .font(.system(size: 14))
    }
    .onAppear {
      viewModel.startLoginFlow()
    }
    .alert(isPresented: $viewModel.showAlert) {
      Alert(title: Text("Error"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
    }
  }
}

// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import UIKit
import AVFoundation
import SessionUIKit
import SessionMessagingKit
import SessionUtilitiesKit

final class QRCodeVC : BaseVC, UIPageViewControllerDataSource, UIPageViewControllerDelegate, QRScannerDelegate {
    private let pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
    private var pages: [UIViewController] = []
    private var targetVCIndex: Int?
    
    // MARK: - Components
    
    private lazy var tabBar: TabBar = {
        let tabs = [
            TabBar.Tab(title: "vc_qr_code_view_my_qr_code_tab_title".localized()) { [weak self] in
                guard let self = self else { return }
                self.pageVC.setViewControllers([ self.pages[0] ], direction: .forward, animated: false, completion: nil)
            },
            TabBar.Tab(title: "vc_qr_code_view_scan_qr_code_tab_title".localized()) { [weak self] in
                guard let self = self else { return }
                self.pageVC.setViewControllers([ self.pages[1] ], direction: .forward, animated: false, completion: nil)
            }
        ]
        return TabBar(tabs: tabs)
    }()
    
    private lazy var viewMyQRCodeVC: ViewMyQRCodeVC = {
        let result = ViewMyQRCodeVC()
        result.qrCodeVC = self
        
        return result
    }()
    
    private lazy var scanQRCodePlaceholderVC: ScanQRCodePlaceholderVC = {
        let result = ScanQRCodePlaceholderVC()
        result.qrCodeVC = self
        
        return result
    }()
    
    private lazy var scanQRCodeWrapperVC: ScanQRCodeWrapperVC = {
        let message = "vc_qr_code_view_scan_qr_code_explanation".localized()
        let result = ScanQRCodeWrapperVC(message: message)
        result.delegate = self
        
        return result
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setNavBarTitle("vc_qr_code_title".localized())
        
        // Set up tab bar
        view.addSubview(tabBar)
        tabBar.pin(.top, to: .top, of: view.safeAreaLayoutGuide)
        tabBar.pin(.leading, to: .leading, of: view)
        tabBar.pin(.trailing, to: .trailing, of: view)
        
        // Set up page VC
        let containerView: UIView = UIView()
        view.addSubview(containerView)
        containerView.pin(.top, to: .bottom, of: tabBar)
        containerView.pin(.leading, to: .leading, of: view)
        containerView.pin(.trailing, to: .trailing, of: view)
        containerView.pin(.bottom, to: .bottom, of: view)
        
        let hasCameraAccess = (AVCaptureDevice.authorizationStatus(for: .video) == .authorized)
        pages = [ viewMyQRCodeVC, (hasCameraAccess ? scanQRCodeWrapperVC : scanQRCodePlaceholderVC) ]
        pageVC.dataSource = self
        pageVC.delegate = self
        pageVC.setViewControllers([ viewMyQRCodeVC ], direction: .forward, animated: false, completion: nil)
        addChild(pageVC)
        containerView.addSubview(pageVC.view)
        
        pageVC.view.pin(to: containerView)
        pageVC.didMove(toParent: self)
    }
    
    // MARK: - General
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController), index != 0 else { return nil }
        return pages[index - 1]
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = pages.firstIndex(of: viewController), index != (pages.count - 1) else { return nil }
        return pages[index + 1]
    }
    
    fileprivate func handleCameraAccessGranted() {
        DispatchQueue.main.async {
            self.pages[1] = self.scanQRCodeWrapperVC
            self.pageVC.setViewControllers([ self.scanQRCodeWrapperVC ], direction: .forward, animated: false, completion: nil)
        }
    }
    
    // MARK: - Updating
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        guard let targetVC = pendingViewControllers.first, let index = pages.firstIndex(of: targetVC) else { return }
        targetVCIndex = index
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating isFinished: Bool, previousViewControllers: [UIViewController], transitionCompleted isCompleted: Bool) {
        guard isCompleted, let index = targetVCIndex else { return }
        tabBar.selectTab(at: index)
    }
    
    // MARK: - Interaction
    
    @objc private func close() {
        dismiss(animated: true, completion: nil)
    }
    
    func controller(_ controller: QRCodeScanningViewController, didDetectQRCodeWith string: String, onError: (() -> ())?) {
        let hexEncodedPublicKey = string
        startNewPrivateChatIfPossible(with: hexEncodedPublicKey, onError: onError)
    }
    
    fileprivate func startNewPrivateChatIfPossible(with hexEncodedPublicKey: String, onError: (() -> ())?) {
        if !KeyPair.isValidHexEncodedPublicKey(candidate: hexEncodedPublicKey) {
            let modal: ConfirmationModal = ConfirmationModal(
                targetView: self.view,
                info: ConfirmationModal.Info(
                    title: "invalid_session_id".localized(),
                    body: .text("INVALID_SESSION_ID_MESSAGE".localized()),
                    cancelTitle: "BUTTON_OK".localized(),
                    cancelStyle: .alert_text,
                    afterClosed: onError
                )
            )
            self.present(modal, animated: true)
        }
        else {
            SessionApp.presentConversationCreatingIfNeeded(
                for: hexEncodedPublicKey,
                variant: .contact,
                dismissing: presentingViewController,
                animated: false
            )
        }
    }
}

private final class ViewMyQRCodeVC : UIViewController {
    weak var qrCodeVC: QRCodeVC!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        // Remove background color
        view.themeBackgroundColor = .clear
        
        // Set up title label
        let titleLabel = UILabel()
        titleLabel.font = .boldSystemFont(ofSize: isIPhone5OrSmaller ? CGFloat(40) : Values.massiveFontSize)
        titleLabel.text = "Scan Me"
        titleLabel.themeTextColor = .textPrimary
        titleLabel.textAlignment = .center
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 1
        titleLabel.set(.height, to: isIPhone5OrSmaller ? CGFloat(40) : Values.massiveFontSize)
        
        // Set up QR code image view
        let qrCodeImageView = UIImageView(
            image: QRCode.generate(for: getUserHexEncodedPublicKey(), hasBackground: false)
                .withRenderingMode(.alwaysTemplate)
        )
        qrCodeImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        qrCodeImageView.set(.width, to: .height, of: qrCodeImageView)
        qrCodeImageView.heightAnchor
            .constraint(lessThanOrEqualToConstant: (isIPhone5OrSmaller ? 180 : 240))
            .isActive = true
        
#if targetEnvironment(simulator)
#else
        // Note: For some reason setting this seems to stop the QRCode from rendering on the
        // simulator so only doing it on device
        qrCodeImageView.contentMode = .scaleAspectFit
#endif
        
        let qrCodeImageViewBackgroundView = UIView()
        qrCodeImageViewBackgroundView.layer.cornerRadius = 8
        qrCodeImageViewBackgroundView.addSubview(qrCodeImageView)
        qrCodeImageView.pin(
            to: qrCodeImageViewBackgroundView,
            withInset: 5    // The QRCode image has about 6pt of padding and we want 11 in total
        )
        
        ThemeManager.onThemeChange(observer: qrCodeImageView) { [weak qrCodeImageView, weak qrCodeImageViewBackgroundView] theme, _ in
            switch theme.interfaceStyle {
                case .light:
                    qrCodeImageView?.themeTintColorForced = .theme(theme, color: .textPrimary)
                    qrCodeImageViewBackgroundView?.themeBackgroundColorForced = nil
                    
                default:
                    qrCodeImageView?.themeTintColorForced = .theme(theme, color: .backgroundPrimary)
                    qrCodeImageViewBackgroundView?.themeBackgroundColorForced = .color(.white)
            }
            
        }
        
        // Set up QR code image view container
        let qrCodeImageViewContainer = UIView()
        qrCodeImageViewContainer.accessibilityLabel = "Your QR code"
        qrCodeImageViewContainer.isAccessibilityElement = true
        qrCodeImageViewContainer.addSubview(qrCodeImageViewBackgroundView)
        qrCodeImageViewBackgroundView.center(.horizontal, in: qrCodeImageViewContainer)
        qrCodeImageViewBackgroundView.pin(.top, to: .top, of: qrCodeImageViewContainer)
        qrCodeImageViewBackgroundView.pin(.bottom, to: .bottom, of: qrCodeImageViewContainer)
        
        // Set up explanation label
        let explanationLabel = UILabel()
        explanationLabel.font = .systemFont(ofSize: Values.mediumFontSize)
        explanationLabel.text = "vc_view_my_qr_code_explanation".localized()
        explanationLabel.themeTextColor = .textPrimary
        explanationLabel.textAlignment = .center
        explanationLabel.lineBreakMode = .byWordWrapping
        explanationLabel.numberOfLines = 0
        
        // Set up share button
        let shareButton = SessionButton(style: .bordered, size: .large)
        shareButton.setTitle("share".localized(), for: .normal)
        shareButton.addTarget(self, action: #selector(shareQRCode), for: .touchUpInside)
        
        // Set up share button container
        let shareButtonContainer = UIView()
        shareButtonContainer.addSubview(shareButton)
        shareButton.pin(.top, to: .top, of: shareButtonContainer)
        shareButton.pin(.bottom, to: .bottom, of: shareButtonContainer)
        if UIDevice.current.isIPad {
            shareButton.center(in: shareButtonContainer)
            shareButton.set(.width, to: Values.iPadButtonWidth)
        } else {
            shareButton.pin(.leading, to: .leading, of: shareButtonContainer, withInset: 80)
            shareButton.pin(.trailing, to: .trailing, of: shareButtonContainer, withInset: -80)
        }
        
        // Set up stack view
        let spacing = (isIPhone5OrSmaller ? Values.mediumSpacing : Values.largeSpacing)
        let stackView = UIStackView(
            arrangedSubviews: [
                titleLabel,
                UIView.spacer(withHeight: spacing),
                qrCodeImageViewContainer,
                UIView.spacer(withHeight: spacing),
                explanationLabel,
                UIView.vStretchingSpacer(),
                shareButtonContainer
            ]
        )
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.layoutMargins = UIEdgeInsets(
            top: Values.largeSpacing,
            left: Values.largeSpacing,
            bottom: Values.smallSpacing,
            right: Values.largeSpacing
        )
        stackView.isLayoutMarginsRelativeArrangement = true
        view.addSubview(stackView)
        stackView.pin(to: view)
    }
    
    // MARK: - Interaction
    
    @objc private func shareQRCode() {
        let qrCode = QRCode.generate(for: getUserHexEncodedPublicKey(), hasBackground: true)
        let shareVC = UIActivityViewController(activityItems: [ qrCode ], applicationActivities: nil)
        if UIDevice.current.isIPad {
            shareVC.excludedActivityTypes = []
            shareVC.popoverPresentationController?.permittedArrowDirections = []
            shareVC.popoverPresentationController?.sourceView = self.view
            shareVC.popoverPresentationController?.sourceRect = self.view.bounds
        }
        qrCodeVC.navigationController!.present(shareVC, animated: true, completion: nil)
    }
}

private final class ScanQRCodePlaceholderVC : UIViewController {
    weak var qrCodeVC: QRCodeVC!
    
    override func viewDidLoad() {
        // Remove background color
        view.themeBackgroundColor = .clear
        
        // Set up explanation label
        let explanationLabel = UILabel()
        explanationLabel.font = .systemFont(ofSize: Values.smallFontSize)
        explanationLabel.text = "vc_scan_qr_code_camera_access_explanation".localized()
        explanationLabel.themeTextColor = .textPrimary
        explanationLabel.textAlignment = .center
        explanationLabel.lineBreakMode = .byWordWrapping
        explanationLabel.numberOfLines = 0
        
        // Set up call to action button
        let callToActionButton = UIButton()
        callToActionButton.titleLabel?.font = .boldSystemFont(ofSize: Values.mediumFontSize)
        callToActionButton.setTitle("continue_2".localized(), for: .normal)
        callToActionButton.setThemeTitleColor(.primary, for: .normal)
        callToActionButton.addTarget(self, action: #selector(requestCameraAccess), for: UIControl.Event.touchUpInside)
        
        // Set up stack view
        let stackView = UIStackView(arrangedSubviews: [ explanationLabel, callToActionButton ])
        stackView.axis = .vertical
        stackView.spacing = Values.mediumSpacing
        stackView.alignment = .center
        
        // Set up constraints
        view.addSubview(stackView)
        stackView.pin(.leading, to: .leading, of: view, withInset: Values.massiveSpacing)
        stackView.pin(.trailing, to: .trailing, of: view, withInset: -Values.massiveSpacing)
        stackView.center(.vertical, in: view, withInset: -16) // Makes things appear centered visually
    }
    
    @objc private func requestCameraAccess() {
        Permissions.requestCameraPermissionIfNeeded { [weak self] in
            self?.qrCodeVC.handleCameraAccessGranted()
        }
    }
}

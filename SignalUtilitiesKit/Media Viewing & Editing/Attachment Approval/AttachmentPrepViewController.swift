// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import UIKit
import AVKit
import AVFoundation
import SessionUIKit
import SignalCoreKit
import SessionMessagingKit
import SessionUtilitiesKit

protocol AttachmentPrepViewControllerDelegate: AnyObject {
    func prepViewControllerUpdateNavigationBar()

    func prepViewControllerUpdateControls()
}

// MARK: -

public class AttachmentPrepViewController: OWSViewController {
    // We sometimes shrink the attachment view so that it remains somewhat visible
    // when the keyboard is presented.
    public enum AttachmentViewScale {
        case fullsize, compact
    }

    // MARK: - Properties

    weak var prepDelegate: AttachmentPrepViewControllerDelegate?

    let attachmentItem: SignalAttachmentItem
    var attachment: SignalAttachment {
        return attachmentItem.attachment
    }
    
    // MARK: - UI
    
    fileprivate static let verticalCenterOffset: CGFloat = (
        AttachmentTextToolbar.kMinTextViewHeight + (AttachmentTextToolbar.kToolbarMargin * 2)
    )
    
    public lazy var scrollView: UIScrollView = {
        // Scroll View - used to zoom/pan on images and video
        let scrollView: UIScrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        // Panning should stop pretty soon after the user stops scrolling
        scrollView.decelerationRate = UIScrollView.DecelerationRate.fast
        
        return scrollView
    }()
    
    private lazy var contentContainerView: UIView = {
        // Anything that should be shrunk when user pops keyboard lives in the contentContainer.
        let view: UIView = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()
    
    private lazy var mediaMessageView: MediaMessageView = {
        let view: MediaMessageView = MediaMessageView(attachment: attachment, mode: .attachmentApproval)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = (imageEditorView != nil)
        
        return view
    }()
    
    private lazy var imageEditorView: ImageEditorView? = {
        guard let imageEditorModel = attachmentItem.imageEditorModel else { return nil }
        
        let view: ImageEditorView = ImageEditorView(model: imageEditorModel, delegate: self)
        view.translatesAutoresizingMaskIntoConstraints = false
        
        guard view.configureSubviews() else { return nil }
        
        return view
    }()
    
    private lazy var playButton: UIButton = {
        let button: UIButton = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentMode = .scaleAspectFit
        button.setBackgroundImage(#imageLiteral(resourceName: "CirclePlay"), for: .normal)
        button.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        
        return button
    }()

    public var shouldHideControls: Bool {
        guard let imageEditorView = imageEditorView else { return false }
        
        return imageEditorView.shouldHideControls
    }

    // MARK: - Initializers

    init(attachmentItem: SignalAttachmentItem) {
        self.attachmentItem = attachmentItem
        
        super.init(nibName: nil, bundle: nil)
        
        if attachment.hasError {
            owsFailDebug(attachment.error.debugDescription)
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.backButtonTitle = ""
        view.themeBackgroundColor = .newConversation_background

        view.addSubview(contentContainerView)
        
        contentContainerView.addSubview(scrollView)
        scrollView.addSubview(mediaMessageView)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        mediaMessageView.addGestureRecognizer(tapGesture)
        
        if attachment.isImage, let editorView: ImageEditorView = imageEditorView {
            view.addSubview(editorView)
            
            imageEditorUpdateNavigationBar()
        }

        if attachment.isVideo || attachment.isAudio {
            contentContainerView.addSubview(playButton)
        }
        
        setupLayout()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        prepDelegate?.prepViewControllerUpdateNavigationBar()
        prepDelegate?.prepViewControllerUpdateControls()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        prepDelegate?.prepViewControllerUpdateNavigationBar()
        prepDelegate?.prepViewControllerUpdateControls()
    }
    
    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        setupZoomScale()
        ensureAttachmentViewScale(animated: false)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Note: Need to do this here to ensure it's based on the final sizing
        // otherwise the offsets will be slightly off
        resetContentInset()
    }
    
    // MARK: - Layout
    
    private func setupLayout() {
        NSLayoutConstraint.activate([
            contentContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainerView.leftAnchor.constraint(equalTo: view.leftAnchor),
            contentContainerView.rightAnchor.constraint(equalTo: view.rightAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            scrollView.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
            scrollView.leftAnchor.constraint(equalTo: contentContainerView.leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: contentContainerView.rightAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor),
            
            mediaMessageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            mediaMessageView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
            mediaMessageView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
            mediaMessageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            mediaMessageView.widthAnchor.constraint(equalTo: view.widthAnchor),
            mediaMessageView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
        
        if attachment.isImage, let editorView: ImageEditorView = imageEditorView {
            let size: CGSize = (attachment.image()?.size ?? CGSize.zero)
            let isPortrait: Bool = (size.height > size.width)
            
            NSLayoutConstraint.activate([
                editorView.topAnchor.constraint(equalTo: view.topAnchor),
                editorView.leftAnchor.constraint(equalTo: view.leftAnchor),
                editorView.rightAnchor.constraint(equalTo: view.rightAnchor),
                editorView.bottomAnchor.constraint(
                    equalTo: view.bottomAnchor,
                    // Don't offset portrait images as they look fine vertically aligned, horizontal
                    // ones need to be pushed up a bit though
                    constant: (isPortrait ? 0 : -AttachmentPrepViewController.verticalCenterOffset)
                )
            ])
        }
         
        if attachment.isVideo || attachment.isAudio {
            let playButtonSize: CGFloat = ScaleFromIPhone5(70)
            
            NSLayoutConstraint.activate([
                playButton.centerXAnchor.constraint(equalTo: contentContainerView.centerXAnchor),
                playButton.centerYAnchor.constraint(
                    equalTo: contentContainerView.centerYAnchor,
                    constant: -AttachmentPrepViewController.verticalCenterOffset
                ),
                playButton.widthAnchor.constraint(equalToConstant: playButtonSize),
                playButton.heightAnchor.constraint(equalToConstant: playButtonSize),
            ])
        }
    }

    // MARK: - Navigation Bar

    public func navigationBarItems() -> [UIView] {
        guard let imageEditorView = imageEditorView else {
            return []
        }
        
        return imageEditorView.navigationBarItems()
    }

    // MARK: - Event Handlers
    
    @objc func screenTapped() {
        self.view.window?.endEditing(true)
    }

    @objc public func playButtonTapped() {
        guard let fileUrl: URL = attachment.dataUrl else { return SNLog("Missing video file") }
        
        let player: AVPlayer = AVPlayer(url: fileUrl)
        let viewController: AVPlayerViewController = AVPlayerViewController()
        viewController.player = player
        
        self.navigationController?.present(viewController, animated: true) { [weak player] in
            player?.play()
        }
    }

    // MARK: - Helpers

    var isZoomable: Bool {
        return attachment.isImage || attachment.isVideo
    }

    func zoomOut(animated: Bool) {
        if self.scrollView.zoomScale != self.scrollView.minimumZoomScale {
            self.scrollView.setZoomScale(self.scrollView.minimumZoomScale, animated: animated)
        }
    }

    // When the keyboard is popped, it can obscure the attachment view.
    // so we sometimes allow resizing the attachment.
    var shouldAllowAttachmentViewResizing: Bool = true

    var attachmentViewScale: AttachmentViewScale = .fullsize
    
    public func setAttachmentViewScale(_ attachmentViewScale: AttachmentViewScale, animated: Bool) {
        self.attachmentViewScale = attachmentViewScale
        ensureAttachmentViewScale(animated: animated)
    }

    func ensureAttachmentViewScale(animated: Bool) {
        let animationDuration = animated ? 0.2 : 0
        guard shouldAllowAttachmentViewResizing else {
            if self.contentContainerView.transform != CGAffineTransform.identity {
                UIView.animate(withDuration: animationDuration) {
                    self.contentContainerView.transform = CGAffineTransform.identity
                }
            }
            return
        }

        switch attachmentViewScale {
        case .fullsize:
            guard self.contentContainerView.transform != .identity else {
                return
            }
            UIView.animate(withDuration: animationDuration) {
                self.contentContainerView.transform = CGAffineTransform.identity
            }
        case .compact:
            guard self.contentContainerView.transform == .identity else {
                return
            }
            UIView.animate(withDuration: animationDuration) {
                let kScaleFactor: CGFloat = 0.7
                let scale = CGAffineTransform(scaleX: kScaleFactor, y: kScaleFactor)

                let originalHeight = self.scrollView.bounds.size.height

                // Position the new scaled item to be centered with respect
                // to it's new size.
                let heightDelta = originalHeight * (1 - kScaleFactor)
                let translate = CGAffineTransform(translationX: 0, y: -heightDelta / 2)

                self.contentContainerView.transform = scale.concatenating(translate)
            }
        }
    }
}

// MARK: -

extension AttachmentPrepViewController: UIScrollViewDelegate {

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if isZoomable {
            return mediaMessageView
        }
        
        // Don't zoom for audio or generic attachments.
        return nil
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        resetContentInset()
    }

    fileprivate func setupZoomScale() {
        // We only want to setup the zoom scale once (otherwise we get glitchy behaviour
        // when anything forces a re-layout)
        guard abs(scrollView.maximumZoomScale - 1.0) <= CGFloat.leastNormalMagnitude else {
            return
        }
        
        // Ensure bounds have been computed
        guard mediaMessageView.bounds.width > 0, mediaMessageView.bounds.height > 0 else {
            Logger.warn("bad bounds")
            return
        }

        let widthScale: CGFloat = (view.bounds.size.width / mediaMessageView.bounds.width)
        let heightScale: CGFloat = (view.bounds.size.height / mediaMessageView.bounds.height)
        let minScale: CGFloat = min(widthScale, heightScale)

        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = (minScale * 5)
        scrollView.zoomScale = minScale
    }
    
    // Allow the user to zoom out to 100% of the attachment size if it's smaller
    // than the screen
    fileprivate func resetContentInset() {
        // If the content isn't zoomable then inset the content so it appears centered
        guard isZoomable else {
            scrollView.contentInset = UIEdgeInsets(
                top: -AttachmentPrepViewController.verticalCenterOffset,
                leading: 0,
                bottom: 0,
                trailing: 0
            )
            return
        }
        
        let offsetX: CGFloat = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY: CGFloat = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        
        scrollView.contentInset = UIEdgeInsets(
            top: offsetY - AttachmentPrepViewController.verticalCenterOffset,
            left: offsetX,
            bottom: 0,
            right: 0
        )
    }
}

// MARK: -

extension AttachmentPrepViewController: ImageEditorViewDelegate {
    public func imageEditor(presentFullScreenView viewController: UIViewController, isTransparent: Bool) {
        let navigationController = StyledNavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = (isTransparent ?
            .overFullScreen :
            .fullScreen
        )
        
        self.present(navigationController, animated: false, completion: nil)
    }

    public func imageEditorUpdateNavigationBar() {
        prepDelegate?.prepViewControllerUpdateNavigationBar()
    }

    public func imageEditorUpdateControls() {
        prepDelegate?.prepViewControllerUpdateControls()
    }
}

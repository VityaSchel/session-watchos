// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import UIKit
import SessionMessagingKit
import SessionUIKit

final class MediaPlaceholderView: UIView {
    private static let iconSize: CGFloat = 24
    private static let iconImageViewSize: CGFloat = 40
    
    // MARK: - Lifecycle
    
    init(cellViewModel: MessageViewModel, textColor: ThemeValue) {
        super.init(frame: CGRect.zero)
        self.accessibilityIdentifier = "Untrusted attachment message"
        self.isAccessibilityElement = true
        setUpViewHierarchy(cellViewModel: cellViewModel, textColor: textColor)
    }
    
    override init(frame: CGRect) {
        preconditionFailure("Use init(viewItem:textColor:) instead.")
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure("Use init(viewItem:textColor:) instead.")
    }
    
    private func setUpViewHierarchy(
        cellViewModel: MessageViewModel,
        textColor: ThemeValue
    ) {
        let (iconName, attachmentDescription): (String, String) = {
            guard
                cellViewModel.variant == .standardIncoming,
                let attachment: Attachment = cellViewModel.attachments?.first
            else {
                return ("actionsheet_document_black", "file") // Should never occur
            }
            
            if attachment.isAudio { return ("attachment_audio", "audio") }
            if attachment.isImage || attachment.isVideo { return ("actionsheet_camera_roll_black", "media") }
            
            return ("actionsheet_document_black", "file")
        }()
        
        // Image view
        let imageView = UIImageView(
            image: UIImage(named: iconName)?
                .resizedImage(
                    to: CGSize(
                        width: MediaPlaceholderView.iconSize,
                        height: MediaPlaceholderView.iconSize
                    )
                )?
                .withRenderingMode(.alwaysTemplate)
        )
        imageView.themeTintColor = textColor
        imageView.contentMode = .center
        imageView.set(.width, to: MediaPlaceholderView.iconImageViewSize)
        imageView.set(.height, to: MediaPlaceholderView.iconImageViewSize)
        
        // Body label
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: Values.mediumFontSize)
        titleLabel.text = "Tap to download \(attachmentDescription)"
        titleLabel.themeTextColor = textColor
        titleLabel.lineBreakMode = .byTruncatingTail
        
        // Stack view
        let stackView = UIStackView(arrangedSubviews: [ imageView, titleLabel ])
        stackView.axis = .horizontal
        stackView.alignment = .center
        addSubview(stackView)
        stackView.pin(.top, to: .top, of: self, withInset: Values.smallSpacing)
        stackView.pin(.leading, to: .leading, of: self, withInset: Values.smallSpacing)
        stackView.pin(.trailing, to: .trailing, of: self, withInset: -Values.largeSpacing)
        stackView.pin(.bottom, to: .bottom, of: self, withInset: -Values.smallSpacing)
    }
}

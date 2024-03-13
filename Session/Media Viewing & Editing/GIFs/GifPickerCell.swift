// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import Combine
import YYImage
import SignalUtilitiesKit
import SignalCoreKit
import SessionUtilitiesKit

class GifPickerCell: UICollectionViewCell {

    // MARK: Properties

    var imageInfo: GiphyImageInfo? {
        didSet {
            AssertIsOnMainThread()

            ensureCellState()
        }
    }

    // Loading and playing GIFs is quite expensive (network, memory, cpu).
    // Here's a bit of logic to not preload offscreen cells that are prefetched.
    var isCellVisible = false {
        didSet {
            AssertIsOnMainThread()

            ensureCellState()
        }
    }

    // We do "progressive" loading by loading stills (jpg or gif) and "animated" gifs.
    // This is critical on cellular connections.
    var stillAssetRequest: ProxiedContentAssetRequest?
    var stillAsset: ProxiedContentAsset?
    var animatedAssetRequest: ProxiedContentAssetRequest?
    var animatedAsset: ProxiedContentAsset?
    var imageView: YYAnimatedImageView?
    var activityIndicator: UIActivityIndicatorView?

    var isCellSelected: Bool = false {
        didSet {
            AssertIsOnMainThread()
            ensureCellState()
        }
    }

    // As another bandwidth saving measure, we only fetch the full sized GIF when the user selects it.
    private var renditionForSending: GiphyRendition?

    // MARK: Initializers

    deinit {
        stillAssetRequest?.cancel()
        animatedAssetRequest?.cancel()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        imageInfo = nil
        isCellVisible = false
        stillAsset = nil
        stillAssetRequest?.cancel()
        stillAssetRequest = nil
        animatedAsset = nil
        animatedAssetRequest?.cancel()
        animatedAssetRequest = nil
        imageView?.removeFromSuperview()
        imageView = nil
        activityIndicator = nil
        isCellSelected = false
    }

    private func clearStillAssetRequest() {
        stillAssetRequest?.cancel()
        stillAssetRequest = nil
    }

    private func clearAnimatedAssetRequest() {
        animatedAssetRequest?.cancel()
        animatedAssetRequest = nil
    }

    private func clearAssetRequests() {
        clearStillAssetRequest()
        clearAnimatedAssetRequest()
    }

    public func ensureCellState() {
        ensureLoadState()
        ensureViewState()
    }

    public func ensureLoadState() {
        guard isCellVisible else {
            // Don't load if cell is not visible.
            clearAssetRequests()
            return
        }
        guard let imageInfo = imageInfo else {
            // Don't load if cell is not configured.
            clearAssetRequests()
            return
        }
        guard self.animatedAsset == nil else {
            // Don't load if cell is already loaded.
            clearAssetRequests()
            return
        }

        // Record high quality animated rendition, but to save bandwidth, don't start downloading
        // until it's selected.
        guard let highQualityAnimatedRendition = imageInfo.pickSendingRendition() else {
            Logger.warn("could not pick gif rendition: \(imageInfo.giphyId)")
            clearAssetRequests()
            return
        }
        self.renditionForSending = highQualityAnimatedRendition

        // The Giphy API returns a slew of "renditions" for a given image.
        // It's critical that we carefully "pick" the best rendition to use.
        guard let animatedRendition = imageInfo.pickPreviewRendition() else {
            Logger.warn("could not pick gif rendition: \(imageInfo.giphyId)")
            clearAssetRequests()
            return
        }
        guard let stillRendition = imageInfo.pickStillRendition() else {
            Logger.warn("could not pick still rendition: \(imageInfo.giphyId)")
            clearAssetRequests()
            return
        }

        // Start still asset request if necessary.
        if stillAsset != nil || animatedAsset != nil {
            clearStillAssetRequest()
        } else if stillAssetRequest == nil {
            stillAssetRequest = GiphyDownloader.giphyDownloader.requestAsset(assetDescription: stillRendition,
                                                                             priority: .high,
                                                                             success: { [weak self] assetRequest, asset in
                                                                                guard let strongSelf = self else { return }
                                                                                if assetRequest != nil && assetRequest != strongSelf.stillAssetRequest {
                                                                                    owsFailDebug("Obsolete request callback.")
                                                                                    return
                                                                                }
                                                                                strongSelf.clearStillAssetRequest()
                                                                                strongSelf.stillAsset = asset
                                                                                strongSelf.ensureViewState()
                },
                                                                             failure: { [weak self] assetRequest in
                                                                                guard let strongSelf = self else { return }
                                                                                if assetRequest != strongSelf.stillAssetRequest {
                                                                                    owsFailDebug("Obsolete request callback.")
                                                                                    return
                                                                                }
                                                                                strongSelf.clearStillAssetRequest()
            })
        }

        // Start animated asset request if necessary.
        if animatedAsset != nil {
            clearAnimatedAssetRequest()
        } else if animatedAssetRequest == nil {
            animatedAssetRequest = GiphyDownloader.giphyDownloader.requestAsset(assetDescription: animatedRendition,
                                                                                priority: .low,
                                                                                success: { [weak self] assetRequest, asset in
                                                                                    guard let strongSelf = self else { return }
                                                                                    if assetRequest != nil && assetRequest != strongSelf.animatedAssetRequest {
                                                                                        owsFailDebug("Obsolete request callback.")
                                                                                        return
                                                                                    }
                                                                                    // If we have the animated asset, we don't need the still asset.
                                                                                    strongSelf.clearAssetRequests()
                                                                                    strongSelf.animatedAsset = asset
                                                                                    strongSelf.ensureViewState()
                },
                                                                                failure: { [weak self] assetRequest in
                                                                                    guard let strongSelf = self else { return }
                                                                                    if assetRequest != strongSelf.animatedAssetRequest {
                                                                                        owsFailDebug("Obsolete request callback.")
                                                                                        return
                                                                                    }
                                                                                    strongSelf.clearAnimatedAssetRequest()
            })
        }
    }

    private func ensureViewState() {
        guard isCellVisible else {
            // Clear image view so we don't animate offscreen GIFs.
            clearViewState()
            return
        }
        guard let asset = pickBestAsset() else {
            clearViewState()
            return
        }
        guard NSData.ows_isValidImage(atPath: asset.filePath, mimeType: OWSMimeTypeImageGif) else {
            owsFailDebug("invalid asset.")
            clearViewState()
            return
        }
        guard let image = YYImage(contentsOfFile: asset.filePath) else {
            owsFailDebug("could not load asset.")
            clearViewState()
            return
        }
        if imageView == nil {
            let imageView = YYAnimatedImageView()
            self.imageView = imageView
            self.contentView.addSubview(imageView)
            imageView.ows_autoPinToSuperviewEdges()
        }
        guard let imageView = imageView else {
            owsFailDebug("missing imageview.")
            clearViewState()
            return
        }
        imageView.image = image
        imageView.accessibilityIdentifier = "gif cell"
        self.themeBackgroundColor = nil

        if self.isCellSelected {
            let activityIndicator = UIActivityIndicatorView(style: .medium)
            self.activityIndicator = activityIndicator
            addSubview(activityIndicator)
            activityIndicator.autoCenterInSuperview()
            activityIndicator.startAnimating()

            // Render activityIndicator on a white tile to ensure it's visible on
            // when overlayed on a variety of potential gifs.
            activityIndicator.themeBackgroundColor = .white
            activityIndicator.alpha = 0.3
            activityIndicator.autoSetDimension(.width, toSize: 30)
            activityIndicator.autoSetDimension(.height, toSize: 30)
            activityIndicator.themeShadowColor = .black
            activityIndicator.layer.cornerRadius = 3
            activityIndicator.layer.shadowOffset = CGSize(width: 1, height: 1)
            activityIndicator.layer.shadowOpacity = 0.7
            activityIndicator.layer.shadowRadius = 1.0
        } else {
            self.activityIndicator?.stopAnimating()
            self.activityIndicator = nil
        }
    }

    public func requestRenditionForSending() -> AnyPublisher<ProxiedContentAsset, Error> {
        guard let renditionForSending = self.renditionForSending else {
            owsFailDebug("renditionForSending was unexpectedly nil")
            return Fail(error: GiphyError.assertionError(description: "renditionForSending was unexpectedly nil"))
                .eraseToAnyPublisher()
        }

        // We don't retain a handle on the asset request, since there will only ever
        // be one selected asset, and we never want to cancel it.
        return GiphyDownloader.giphyDownloader
            .requestAsset(
                assetDescription: renditionForSending,
                priority: .high
            )
            .mapError { _ -> Error in
                // TODO: GiphyDownloader API should pass through a useful failing error so we can pass it through here
                Logger.error("request failed")
                return GiphyError.fetchFailure
            }
            .map { asset, _ in asset }
            .eraseToAnyPublisher()
    }

    private func clearViewState() {
        imageView?.image = nil
        self.themeBackgroundColor = .backgroundSecondary
    }

    private func pickBestAsset() -> ProxiedContentAsset? {
        return animatedAsset ?? stillAsset
    }
}

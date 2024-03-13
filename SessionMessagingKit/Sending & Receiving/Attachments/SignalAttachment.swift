//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

import Foundation
import Combine
import MobileCoreServices
import AVFoundation
import SessionUtilitiesKit

public enum SignalAttachmentError: Error {
    case missingData
    case fileSizeTooLarge
    case invalidData
    case couldNotParseImage
    case couldNotConvertToJpeg
    case couldNotConvertToMpeg4
    case couldNotRemoveMetadata
    case invalidFileFormat
    case couldNotResizeImage
}

extension String {
    public var filenameWithoutExtension: String {
        return (self as NSString).deletingPathExtension
    }

    public var fileExtension: String? {
        return (self as NSString).pathExtension
    }

    public func appendingFileExtension(_ fileExtension: String) -> String {
        guard let result = (self as NSString).appendingPathExtension(fileExtension) else {
            return self
        }
        return result
    }
}

extension SignalAttachmentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingData:
            return NSLocalizedString("ATTACHMENT_ERROR_MISSING_DATA", comment: "Attachment error message for attachments without any data")
        case .fileSizeTooLarge:
            return NSLocalizedString("ATTACHMENT_ERROR_FILE_SIZE_TOO_LARGE", comment: "Attachment error message for attachments whose data exceed file size limits")
        case .invalidData:
            return NSLocalizedString("ATTACHMENT_ERROR_INVALID_DATA", comment: "Attachment error message for attachments with invalid data")
        case .couldNotParseImage:
            return NSLocalizedString("ATTACHMENT_ERROR_COULD_NOT_PARSE_IMAGE", comment: "Attachment error message for image attachments which cannot be parsed")
        case .couldNotConvertToJpeg:
            return NSLocalizedString("ATTACHMENT_ERROR_COULD_NOT_CONVERT_TO_JPEG", comment: "Attachment error message for image attachments which could not be converted to JPEG")
        case .invalidFileFormat:
            return NSLocalizedString("ATTACHMENT_ERROR_INVALID_FILE_FORMAT", comment: "Attachment error message for attachments with an invalid file format")
        case .couldNotConvertToMpeg4:
            return NSLocalizedString("ATTACHMENT_ERROR_COULD_NOT_CONVERT_TO_MP4", comment: "Attachment error message for video attachments which could not be converted to MP4")
        case .couldNotRemoveMetadata:
            return NSLocalizedString("ATTACHMENT_ERROR_COULD_NOT_REMOVE_METADATA", comment: "Attachment error message for image attachments in which metadata could not be removed")
        case .couldNotResizeImage:
            return NSLocalizedString("ATTACHMENT_ERROR_COULD_NOT_RESIZE_IMAGE", comment: "Attachment error message for image attachments which could not be resized")
        }
    }
}

@objc
public enum TSImageQualityTier: UInt {
    case original
    case high
    case mediumHigh
    case medium
    case mediumLow
    case low
}

@objc
public enum TSImageQuality: UInt {
    case original
    case medium
    case compact

    func imageQualityTier() -> TSImageQualityTier {
        switch self {
        case .original:
            return .original
        case .medium:
            return .mediumHigh
        case .compact:
            return .medium
        }
    }
}

// Represents a possible attachment to upload.
// The attachment may be invalid.
//
// Signal attachments are subject to validation and 
// in some cases, file format conversion.
//
// This class gathers that logic.  It offers factory methods
// for attachments that do the necessary work. 
//
// The return value for the factory methods will be nil if the input is nil.
//
// [SignalAttachment hasError] will be true for non-valid attachments.
//
// TODO: Perhaps do conversion off the main thread?
public class SignalAttachment: Equatable, Hashable {

    // MARK: Properties

    public let dataSource: DataSource
    public var captionText: String?
    public var linkPreviewDraft: LinkPreviewDraft?
    
    public var data: Data { return dataSource.data() }
    public var dataLength: UInt { return dataSource.dataLength() }
    public var dataUrl: URL? { return dataSource.dataUrl() }
    public var sourceFilename: String? { return dataSource.sourceFilename?.filterFilename() }
    public var isValidImage: Bool { return dataSource.isValidImage() }
    public var isValidVideo: Bool { return dataSource.isValidVideo() }

    // This flag should be set for text attachments that can be sent as text messages.
    public var isConvertibleToTextMessage = false

    // This flag should be set for attachments that can be sent as contact shares.
    public var isConvertibleToContactShare = false

    // Attachment types are identified using UTIs.
    //
    // See: https://developer.apple.com/library/content/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html
    public let dataUTI: String

    public var error: SignalAttachmentError? {
        didSet {
            assert(oldValue == nil)
        }
    }

    // To avoid redundant work of repeatedly compressing/uncompressing
    // images, we cache the UIImage associated with this attachment if
    // possible.
    private var cachedImage: UIImage?
    private var cachedVideoPreview: UIImage?

    private(set) public var isVoiceMessage = false

    // MARK: Constants

    static let kMaxFileSizeAnimatedImage = OWSMediaUtils.kMaxFileSizeAnimatedImage
    static let kMaxFileSizeImage = OWSMediaUtils.kMaxFileSizeImage
    static let kMaxFileSizeVideo = OWSMediaUtils.kMaxFileSizeVideo
    static let kMaxFileSizeAudio = OWSMediaUtils.kMaxFileSizeAudio
    static let kMaxFileSizeGeneric = OWSMediaUtils.kMaxFileSizeGeneric

    // MARK: 

    public static let maxAttachmentsAllowed: Int = 32

    // MARK: Constructor

    // This method should not be called directly; use the factory
    // methods instead.
    private init(dataSource: DataSource, dataUTI: String) {
        self.dataSource = dataSource
        self.dataUTI = dataUTI
    }

    // MARK: Methods

    public var hasError: Bool { return error != nil }

    public var errorName: String? {
        guard let error = error else {
            // This method should only be called if there is an error.
            return nil
        }

        return "\(error)"
    }

    public var localizedErrorDescription: String? {
        guard let error = self.error else {
            // This method should only be called if there is an error.
            return nil
        }
        guard let errorDescription = error.errorDescription else {
            return nil
        }

        return "\(errorDescription)"
    }

    public class var missingDataErrorMessage: String {
        guard let errorDescription = SignalAttachmentError.missingData.errorDescription else {
            return ""
        }
        
        return errorDescription
    }

    public func staticThumbnail() -> UIImage? {
        if isAnimatedImage {
            return image()
        }
        else if isImage {
            return image()
        }
        else if isVideo {
            return videoPreview()
        }
        else if isAudio {
            return nil
        }
        
        return nil
    }

    public func image() -> UIImage? {
        if let cachedImage = cachedImage {
            return cachedImage
        }
        guard let image = UIImage(data: dataSource.data()) else {
            return nil
        }
        
        cachedImage = image
        return image
    }

    public func videoPreview() -> UIImage? {
        if let cachedVideoPreview = cachedVideoPreview {
            return cachedVideoPreview
        }

        guard let mediaUrl = dataUrl else {
            return nil
        }

        do {
            let filePath = mediaUrl.path
            guard FileManager.default.fileExists(atPath: filePath) else {
                return nil
            }

            let asset = AVURLAsset(url: mediaUrl)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let cgImage = try generator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            let image = UIImage(cgImage: cgImage)

            cachedVideoPreview = image
            return image

        } catch {
            return nil
        }
    }
    
    public func text() -> String? {
        guard let text = String(data: dataSource.data(), encoding: .utf8) else {
            return nil
        }
        
        return text
    }
    
    public func duration() -> TimeInterval? {
        switch (isAudio, isVideo) {
            case (true, _):
                let audioPlayer: AVAudioPlayer? = try? AVAudioPlayer(data: dataSource.data())
                
                return (audioPlayer?.duration).map { $0 > 0 ? $0 : nil }
                
            case (_, true):
                return dataUrl.map { url in
                    let asset: AVURLAsset = AVURLAsset(url: url, options: nil)
                    
                    // According to the CMTime docs "value/timescale = seconds"
                    return (TimeInterval(asset.duration.value) / TimeInterval(asset.duration.timescale))
                }
                
            default: return nil
        }
    }

    // Returns the MIME type for this attachment or nil if no MIME type
    // can be identified.
    public var mimeType: String {
        if isVoiceMessage {
            // Legacy iOS clients don't handle "audio/mp4" files correctly;
            // they are written to disk as .mp4 instead of .m4a which breaks
            // playback.  So we send voice messages as "audio/aac" to work
            // around this.
            //
            // TODO: Remove this Nov. 2016 or after.
            return "audio/aac"
        }

        if let filename = sourceFilename {
            let fileExtension = (filename as NSString).pathExtension
            if fileExtension.count > 0 {
                if let mimeType = MIMETypeUtil.mimeType(forFileExtension: fileExtension) {
                    // UTI types are an imperfect means of representing file type;
                    // file extensions are also imperfect but far more reliable and
                    // comprehensive so we always prefer to try to deduce MIME type
                    // from the file extension.
                    return mimeType
                }
            }
        }
        if dataUTI == kUnknownTestAttachmentUTI {
            return OWSMimeTypeUnknownForTests
        }
        guard let mimeType = UTTypeCopyPreferredTagWithClass(dataUTI as CFString, kUTTagClassMIMEType) else {
            return OWSMimeTypeApplicationOctetStream
        }
        return mimeType.takeRetainedValue() as String
    }

    // Use the filename if known. If not, e.g. if the attachment was copy/pasted, we'll generate a filename
    // like: "signal-2017-04-24-095918.zip"
    public var filenameOrDefault: String {
        if let filename = sourceFilename {
            return filename.filterFilename()
        } else {
            let kDefaultAttachmentName = "signal"

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYY-MM-dd-HHmmss"
            let dateString = dateFormatter.string(from: Date())

            let withoutExtension = "\(kDefaultAttachmentName)-\(dateString)"
            if let fileExtension = self.fileExtension {
                return "\(withoutExtension).\(fileExtension)"
            }

            return withoutExtension
        }
    }

    // Returns the file extension for this attachment or nil if no file extension
    // can be identified.
    public var fileExtension: String? {
        if let filename = sourceFilename {
            let fileExtension = (filename as NSString).pathExtension
            if fileExtension.count > 0 {
                return fileExtension.filterFilename()
            }
        }
        if dataUTI == kUnknownTestAttachmentUTI {
            return "unknown"
        }
        guard let fileExtension = MIMETypeUtil.fileExtension(forUTIType: dataUTI) else {
            return nil
        }
        return fileExtension
    }

    // Returns the set of UTIs that correspond to valid _input_ image formats
    // for Signal attachments.
    //
    // Image attachments may be converted to another image format before 
    // being uploaded.
    private class var inputImageUTISet: Set<String> {
         // HEIC is valid input, but not valid output. Non-iOS11 clients do not support it.
        let heicSet: Set<String> = Set(["public.heic", "public.heif"])

        return MIMETypeUtil.supportedImageUTITypes()
            .union(animatedImageUTISet)
            .union(heicSet)
    }

    // Returns the set of UTIs that correspond to valid _output_ image formats
    // for Signal attachments.
    private class var outputImageUTISet: Set<String> {
        return MIMETypeUtil.supportedImageUTITypes().union(animatedImageUTISet)
    }

    private class var outputVideoUTISet: Set<String> {
        return Set([kUTTypeMPEG4 as String])
    }

    // Returns the set of UTIs that correspond to valid animated image formats
    // for Signal attachments.
    private class var animatedImageUTISet: Set<String> {
        return MIMETypeUtil.supportedAnimatedImageUTITypes()
    }

    // Returns the set of UTIs that correspond to valid video formats
    // for Signal attachments.
    private class var videoUTISet: Set<String> {
        return MIMETypeUtil.supportedVideoUTITypes()
    }

    // Returns the set of UTIs that correspond to valid audio formats
    // for Signal attachments.
    private class var audioUTISet: Set<String> {
        return MIMETypeUtil.supportedAudioUTITypes()
    }

    // Returns the set of UTIs that correspond to valid image, video and audio formats
    // for Signal attachments.
    private class var mediaUTISet: Set<String> {
        return audioUTISet.union(videoUTISet).union(animatedImageUTISet).union(inputImageUTISet)
    }

    @objc
    public var isImage: Bool {
        return SignalAttachment.outputImageUTISet.contains(dataUTI)
    }

    @objc
    public var isAnimatedImage: Bool {
        return SignalAttachment.animatedImageUTISet.contains(dataUTI)
    }

    @objc
    public var isVideo: Bool {
        return SignalAttachment.videoUTISet.contains(dataUTI)
    }

    @objc
    public var isAudio: Bool {
        return SignalAttachment.audioUTISet.contains(dataUTI)
    }

    @objc
    public var isText: Bool {
        return (
            isConvertibleToTextMessage &&
            UTTypeConformsTo(dataUTI as CFString, kUTTypeText)
        )
    }

    @objc
    public var isUrl: Bool {
        return UTTypeConformsTo(dataUTI as CFString, kUTTypeURL)
    }

    @objc
    public class func pasteboardHasPossibleAttachment() -> Bool {
        return UIPasteboard.general.numberOfItems > 0
    }

    @objc
    public class func pasteboardHasText() -> Bool {
        if UIPasteboard.general.numberOfItems < 1 {
            return false
        }
        let itemSet = IndexSet(integer: 0)
        guard let pasteboardUTITypes = UIPasteboard.general.types(forItemSet: itemSet) else {
            return false
        }
        let pasteboardUTISet = Set<String>(pasteboardUTITypes[0])

        // The pasteboard can be populated with multiple UTI types
        // with different payloads.  iMessage for example will copy
        // an animated GIF to the pasteboard with the following UTI
        // types:
        //
        // * "public.url-name"
        // * "public.utf8-plain-text"
        // * "com.compuserve.gif"
        //
        // We want to paste the animated GIF itself, not it's name.
        //
        // In general, our rule is to prefer non-text pasteboard
        // contents, so we return true IFF there is a text UTI type
        // and there is no non-text UTI type.
        var hasTextUTIType = false
        var hasNonTextUTIType = false
        for utiType in pasteboardUTISet {
            if UTTypeConformsTo(utiType as CFString, kUTTypeText) {
                hasTextUTIType = true
            } else if mediaUTISet.contains(utiType) {
                hasNonTextUTIType = true
            }
        }
        if pasteboardUTISet.contains(kUTTypeURL as String) {
            // Treat URL as a textual UTI type.
            hasTextUTIType = true
        }
        if hasNonTextUTIType {
            return false
        }
        return hasTextUTIType
    }

    // Returns an attachment from the pasteboard, or nil if no attachment
    // can be found.
    //
    // NOTE: The attachment returned by this method may not be valid.
    //       Check the attachment's error property.
    public class func attachmentFromPasteboard() -> SignalAttachment? {
        guard UIPasteboard.general.numberOfItems >= 1 else {
            return nil
        }
        // If pasteboard contains multiple items, use only the first.
        let itemSet = IndexSet(integer: 0)
        guard let pasteboardUTITypes = UIPasteboard.general.types(forItemSet: itemSet) else {
            return nil
        }
        let pasteboardUTISet = Set<String>(pasteboardUTITypes[0])
        for dataUTI in inputImageUTISet {
            if pasteboardUTISet.contains(dataUTI) {
                guard let data = dataForFirstPasteboardItem(dataUTI: dataUTI) else {
                    return nil
                }
                let dataSource = DataSourceValue.dataSource(with: data, utiType: dataUTI)
                // Pasted images _SHOULD _NOT_ be resized, if possible.
                return attachment(dataSource: dataSource, dataUTI: dataUTI, imageQuality: .original)
            }
        }
        for dataUTI in videoUTISet {
            if pasteboardUTISet.contains(dataUTI) {
                guard let data = dataForFirstPasteboardItem(dataUTI: dataUTI) else {
                    return nil
                }
                let dataSource = DataSourceValue.dataSource(with: data, utiType: dataUTI)
                return videoAttachment(dataSource: dataSource, dataUTI: dataUTI)
            }
        }
        for dataUTI in audioUTISet {
            if pasteboardUTISet.contains(dataUTI) {
                guard let data = dataForFirstPasteboardItem(dataUTI: dataUTI) else {
                    return nil
                }
                let dataSource = DataSourceValue.dataSource(with: data, utiType: dataUTI)
                return audioAttachment(dataSource: dataSource, dataUTI: dataUTI)
            }
        }

        let dataUTI = pasteboardUTISet[pasteboardUTISet.startIndex]
        guard let data = dataForFirstPasteboardItem(dataUTI: dataUTI) else {
            return nil
        }
        let dataSource = DataSourceValue.dataSource(with: data, utiType: dataUTI)
        return genericAttachment(dataSource: dataSource, dataUTI: dataUTI)
    }

    // This method should only be called for dataUTIs that
    // are appropriate for the first pasteboard item.
    private class func dataForFirstPasteboardItem(dataUTI: String) -> Data? {
        let itemSet = IndexSet(integer: 0)
        guard let datas = UIPasteboard.general.data(forPasteboardType: dataUTI, inItemSet: itemSet) else {
            return nil
        }
        guard datas.count > 0 else {
            return nil
        }
        return datas[0]
    }

    // MARK: Image Attachments

    // Factory method for an image attachment.
    //
    // NOTE: The attachment returned by this method may not be valid.
    //       Check the attachment's error property.
    private class func imageAttachment(dataSource: DataSource?, dataUTI: String, imageQuality: TSImageQuality) -> SignalAttachment {
        assert(dataUTI.count > 0)
        assert(dataSource != nil)
        guard let dataSource = dataSource else {
            let attachment = SignalAttachment(dataSource: DataSourceValue.emptyDataSource(), dataUTI: dataUTI)
            attachment.error = .missingData
            return attachment
        }

        let attachment = SignalAttachment(dataSource: dataSource, dataUTI: dataUTI)

        guard inputImageUTISet.contains(dataUTI) else {
            attachment.error = .invalidFileFormat
            return attachment
        }

        guard dataSource.dataLength() > 0 else {
            attachment.error = .invalidData
            return attachment
        }

        if animatedImageUTISet.contains(dataUTI) {
            guard dataSource.dataLength() <= kMaxFileSizeAnimatedImage else {
                attachment.error = .fileSizeTooLarge
                return attachment
            }

            // Never re-encode animated images (i.e. GIFs) as JPEGs.
            return attachment
        } else {
            guard let image = UIImage(data: dataSource.data()) else {
                attachment.error = .couldNotParseImage
                return attachment
            }
            attachment.cachedImage = image

            let isValidOutput = isValidOutputImage(image: image, dataSource: dataSource, dataUTI: dataUTI, imageQuality: imageQuality)

            if let sourceFilename = dataSource.sourceFilename,
                let sourceFileExtension = sourceFilename.fileExtension,
                ["heic", "heif"].contains(sourceFileExtension.lowercased()) {

                // If a .heic file actually contains jpeg data, update the extension to match.
                //
                // Here's how that can happen:
                // In iOS11, the Photos.app records photos with HEIC UTIType, with the .HEIC extension.
                // Since HEIC isn't a valid output format for Signal, we'll detect that and convert to JPEG,
                // updating the extension as well. No problem.
                // However the problem comes in when you edit an HEIC image in Photos.app - the image is saved
                // in the Photos.app as a JPEG, but retains the (now incongruous) HEIC extension in the filename.
                assert(dataUTI == kUTTypeJPEG as String || !isValidOutput)

                let baseFilename = sourceFilename.filenameWithoutExtension
                dataSource.sourceFilename = baseFilename.appendingFileExtension("jpg")
            }

            if isValidOutput {
                return removeImageMetadata(attachment: attachment)
            } else {
                return compressImageAsJPEG(image: image, attachment: attachment, filename: dataSource.sourceFilename, imageQuality: imageQuality)
            }
        }
    }

    // If the proposed attachment already conforms to the
    // file size and content size limits, don't recompress it.
    private class func isValidOutputImage(image: UIImage?, dataSource: DataSource?, dataUTI: String, imageQuality: TSImageQuality) -> Bool {
        guard image != nil else {
            return false
        }
        guard let dataSource = dataSource else {
            return false
        }
        guard SignalAttachment.outputImageUTISet.contains(dataUTI) else {
            return false
        }
        if doesImageHaveAcceptableFileSize(dataSource: dataSource, imageQuality: imageQuality) &&
            dataSource.dataLength() <= kMaxFileSizeImage {
            return true
        }
        return false
    }

    // Factory method for an image attachment.
    //
    // NOTE: The attachment returned by this method may nil or not be valid.
    //       Check the attachment's error property.
    public class func imageAttachment(image: UIImage?, dataUTI: String, filename: String?, imageQuality: TSImageQuality) -> SignalAttachment {
        assert(dataUTI.count > 0)

        guard let image = image else {
            let dataSource = DataSourceValue.emptyDataSource()
            dataSource.sourceFilename = filename
            let attachment = SignalAttachment(dataSource: dataSource, dataUTI: dataUTI)
            attachment.error = .missingData
            return attachment
        }

        // Make a placeholder attachment on which to hang errors if necessary.
        let dataSource = DataSourceValue.emptyDataSource()
        dataSource.sourceFilename = filename
        let attachment = SignalAttachment(dataSource: dataSource, dataUTI: dataUTI)
        attachment.cachedImage = image

        return compressImageAsJPEG(image: image, attachment: attachment, filename: filename, imageQuality: imageQuality)
    }

    private class func compressImageAsJPEG(image: UIImage, attachment: SignalAttachment, filename: String?, imageQuality: TSImageQuality) -> SignalAttachment {
        assert(attachment.error == nil)

        if imageQuality == .original &&
            attachment.dataLength < kMaxFileSizeGeneric &&
            outputImageUTISet.contains(attachment.dataUTI) {
            // We should avoid resizing images attached "as documents" if possible.
            return attachment
        }

        var imageUploadQuality = imageQuality.imageQualityTier()

        while true {
            let maxSize = maxSizeForImage(image: image, imageUploadQuality: imageUploadQuality)
            var dstImage: UIImage! = image
            if image.size.width > maxSize ||
                image.size.height > maxSize {
                guard let resizedImage = imageScaled(image, toMaxSize: maxSize) else {
                    attachment.error = .couldNotResizeImage
                    return attachment
                }
                dstImage = resizedImage
            }
            guard let jpgImageData = dstImage.jpegData(compressionQuality: jpegCompressionQuality(imageUploadQuality: imageUploadQuality)) else {
                                                                attachment.error = .couldNotConvertToJpeg
                                                                return attachment
            }

            guard let dataSource = DataSourceValue.dataSource(with: jpgImageData, fileExtension: "jpg") else {
                attachment.error = .couldNotConvertToJpeg
                return attachment
            }

            let baseFilename = filename?.filenameWithoutExtension
            let jpgFilename = baseFilename?.appendingFileExtension("jpg")
            dataSource.sourceFilename = jpgFilename

            if doesImageHaveAcceptableFileSize(dataSource: dataSource, imageQuality: imageQuality) &&
                dataSource.dataLength() <= kMaxFileSizeImage {
                let recompressedAttachment = SignalAttachment(dataSource: dataSource, dataUTI: kUTTypeJPEG as String)
                recompressedAttachment.cachedImage = dstImage
                return recompressedAttachment
            }

            // If the JPEG output is larger than the file size limit,
            // continue to try again by progressively reducing the
            // image upload quality.
            switch imageUploadQuality {
            case .original:
                imageUploadQuality = .high
            case .high:
                imageUploadQuality = .mediumHigh
            case .mediumHigh:
                imageUploadQuality = .medium
            case .medium:
                imageUploadQuality = .mediumLow
            case .mediumLow:
                imageUploadQuality = .low
            case .low:
                attachment.error = .fileSizeTooLarge
                return attachment
            }
        }
    }

    // NOTE: For unknown reasons, resizing images with UIGraphicsBeginImageContext()
    // crashes reliably in the share extension after screen lock's auth UI has been presented.
    // Resizing using a CGContext seems to work fine.
    private class func imageScaled(_ uiImage: UIImage, toMaxSize maxSize: CGFloat) -> UIImage? {
        guard let cgImage = uiImage.cgImage else {
            return nil
        }

        // It's essential that we work consistently in "CG" coordinates (which are
        // pixels and don't reflect orientation), not "UI" coordinates (which
        // are points and do reflect orientation).
        let scrSize = CGSize(width: cgImage.width, height: cgImage.height)
        var maxSizeRect = CGRect.zero
        maxSizeRect.size = CGSize(width: maxSize, height: maxSize)
        let newSize = AVMakeRect(aspectRatio: scrSize, insideRect: maxSizeRect).size

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: CGBitmapInfo = [
            CGBitmapInfo(rawValue: CGImageByteOrderInfo.orderDefault.rawValue),
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
        guard let context = CGContext.init(data: nil,
                                           width: Int(newSize.width),
                                           height: Int(newSize.height),
                                           bitsPerComponent: 8,
                                           bytesPerRow: 0,
                                           space: colorSpace,
                                           bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }
        context.interpolationQuality = .high

        var drawRect = CGRect.zero
        drawRect.size = newSize
        context.draw(cgImage, in: drawRect)

        guard let newCGImage = context.makeImage() else {
            return nil
        }
        return UIImage(cgImage: newCGImage,
                       scale: uiImage.scale,
                       orientation: uiImage.imageOrientation)
    }

    private class func doesImageHaveAcceptableFileSize(dataSource: DataSource, imageQuality: TSImageQuality) -> Bool {
        switch imageQuality {
        case .original:
            return true
        case .medium:
            return dataSource.dataLength() < UInt(1024 * 1024)
        case .compact:
            return dataSource.dataLength() < UInt(400 * 1024)
        }
    }

    private class func maxSizeForImage(image: UIImage, imageUploadQuality: TSImageQualityTier) -> CGFloat {
        switch imageUploadQuality {
        case .original:
            return max(image.size.width, image.size.height)
        case .high:
            return 2048
        case .mediumHigh:
            return 1536
        case .medium:
            return 1024
        case .mediumLow:
            return 768
        case .low:
            return 512
        }
    }

    private class func jpegCompressionQuality(imageUploadQuality: TSImageQualityTier) -> CGFloat {
        switch imageUploadQuality {
        case .original:
            return 1
        case .high:
            return 0.9
        case .mediumHigh:
            return 0.8
        case .medium:
            return 0.7
        case .mediumLow:
            return 0.6
        case .low:
            return 0.5
        }
    }

    private class func removeImageMetadata(attachment: SignalAttachment) -> SignalAttachment {

        guard let source = CGImageSourceCreateWithData(attachment.data as CFData, nil) else {
            let attachment = SignalAttachment(dataSource: DataSourceValue.emptyDataSource(), dataUTI: attachment.dataUTI)
            attachment.error = .missingData
            return attachment
        }

        guard let type = CGImageSourceGetType(source) else {
            let attachment = SignalAttachment(dataSource: DataSourceValue.emptyDataSource(), dataUTI: attachment.dataUTI)
            attachment.error = .invalidFileFormat
            return attachment
        }

        let count = CGImageSourceGetCount(source)
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData as CFMutableData, type, count, nil) else {
            attachment.error = .couldNotRemoveMetadata
            return attachment
        }

        let removeMetadataProperties: [String: AnyObject] =
        [
            kCGImagePropertyExifDictionary as String: kCFNull,
            kCGImagePropertyExifAuxDictionary as String: kCFNull,
            kCGImagePropertyGPSDictionary as String: kCFNull,
            kCGImagePropertyTIFFDictionary as String: kCFNull,
            kCGImagePropertyJFIFDictionary as String: kCFNull,
            kCGImagePropertyPNGDictionary as String: kCFNull,
            kCGImagePropertyIPTCDictionary as String: kCFNull,
            kCGImagePropertyMakerAppleDictionary as String: kCFNull
        ]

        for index in 0...count-1 {
            CGImageDestinationAddImageFromSource(destination, source, index, removeMetadataProperties as CFDictionary)
        }

        if CGImageDestinationFinalize(destination) {
            guard let dataSource = DataSourceValue.dataSource(with: mutableData as Data, utiType: attachment.dataUTI) else {
                attachment.error = .couldNotRemoveMetadata
                return attachment
            }

            let strippedAttachment = SignalAttachment(dataSource: dataSource, dataUTI: attachment.dataUTI)
            return strippedAttachment

        } else {
            attachment.error = .couldNotRemoveMetadata
            return attachment
        }
    }

    // MARK: Video Attachments

    // Factory method for video attachments.
    //
    // NOTE: The attachment returned by this method may not be valid.
    //       Check the attachment's error property.
    private class func videoAttachment(dataSource: DataSource?, dataUTI: String) -> SignalAttachment {
        guard let dataSource = dataSource else {
            let dataSource = DataSourceValue.emptyDataSource()
            let attachment = SignalAttachment(dataSource: dataSource, dataUTI: dataUTI)
            attachment.error = .missingData
            return attachment
        }

        return newAttachment(dataSource: dataSource,
                             dataUTI: dataUTI,
                             validUTISet: videoUTISet,
                             maxFileSize: kMaxFileSizeVideo)
    }

    public class func copyToVideoTempDir(url fromUrl: URL) throws -> URL {
        let baseDir = SignalAttachment.videoTempPath.appendingPathComponent(UUID().uuidString, isDirectory: true)
        OWSFileSystem.ensureDirectoryExists(baseDir.path)
        let toUrl = baseDir.appendingPathComponent(fromUrl.lastPathComponent)

        try FileManager.default.copyItem(at: fromUrl, to: toUrl)

        return toUrl
    }

    private class var videoTempPath: URL {
        let videoDir = URL(fileURLWithPath: Singleton.appContext.temporaryDirectory).appendingPathComponent("video")
        OWSFileSystem.ensureDirectoryExists(videoDir.path)
        return videoDir
    }

    public class func compressVideoAsMp4(dataSource: DataSource, dataUTI: String) -> (AnyPublisher<SignalAttachment, Error>, AVAssetExportSession?) {
        guard let url = dataSource.dataUrl() else {
            let attachment = SignalAttachment(dataSource: DataSourceValue.emptyDataSource(), dataUTI: dataUTI)
            attachment.error = .missingData
            return (
                Just(attachment)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher(),
                nil
            )
        }

        let asset = AVAsset(url: url)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            let attachment = SignalAttachment(dataSource: DataSourceValue.emptyDataSource(), dataUTI: dataUTI)
            attachment.error = .couldNotConvertToMpeg4
            return (
                Just(attachment)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher(),
                nil
            )
        }

        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.outputFileType = AVFileType.mp4
        exportSession.metadataItemFilter = AVMetadataItemFilter.forSharing()

        let exportURL = videoTempPath.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        exportSession.outputURL = exportURL

        let publisher = Deferred {
            Future<SignalAttachment, Error> { resolver in
                exportSession.exportAsynchronously {
                    let baseFilename = dataSource.sourceFilename
                    let mp4Filename = baseFilename?.filenameWithoutExtension.appendingFileExtension("mp4")
                    
                    guard let dataSource = DataSourcePath.dataSource(with: exportURL,
                                                                     shouldDeleteOnDeallocation: true) else {
                        let attachment = SignalAttachment(dataSource: DataSourceValue.emptyDataSource(), dataUTI: dataUTI)
                        attachment.error = .couldNotConvertToMpeg4
                        resolver(Result.success(attachment))
                        return
                    }
                    
                    dataSource.sourceFilename = mp4Filename
                    
                    let attachment = SignalAttachment(dataSource: dataSource, dataUTI: kUTTypeMPEG4 as String)
                    resolver(Result.success(attachment))
                }
            }
        }
        .eraseToAnyPublisher()

        return (publisher, exportSession)
    }

    public struct VideoCompressionResult {
        public let attachmentPublisher: AnyPublisher<SignalAttachment, Error>
        public let exportSession: AVAssetExportSession?

        fileprivate init(attachmentPublisher: AnyPublisher<SignalAttachment, Error>, exportSession: AVAssetExportSession?) {
            self.attachmentPublisher = attachmentPublisher
            self.exportSession = exportSession
        }
    }

    public class func compressVideoAsMp4(dataSource: DataSource, dataUTI: String) -> VideoCompressionResult {
        let (attachmentPublisher, exportSession) = compressVideoAsMp4(dataSource: dataSource, dataUTI: dataUTI)
        return VideoCompressionResult(attachmentPublisher: attachmentPublisher, exportSession: exportSession)
    }

    @objc
    public class func isInvalidVideo(dataSource: DataSource, dataUTI: String) -> Bool {
        guard videoUTISet.contains(dataUTI) else {
            // not a video
            return false
        }

        guard isValidOutputVideo(dataSource: dataSource, dataUTI: dataUTI) else {
            // found a video which needs to be converted
            return true
        }

        // It is a video, but it's not invalid
        return false
    }

    private class func isValidOutputVideo(dataSource: DataSource?, dataUTI: String) -> Bool {
        guard let dataSource = dataSource else {
            return false
        }

        guard SignalAttachment.outputVideoUTISet.contains(dataUTI) else {
            return false
        }

        if dataSource.dataLength() <= kMaxFileSizeVideo {
            return true
        }
        return false
    }

    // MARK: Audio Attachments

    // Factory method for audio attachments.
    //
    // NOTE: The attachment returned by this method may not be valid.
    //       Check the attachment's error property.
    private class func audioAttachment(dataSource: DataSource?, dataUTI: String) -> SignalAttachment {
        return newAttachment(dataSource: dataSource,
                             dataUTI: dataUTI,
                             validUTISet: audioUTISet,
                             maxFileSize: kMaxFileSizeAudio)
    }

    // MARK: Generic Attachments

    // Factory method for generic attachments.
    //
    // NOTE: The attachment returned by this method may not be valid.
    //       Check the attachment's error property.
    private class func genericAttachment(dataSource: DataSource?, dataUTI: String) -> SignalAttachment {
        return newAttachment(dataSource: dataSource,
                             dataUTI: dataUTI,
                             validUTISet: nil,
                             maxFileSize: kMaxFileSizeGeneric)
    }

    // MARK: Voice Messages

    public class func voiceMessageAttachment(dataSource: DataSource?, dataUTI: String) -> SignalAttachment {
        let attachment = audioAttachment(dataSource: dataSource, dataUTI: dataUTI)
        attachment.isVoiceMessage = true
        return attachment
    }

    // MARK: Attachments

    // Factory method for non-image Attachments.
    //
    // NOTE: The attachment returned by this method may not be valid.
    //       Check the attachment's error property.
    public class func attachment(dataSource: DataSource?, dataUTI: String) -> SignalAttachment {
        return attachment(dataSource: dataSource, dataUTI: dataUTI, imageQuality: .original)
    }

    // Factory method for attachments of any kind.
    //
    // NOTE: The attachment returned by this method may not be valid.
    //       Check the attachment's error property.
    public class func attachment(dataSource: DataSource?, dataUTI: String, imageQuality: TSImageQuality) -> SignalAttachment {
        if inputImageUTISet.contains(dataUTI) {
            return imageAttachment(dataSource: dataSource, dataUTI: dataUTI, imageQuality: imageQuality)
        } else if videoUTISet.contains(dataUTI) {
            return videoAttachment(dataSource: dataSource, dataUTI: dataUTI)
        } else if audioUTISet.contains(dataUTI) {
            return audioAttachment(dataSource: dataSource, dataUTI: dataUTI)
        } else {
            return genericAttachment(dataSource: dataSource, dataUTI: dataUTI)
        }
    }

    public class func empty() -> SignalAttachment {
        return SignalAttachment.attachment(dataSource: DataSourceValue.emptyDataSource(),
                                           dataUTI: kUTTypeContent as String,
                                           imageQuality: .original)
    }

    // MARK: Helper Methods

    private class func newAttachment(dataSource: DataSource?,
                                     dataUTI: String,
                                     validUTISet: Set<String>?,
                                     maxFileSize: UInt) -> SignalAttachment {
        assert(dataUTI.count > 0)

        assert(dataSource != nil)
        guard let dataSource = dataSource else {
            let attachment = SignalAttachment(dataSource: DataSourceValue.emptyDataSource(), dataUTI: dataUTI)
            attachment.error = .missingData
            return attachment
        }

        let attachment = SignalAttachment(dataSource: dataSource, dataUTI: dataUTI)

        if let validUTISet = validUTISet {
            guard validUTISet.contains(dataUTI) else {
                attachment.error = .invalidFileFormat
                return attachment
            }
        }

        guard dataSource.dataLength() > 0 else {
            assert(dataSource.dataLength() > 0)
            attachment.error = .invalidData
            return attachment
        }

        guard dataSource.dataLength() <= maxFileSize else {
            attachment.error = .fileSizeTooLarge
            return attachment
        }

        // Attachment is valid
        return attachment
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: SignalAttachment, rhs: SignalAttachment) -> Bool {
        return (
            lhs.dataSource == rhs.dataSource &&
            lhs.dataUTI == rhs.dataUTI &&
            lhs.captionText == rhs.captionText &&
            lhs.linkPreviewDraft == rhs.linkPreviewDraft &&
            lhs.isConvertibleToTextMessage == rhs.isConvertibleToTextMessage &&
            lhs.isConvertibleToContactShare == rhs.isConvertibleToContactShare &&
            lhs.cachedImage == rhs.cachedImage &&
            lhs.cachedVideoPreview == rhs.cachedVideoPreview &&
            lhs.isVoiceMessage == rhs.isVoiceMessage
        )
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        dataSource.hash(into: &hasher)
        dataUTI.hash(into: &hasher)
        captionText.hash(into: &hasher)
        linkPreviewDraft.hash(into: &hasher)
        isConvertibleToTextMessage.hash(into: &hasher)
        isConvertibleToContactShare.hash(into: &hasher)
        cachedImage.hash(into: &hasher)
        cachedVideoPreview.hash(into: &hasher)
        isVoiceMessage.hash(into: &hasher)
    }
}

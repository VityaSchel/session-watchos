// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import AVFAudio
import AVFoundation
import Combine
import GRDB
import SignalCoreKit
import SessionUtilitiesKit
import SessionSnodeKit
import SessionUIKit

public struct Attachment: Codable, Identifiable, Equatable, Hashable, FetchableRecord, PersistableRecord, TableRecord, ColumnExpressible {
    public static var databaseTableName: String { "attachment" }
    internal static let quoteForeignKey = ForeignKey([Columns.id], to: [Quote.Columns.attachmentId])
    internal static let linkPreviewForeignKey = ForeignKey([Columns.id], to: [LinkPreview.Columns.attachmentId])
    public static let interactionAttachments = hasOne(InteractionAttachment.self)
    public static let interaction = hasOne(
        Interaction.self,
        through: interactionAttachments,
        using: InteractionAttachment.interaction
    )
    fileprivate static let quote = belongsTo(Quote.self, using: quoteForeignKey)
    fileprivate static let linkPreview = belongsTo(LinkPreview.self, using: linkPreviewForeignKey)
    
    public typealias Columns = CodingKeys
    public enum CodingKeys: String, CodingKey, ColumnExpression, CaseIterable {
        case id
        case serverId
        case variant
        case state
        case contentType
        case byteCount
        case creationTimestamp
        case sourceFilename
        case downloadUrl
        case localRelativeFilePath
        case width
        case height
        case duration
        case isVisualMedia
        case isValid
        case encryptionKey
        case digest
        case caption
    }
    
    public enum Variant: Int, Codable, DatabaseValueConvertible {
        case standard
        case voiceMessage
    }
    
    public enum State: Int, Codable, DatabaseValueConvertible {
        case failedDownload
        case pendingDownload
        case downloading
        case downloaded
        case failedUpload
        case uploading
        case uploaded
        
        case invalid = 100
    }
    
    /// A unique identifier for the attachment
    public let id: String
    
    /// The id for the attachment returned by the server
    ///
    /// This will be null for attachments which haven’t completed uploading
    ///
    /// **Note:** This value is not unique as multiple SOGS could end up having the same file id
    public let serverId: String?
    
    /// The type of this attachment, used to distinguish logic handling
    public let variant: Variant
    
    /// The current state of the attachment
    public let state: State
    
    /// The MIMEType for the attachment
    public let contentType: String
    
    /// The size of the attachment in bytes
    ///
    /// **Note:** This may be `0` for some legacy attachments
    public let byteCount: UInt
    
    /// Timestamp in seconds since epoch for when this attachment was created
    ///
    /// **Uploaded:** This will be the timestamp the file finished uploading
    /// **Downloaded:** This will be the timestamp the file finished downloading
    /// **Other:** This will be null
    public let creationTimestamp: TimeInterval?
    
    /// Represents the "source" filename sent or received in the protos, not the filename on disk
    public let sourceFilename: String?
    
    /// The url the attachment can be downloaded from, this will be `null` for attachments which haven’t yet been uploaded
    ///
    /// **Note:** The url is a fully constructed url but the clients just extract the id from the end of the url to perform the actual download
    public let downloadUrl: String?
    
    /// The file path for the attachment relative to the attachments folder
    ///
    /// **Note:** We store this path so that file path generation changes don’t break existing attachments
    public let localRelativeFilePath: String?
    
    /// The width of the attachment, this will be `null` for non-visual attachment types
    public let width: UInt?
    
    /// The height of the attachment, this will be `null` for non-visual attachment types
    public let height: UInt?
    
    /// The number of seconds the attachment plays for (this will only be set for video and audio attachment types)
    public let duration: TimeInterval?
    
    /// A flag indicating whether the attachment data is visual media
    public let isVisualMedia: Bool
    
    /// A flag indicating whether the attachment data downloaded is valid for it's content type
    public let isValid: Bool
    
    /// The key used to decrypt the attachment
    public let encryptionKey: Data?
    
    /// The computed digest for the attachment (generated from `iv || encrypted data || hmac`)
    public let digest: Data?
    
    /// Caption for the attachment
    public let caption: String?
    
    // MARK: - Initialization
    
    public init(
        id: String = UUID().uuidString,
        serverId: String? = nil,
        variant: Variant,
        state: State = .pendingDownload,
        contentType: String,
        byteCount: UInt,
        creationTimestamp: TimeInterval? = nil,
        sourceFilename: String? = nil,
        downloadUrl: String? = nil,
        localRelativeFilePath: String? = nil,
        width: UInt? = nil,
        height: UInt? = nil,
        duration: TimeInterval? = nil,
        isVisualMedia: Bool? = nil,
        isValid: Bool = false,
        encryptionKey: Data? = nil,
        digest: Data? = nil,
        caption: String? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.variant = variant
        self.state = state
        self.contentType = contentType
        self.byteCount = byteCount
        self.creationTimestamp = creationTimestamp
        self.sourceFilename = sourceFilename
        self.downloadUrl = downloadUrl
        self.localRelativeFilePath = localRelativeFilePath
        self.width = width
        self.height = height
        self.duration = duration
        self.isVisualMedia = (isVisualMedia ?? (
            MIMETypeUtil.isImage(contentType) ||
            MIMETypeUtil.isVideo(contentType) ||
            MIMETypeUtil.isAnimated(contentType)
        ))
        self.isValid = isValid
        self.encryptionKey = encryptionKey
        self.digest = digest
        self.caption = caption
    }
    
    /// This initializer should only be used when converting from either a LinkPreview or a SignalAttachment to an Attachment (prior to upload)
    public init?(
        id: String = UUID().uuidString,
        variant: Variant = .standard,
        contentType: String,
        dataSource: DataSource,
        sourceFilename: String? = nil,
        caption: String? = nil
    ) {
        guard let originalFilePath: String = Attachment.originalFilePath(id: id, mimeType: contentType, sourceFilename: sourceFilename) else {
            return nil
        }
        guard dataSource.write(toPath: originalFilePath) else { return nil }
        
        let imageSize: CGSize? = Attachment.imageSize(
            contentType: contentType,
            originalFilePath: originalFilePath
        )
        let (isValid, duration): (Bool, TimeInterval?) = Attachment.determineValidityAndDuration(
            contentType: contentType,
            localRelativeFilePath: nil,
            originalFilePath: originalFilePath
        )
        
        self.id = id
        self.serverId = nil
        self.variant = variant
        self.state = .uploading
        self.contentType = contentType
        self.byteCount = dataSource.dataLength()
        self.creationTimestamp = nil
        self.sourceFilename = sourceFilename
        self.downloadUrl = nil
        self.localRelativeFilePath = Attachment.localRelativeFilePath(from: originalFilePath)
        self.width = imageSize.map { UInt(floor($0.width)) }
        self.height = imageSize.map { UInt(floor($0.height)) }
        self.duration = duration
        self.isVisualMedia = (
            MIMETypeUtil.isImage(contentType) ||
            MIMETypeUtil.isVideo(contentType) ||
            MIMETypeUtil.isAnimated(contentType)
        )
        self.isValid = isValid
        self.encryptionKey = nil
        self.digest = nil
        self.caption = caption
    }
}

// MARK: - CustomStringConvertible

extension Attachment: CustomStringConvertible {
    public struct DescriptionInfo: FetchableRecord, Decodable, Equatable, Hashable, ColumnExpressible {
        public typealias Columns = CodingKeys
        public enum CodingKeys: String, CodingKey, ColumnExpression, CaseIterable {
            case id
            case variant
            case contentType
            case sourceFilename
        }
        
        let id: String
        let variant: Attachment.Variant
        let contentType: String
        let sourceFilename: String?
        
        public init(
            id: String,
            variant: Attachment.Variant,
            contentType: String,
            sourceFilename: String?
        ) {
            self.id = id
            self.variant = variant
            self.contentType = contentType
            self.sourceFilename = sourceFilename
        }
    }
    
    public static func description(for descriptionInfo: DescriptionInfo?, count: Int?) -> String? {
        guard let descriptionInfo: DescriptionInfo = descriptionInfo else {
            return nil
        }
        
        return description(for: descriptionInfo, count: (count ?? 1))
    }
    
    public static func description(for descriptionInfo: DescriptionInfo, count: Int) -> String {
        // We only support multi-attachment sending of images so we can just default to the image attachment
        // if there were multiple attachments
        guard count == 1 else { return "\(emoji(for: OWSMimeTypeImageJpeg)) \("ATTACHMENT".localized())" }
        
        if MIMETypeUtil.isAudio(descriptionInfo.contentType) {
            // a missing filename is the legacy way to determine if an audio attachment is
            // a voice note vs. other arbitrary audio attachments.
            if
                descriptionInfo.variant == .voiceMessage ||
                descriptionInfo.sourceFilename == nil ||
                (descriptionInfo.sourceFilename?.count ?? 0) == 0
            {
                return "🎙️ \("ATTACHMENT_TYPE_VOICE_MESSAGE".localized())"
            }
        }
        
        return "\(emoji(for: descriptionInfo.contentType)) \("ATTACHMENT".localized())"
    }
    
    public static func emoji(for contentType: String) -> String {
        if MIMETypeUtil.isImage(contentType) {
            return "📷"     // stringlint:disable
        }
        else if MIMETypeUtil.isVideo(contentType) {
            return "🎥"     // stringlint:disable
        }
        else if MIMETypeUtil.isAudio(contentType) {
            return "🎧"     // stringlint:disable
        }
        else if MIMETypeUtil.isAnimated(contentType) {
            return "🎡"     // stringlint:disable
        }
        
        return "📎"         // stringlint:disable
    }
    
    public var description: String {
        return Attachment.description(
            for: DescriptionInfo(
                id: id,
                variant: variant,
                contentType: contentType,
                sourceFilename: sourceFilename
            ),
            count: 1
        )
    }
}

// MARK: - Mutation

extension Attachment {
    public func with(
        serverId: String? = nil,
        state: State? = nil,
        creationTimestamp: TimeInterval? = nil,
        downloadUrl: String? = nil,
        localRelativeFilePath: String? = nil,
        encryptionKey: Data? = nil,
        digest: Data? = nil
    ) -> Attachment {
        let (isValid, duration): (Bool, TimeInterval?) = {
            switch (self.state, state) {
                case (_, .downloaded):
                    return Attachment.determineValidityAndDuration(
                        contentType: contentType,
                        localRelativeFilePath: localRelativeFilePath,
                        originalFilePath: originalFilePath
                    )
                
                // Assume the data is already correct for "uploading" attachments (and don't override it)
                case (.uploading, _), (.uploaded, _), (.failedUpload, _): return (self.isValid, self.duration)
                case (_, .failedDownload): return (false, nil)
                    
                default: return (self.isValid, self.duration)
            }
        }()
        // Regenerate this just in case we added support since the attachment was inserted into
        // the database (eg. manually downloaded in a later update)
        let isVisualMedia: Bool = (
            MIMETypeUtil.isImage(contentType) ||
            MIMETypeUtil.isVideo(contentType) ||
            MIMETypeUtil.isAnimated(contentType)
        )
        let attachmentResolution: CGSize? = {
            if let width: UInt = self.width, let height: UInt = self.height, width > 0, height > 0 {
                return CGSize(width: Int(width), height: Int(height))
            }
            guard isVisualMedia else { return nil }
            guard state == .downloaded else { return nil }
            guard let originalFilePath: String = originalFilePath else { return nil }
            
            return Attachment.imageSize(contentType: contentType, originalFilePath: originalFilePath)
        }()
        
        return Attachment(
            id: self.id,
            serverId: (serverId ?? self.serverId),
            variant: variant,
            state: (state ?? self.state),
            contentType: contentType,
            byteCount: byteCount,
            creationTimestamp: (creationTimestamp ?? self.creationTimestamp),
            sourceFilename: sourceFilename,
            downloadUrl: (downloadUrl ?? self.downloadUrl),
            localRelativeFilePath: (localRelativeFilePath ?? self.localRelativeFilePath),
            width: attachmentResolution.map { UInt($0.width) },
            height: attachmentResolution.map { UInt($0.height) },
            duration: duration,
            isVisualMedia: (
                // Regenerate this just in case we added support since the attachment was inserted into
                // the database (eg. manually downloaded in a later update)
                MIMETypeUtil.isImage(contentType) ||
                MIMETypeUtil.isVideo(contentType) ||
                MIMETypeUtil.isAnimated(contentType)
            ),
            isValid: isValid,
            encryptionKey: (encryptionKey ?? self.encryptionKey),
            digest: (digest ?? self.digest),
            caption: self.caption
        )
    }
}

// MARK: - Protobuf

extension Attachment {
    public init(proto: SNProtoAttachmentPointer) {
        func inferContentType(from filename: String?) -> String {
            guard
                let fileName: String = filename,
                let fileExtension: String = URL(string: fileName)?.pathExtension
            else { return OWSMimeTypeApplicationOctetStream }
            
            return (MIMETypeUtil.mimeType(forFileExtension: fileExtension) ?? OWSMimeTypeApplicationOctetStream)
        }
        
        self.id = UUID().uuidString
        self.serverId = "\(proto.id)"
        self.variant = {
            let voiceMessageFlag: Int32 = SNProtoAttachmentPointer.SNProtoAttachmentPointerFlags
                .voiceMessage
                .rawValue
            
            guard proto.hasFlags && ((proto.flags & UInt32(voiceMessageFlag)) > 0) else {
                return .standard
            }
            
            return .voiceMessage
        }()
        self.state = .pendingDownload
        self.contentType = (proto.contentType ?? inferContentType(from: proto.fileName))
        self.byteCount = UInt(proto.size)
        self.creationTimestamp = nil
        self.sourceFilename = proto.fileName
        self.downloadUrl = proto.url
        self.localRelativeFilePath = nil
        self.width = (proto.hasWidth && proto.width > 0 ? UInt(proto.width) : nil)
        self.height = (proto.hasHeight && proto.height > 0 ? UInt(proto.height) : nil)
        self.duration = nil         // Needs to be downloaded to be set
        self.isVisualMedia = (
            MIMETypeUtil.isImage(contentType) ||
            MIMETypeUtil.isVideo(contentType) ||
            MIMETypeUtil.isAnimated(contentType)
        )
        self.isValid = false        // Needs to be downloaded to be set
        self.encryptionKey = proto.key
        self.digest = proto.digest
        self.caption = (proto.hasCaption ? proto.caption : nil)
    }
    
    public func buildProto() -> SNProtoAttachmentPointer? {
        guard let serverId: UInt64 = UInt64(self.serverId ?? "") else { return nil }
        
        let builder = SNProtoAttachmentPointer.builder(id: serverId)
        builder.setContentType(contentType)
        
        if let sourceFilename: String = sourceFilename, !sourceFilename.isEmpty {
            builder.setFileName(sourceFilename)
        }
        
        if let caption: String = self.caption, !caption.isEmpty {
            builder.setCaption(caption)
        }
        
        builder.setSize(UInt32(byteCount))
        builder.setFlags(variant == .voiceMessage ?
            UInt32(SNProtoAttachmentPointer.SNProtoAttachmentPointerFlags.voiceMessage.rawValue) :
            0
        )
        
        if let encryptionKey: Data = encryptionKey, let digest: Data = digest {
            builder.setKey(encryptionKey)
            builder.setDigest(digest)
        }
        
        if
            let width: UInt = self.width,
            let height: UInt = self.height,
            width > 0,
            width < Int.max,
            height > 0,
            height < Int.max
        {
            builder.setWidth(UInt32(width))
            builder.setHeight(UInt32(height))
        }
        
        if let downloadUrl: String = self.downloadUrl {
            builder.setUrl(downloadUrl)
        }
        
        do {
            return try builder.build()
        }
        catch {
            SNLog("Couldn't construct attachment proto from: \(self).")
            return nil
        }
    }
}

// MARK: - GRDB Interactions

extension Attachment {
    public struct StateInfo: FetchableRecord, Decodable {
        public let attachmentId: String
        public let interactionId: Int64
        public let state: Attachment.State
        public let downloadUrl: String?
        public let albumIndex: Int
    }
    
    public static func stateInfo(authorId: String, state: State? = nil) -> SQLRequest<Attachment.StateInfo> {
        let attachment: TypedTableAlias<Attachment> = TypedTableAlias()
        let interaction: TypedTableAlias<Interaction> = TypedTableAlias()
        let quote: TypedTableAlias<Quote> = TypedTableAlias()
        let interactionAttachment: TypedTableAlias<InteractionAttachment> = TypedTableAlias()
        let linkPreview: TypedTableAlias<LinkPreview> = TypedTableAlias()
        
        // Note: In GRDB all joins need to run via their "association" system which doesn't support the type
        // of query we have below (a required join based on one of 3 optional joins) so we have to construct
        // the query manually
        return """
            SELECT DISTINCT
                \(attachment[.id]) AS attachmentId,
                \(interaction[.id]) AS interactionId,
                \(attachment[.state]) AS state,
                \(attachment[.downloadUrl]) AS downloadUrl,
                IFNULL(\(interactionAttachment[.albumIndex]), 0) AS albumIndex
        
            FROM \(Attachment.self)
            
            JOIN \(Interaction.self) ON
                \(SQL("\(interaction[.authorId]) = \(authorId)")) AND (
                    \(interaction[.id]) = \(quote[.interactionId]) OR
                    \(interaction[.id]) = \(interactionAttachment[.interactionId]) OR
                    (
                        \(interaction[.linkPreviewUrl]) = \(linkPreview[.url]) AND
                        \(Interaction.linkPreviewFilterLiteral())
                    )
                )
            
            LEFT JOIN \(Quote.self) ON \(quote[.attachmentId]) = \(attachment[.id])
            LEFT JOIN \(InteractionAttachment.self) ON \(interactionAttachment[.attachmentId]) = \(attachment[.id])
            LEFT JOIN \(LinkPreview.self) ON
                \(linkPreview[.attachmentId]) = \(attachment[.id]) AND
                \(SQL("\(linkPreview[.variant]) = \(LinkPreview.Variant.standard)"))
        
            WHERE
                (
                    \(SQL("\(state) IS NULL")) OR
                    \(SQL("\(attachment[.state]) = \(state)"))
                )
        
            ORDER BY interactionId DESC
        """
    }

    public static func stateInfo(interactionId: Int64, state: State? = nil) -> SQLRequest<Attachment.StateInfo> {
        let attachment: TypedTableAlias<Attachment> = TypedTableAlias()
        let interaction: TypedTableAlias<Interaction> = TypedTableAlias()
        let quote: TypedTableAlias<Quote> = TypedTableAlias()
        let interactionAttachment: TypedTableAlias<InteractionAttachment> = TypedTableAlias()
        let linkPreview: TypedTableAlias<LinkPreview> = TypedTableAlias()
        
        // Note: In GRDB all joins need to run via their "association" system which doesn't support the type
        // of query we have below (a required join based on one of 3 optional joins) so we have to construct
        // the query manually
        return """
            SELECT DISTINCT
                \(attachment[.id]) AS attachmentId,
                \(interaction[.id]) AS interactionId,
                \(attachment[.state]) AS state,
                \(attachment[.downloadUrl]) AS downloadUrl,
                IFNULL(\(interactionAttachment[.albumIndex]), 0) AS albumIndex
        
            FROM \(Attachment.self)
            
            JOIN \(Interaction.self) ON
                \(SQL("\(interaction[.id]) = \(interactionId)")) AND (
                    \(interaction[.id]) = \(quote[.interactionId]) OR
                    \(interaction[.id]) = \(interactionAttachment[.interactionId]) OR
                    (
                        \(interaction[.linkPreviewUrl]) = \(linkPreview[.url]) AND
                        \(Interaction.linkPreviewFilterLiteral())
                    )
                )
            
            LEFT JOIN \(Quote.self) ON \(quote[.attachmentId]) = \(attachment[.id])
            LEFT JOIN \(InteractionAttachment.self) ON \(interactionAttachment[.attachmentId]) = \(attachment[.id])
            LEFT JOIN \(LinkPreview.self) ON
                \(linkPreview[.attachmentId]) = \(attachment[.id]) AND
                \(SQL("\(linkPreview[.variant]) = \(LinkPreview.Variant.standard)"))
        
            WHERE
                (
                    \(SQL("\(state) IS NULL")) OR
                    \(SQL("\(attachment[.state]) = \(state)"))
                )
        """
    }
}

// MARK: - Convenience - Static

extension Attachment {
    private static let thumbnailDimensionSmall: UInt = 200
    private static let thumbnailDimensionMedium: UInt = 450
    
    /// This size is large enough to render full screen
    private static var thumbnailDimensionLarge: UInt = {
        let screenSizePoints: CGSize = UIScreen.main.bounds.size
        let minZoomFactor: CGFloat = UIScreen.main.scale
        
        return UInt(floor(max(screenSizePoints.width, screenSizePoints.height) * minZoomFactor))
    }()
    
    private static var sharedDataAttachmentsDirPath: String = {
        URL(fileURLWithPath: OWSFileSystem.appSharedDataDirectoryPath())
            .appendingPathComponent("Attachments")
            .path
    }()
    
    internal static var attachmentsFolder: String = {
        let attachmentsFolder: String = sharedDataAttachmentsDirPath
        OWSFileSystem.ensureDirectoryExists(attachmentsFolder)
        
        return attachmentsFolder
    }()
    
    public static func resetAttachmentStorage() {
        try? FileManager.default.removeItem(atPath: Attachment.sharedDataAttachmentsDirPath)
    }
    
    public static func originalFilePath(id: String, mimeType: String, sourceFilename: String?) -> String? {
        return MIMETypeUtil.filePath(
            forAttachment: id,
            ofMIMEType: mimeType,
            sourceFilename: sourceFilename,
            inFolder: Attachment.attachmentsFolder
        )
    }
    
    public static func localRelativeFilePath(from originalFilePath: String?) -> String? {
        guard let originalFilePath: String = originalFilePath else { return nil }
        
        return originalFilePath
            .substring(from: (Attachment.attachmentsFolder.count + 1))  // Leading forward slash
    }
    
    internal static func imageSize(contentType: String, originalFilePath: String) -> CGSize? {
        let isVideo: Bool = MIMETypeUtil.isVideo(contentType)
        let isImage: Bool = MIMETypeUtil.isImage(contentType)
        let isAnimated: Bool = MIMETypeUtil.isAnimated(contentType)
        
        guard isVideo || isImage || isAnimated else { return nil }
        
        if isVideo {
            guard OWSMediaUtils.isValidVideo(path: originalFilePath) else { return nil }
            
            return Attachment.videoStillImage(filePath: originalFilePath)?.size
        }
        
        return NSData.imageSize(forFilePath: originalFilePath, mimeType: contentType)
    }
    
    public static func videoStillImage(filePath: String) -> UIImage? {
        return try? OWSMediaUtils.thumbnail(
            forVideoAtPath: filePath,
            maxDimension: CGFloat(Attachment.thumbnailDimensionLarge)
        )
    }
    
    internal static func determineValidityAndDuration(
        contentType: String,
        localRelativeFilePath: String?,
        originalFilePath: String?
    ) -> (isValid: Bool, duration: TimeInterval?) {
        guard let originalFilePath: String = originalFilePath else { return (false, nil) }
        
        let constructedFilePath: String? = localRelativeFilePath.map {
            URL(fileURLWithPath: Attachment.attachmentsFolder)
                .appendingPathComponent($0)
                .path
        }
        let targetPath: String = (constructedFilePath ?? originalFilePath)
        
        // Process audio attachments
        if MIMETypeUtil.isAudio(contentType) {
            do {
                let audioPlayer: AVAudioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: targetPath))
                
                return ((audioPlayer.duration > 0), audioPlayer.duration)
            }
            catch {
                switch (error as NSError).code {
                    case Int(kAudioFileInvalidFileError), Int(kAudioFileStreamError_InvalidFile):
                        // Ignore "invalid audio file" errors
                        return (false, nil)
                        
                    default: return (false, nil)
                }
            }
        }
        
        // Process image attachments
        if MIMETypeUtil.isImage(contentType) || MIMETypeUtil.isAnimated(contentType) {
            return (
                NSData.ows_isValidImage(atPath: targetPath, mimeType: contentType),
                nil
            )
        }
        
        // Process video attachments
        if MIMETypeUtil.isVideo(contentType) {
            let asset: AVURLAsset = AVURLAsset(url: URL(fileURLWithPath: targetPath), options: nil)
            let durationSeconds: TimeInterval = (
                // According to the CMTime docs "value/timescale = seconds"
                TimeInterval(asset.duration.value) / TimeInterval(asset.duration.timescale)
            )
            
            return (
                OWSMediaUtils.isValidVideo(path: targetPath),
                durationSeconds
            )
        }
        
        // Any other attachment types are valid and have no duration
        return (true, nil)
    }
}

// MARK: - Convenience

extension Attachment {
    public static let nonMediaQuoteFileId: String = "NON_MEDIA_QUOTE_FILE_ID"
    
    public enum ThumbnailSize {
        case small
        case medium
        case large
        
        var dimension: UInt {
            switch self {
                case .small: return Attachment.thumbnailDimensionSmall
                case .medium: return Attachment.thumbnailDimensionMedium
                case .large: return Attachment.thumbnailDimensionLarge
            }
        }
    }
    
    public var originalFilePath: String? {
        if let localRelativeFilePath: String = self.localRelativeFilePath {
            return URL(fileURLWithPath: Attachment.attachmentsFolder)
                .appendingPathComponent(localRelativeFilePath)
                .path
        }
        
        return Attachment.originalFilePath(
            id: self.id,
            mimeType: self.contentType,
            sourceFilename: self.sourceFilename
        )
    }
    
    var thumbnailsDirPath: String {
        // Thumbnails are written to the caches directory, so that iOS can
        // remove them if necessary
        return "\(OWSFileSystem.cachesDirectoryPath())/\(id)-thumbnails"
    }
    
    var legacyThumbnailPath: String? {
        guard
            let originalFilePath: String = originalFilePath,
            (isImage || isVideo || isAnimated)
        else { return nil }
        
        let fileUrl: URL = URL(fileURLWithPath: originalFilePath)
        let filename: String = fileUrl.lastPathComponent.filenameWithoutExtension
        let containingDir: String = fileUrl.deletingLastPathComponent().path
        
        return "\(containingDir)/\(filename)-signal-ios-thumbnail.jpg"
    }
    
    var originalImage: UIImage? {
        guard let originalFilePath: String = originalFilePath else { return nil }
        
        if isVideo {
            return Attachment.videoStillImage(filePath: originalFilePath)
        }
        
        guard isImage || isAnimated else { return nil }
        guard isValid else { return nil }
        
        return UIImage(contentsOfFile: originalFilePath)
    }
    
    public var isImage: Bool { MIMETypeUtil.isImage(contentType) }
    public var isVideo: Bool { MIMETypeUtil.isVideo(contentType) }
    public var isAnimated: Bool { MIMETypeUtil.isAnimated(contentType) }
    public var isAudio: Bool { MIMETypeUtil.isAudio(contentType) }
    public var isText: Bool { MIMETypeUtil.isText(contentType) }
    public var isMicrosoftDoc: Bool { MIMETypeUtil.isMicrosoftDoc(contentType) }
    
    public var documentFileName: String {
        if let sourceFilename: String = sourceFilename { return sourceFilename }
        if isImage { return "Image File" }
        if isAudio { return "Audio File" }
        if isVideo { return "Video File" }
        return "File"
    }
    
    public var shortDescription: String {
        if isImage { return "Image" }
        if isAudio { return "Audio" }
        if isVideo { return "Video" }
        return "Document"
    }
    
    public var documentFileInfo: String {
        switch duration {
            case .some(let duration) where duration > 0:
                return "\(Format.fileSize(byteCount)), \(Format.duration(duration))"
                
            default: return Format.fileSize(byteCount)
        }
    }
    
    public func readDataFromFile() throws -> Data? {
        guard let filePath: String = self.originalFilePath else {
            return nil
        }
        
        return try Data(contentsOf: URL(fileURLWithPath: filePath))
    }
    
    public func thumbnailPath(for dimensions: UInt) -> String {
        return "\(thumbnailsDirPath)/thumbnail-\(dimensions).jpg"
    }
    
    private func loadThumbnail(with dimensions: UInt, success: @escaping (UIImage, () throws -> Data) -> (), failure: @escaping () -> ()) {
        guard let width: UInt = self.width, let height: UInt = self.height, width > 1, height > 1 else {
            failure()
            return
        }
        
        // There's no point in generating a thumbnail if the original is smaller than the
        // thumbnail size
        if width < dimensions || height < dimensions {
            guard let image: UIImage = originalImage else {
                failure()
                return
            }
            
            success(
                image,
                {
                    guard let originalFilePath: String = originalFilePath else { throw AttachmentError.invalidData }
                    
                    return try Data(contentsOf: URL(fileURLWithPath: originalFilePath))
                }
            )
            return
        }
        
        let thumbnailPath = thumbnailPath(for: dimensions)
        
        if FileManager.default.fileExists(atPath: thumbnailPath) {
            guard
                let data: Data = try? Data(contentsOf: URL(fileURLWithPath: thumbnailPath)),
                let image: UIImage = UIImage(data: data)
            else {
                failure()
                return
            }
            
            success(image, { data })
            return
        }
        
        ThumbnailService.shared.ensureThumbnail(
            for: self,
            dimensions: dimensions,
            success: { loadedThumbnail in success(loadedThumbnail.image, loadedThumbnail.dataSourceBlock) },
            failure: { _ in failure() }
        )
    }
    
    public func thumbnail(size: ThumbnailSize, success: @escaping (UIImage, () throws -> Data) -> (), failure: @escaping () -> ()) {
        loadThumbnail(with: size.dimension, success: success, failure: failure)
    }
    
    public func existingThumbnail(size: ThumbnailSize) -> UIImage? {
        var existingImage: UIImage?
        
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        loadThumbnail(
            with: size.dimension,
            success: { image, _ in
                existingImage = image
                semaphore.signal()
            },
            failure: { semaphore.signal() }
        )
        
        // We don't really want to wait at all so having a tiny timeout here will give the
        // 'loadThumbnail' call the change to return a result for an existing thumbnail but
        // not a new one
        _ = semaphore.wait(timeout: .now() + .milliseconds(10))
        
        return existingImage
    }
    
    public func cloneAsQuoteThumbnail() -> Attachment? {
        let cloneId: String = UUID().uuidString
        let thumbnailName: String = "quoted-thumbnail-\(sourceFilename ?? "null")"
        
        guard self.isVisualMedia else { return nil }
        
        guard
            self.isValid,
            let thumbnailPath: String = Attachment.originalFilePath(
                id: cloneId,
                mimeType: OWSMimeTypeImageJpeg,
                sourceFilename: thumbnailName
            )
        else {
            // Non-media files cannot have thumbnails but may be sent as quotes, in these cases we want
            // to create an attachment in an 'uploaded' state with a hard-coded file id so the messageSend
            // job doesn't try to upload the attachment (we include the original `serverId` as it's
            // required for generating the protobuf)
            return Attachment(
                id: cloneId,
                serverId: self.serverId,
                variant: self.variant,
                state: .uploaded,
                contentType: self.contentType,
                byteCount: 0,
                downloadUrl: Attachment.nonMediaQuoteFileId,
                isValid: self.isValid
            )
        }
        
        // Try generate the thumbnail
        var thumbnailData: Data?
        let semaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        
        self.thumbnail(
            size: .small,
            success: { _, dataSourceBlock in
                thumbnailData = try? dataSourceBlock()
                semaphore.signal()
            },
            failure: { semaphore.signal() }
        )
        
        // Wait up to 0.5 seconds
        _ = semaphore.wait(timeout: .now() + .milliseconds(500))
        
        guard let thumbnailData: Data = thumbnailData else { return nil }
        
        // Write the quoted thumbnail to disk
        do { try thumbnailData.write(to: URL(fileURLWithPath: thumbnailPath)) }
        catch { return nil }
        
        // Need to retrieve the size of the thumbnail as it maintains it's aspect ratio
        let thumbnailSize: CGSize = Attachment
            .imageSize(
                contentType: OWSMimeTypeImageJpeg,
                originalFilePath: thumbnailPath
            )
            .defaulting(
                to: CGSize(
                    width: Int(ThumbnailSize.small.dimension),
                    height: Int(ThumbnailSize.small.dimension)
                )
            )
        
        // Copy the thumbnail to a new attachment
        return Attachment(
            id: cloneId,
            variant: .standard,
            state: .downloaded,
            contentType: OWSMimeTypeImageJpeg,
            byteCount: UInt(thumbnailData.count),
            sourceFilename: thumbnailName,
            localRelativeFilePath: Attachment.localRelativeFilePath(from: thumbnailPath),
            width: UInt(thumbnailSize.width),
            height: UInt(thumbnailSize.height),
            isValid: true
        )
    }
    
    public func write(data: Data) throws -> Bool {
        guard let originalFilePath: String = originalFilePath else { return false }

        try data.write(to: URL(fileURLWithPath: originalFilePath))

        return true
    }
    
    public static func fileId(for downloadUrl: String?) -> String? {
        return downloadUrl
            .map { urlString -> String? in
                urlString
                    .split(separator: "/")  // stringlint:disable
                    .last
                    .map { String($0) }
            }
    }
}

// MARK: - Upload

extension Attachment {
    public enum Destination {
        case fileServer
        case openGroup(OpenGroup)
        
        var shouldEncrypt: Bool {
            switch self {
                case .fileServer: return true
                case .openGroup: return false
            }
        }
    }
    
    public struct PreparedData {
        public let attachments: [Attachment]
    }
    
    public static func prepare(attachments: [SignalAttachment]) -> PreparedData {
        return PreparedData(
            attachments: attachments.compactMap { signalAttachment in
                Attachment(
                    variant: (signalAttachment.isVoiceMessage ?
                        .voiceMessage :
                        .standard
                    ),
                    contentType: signalAttachment.mimeType,
                    dataSource: signalAttachment.dataSource,
                    sourceFilename: signalAttachment.sourceFilename,
                    caption: signalAttachment.captionText
                )
            }
        )
    }
    
    public static func process(
        _ db: Database,
        data: PreparedData?,
        for interactionId: Int64?
    ) throws {
        guard
            let data: PreparedData = data,
            let interactionId: Int64 = interactionId
        else { return }
                
        try data.attachments
            .enumerated()
            .forEach { index, attachment in
                let interactionAttachment: InteractionAttachment = InteractionAttachment(
                    albumIndex: index,
                    interactionId: interactionId,
                    attachmentId: attachment.id
                )
                
                try attachment.insert(db)
                try interactionAttachment.insert(db)
            }
    }
    
    internal func upload(
        to destination: Attachment.Destination,
        using dependencies: Dependencies
    ) -> AnyPublisher<String?, Error> {
        // This can occur if an AttachmnetUploadJob was explicitly created for a message
        // dependant on the attachment being uploaded (in this case the attachment has
        // already been uploaded so just succeed)
        guard state != .uploaded else {
            return Just(Attachment.fileId(for: self.downloadUrl))
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Get the attachment
        guard var data = try? readDataFromFile() else {
            SNLog("Couldn't read attachment from disk.")
            return Fail(error: AttachmentError.noAttachment)
                .eraseToAnyPublisher()
        }
        
        let attachmentId: String = self.id
        
        return Storage.shared
            .writePublisher { db -> (OpenGroupAPI.PreparedSendData<FileUploadResponse>?, String?, Data?, Data?) in
                // If the attachment is a downloaded attachment, check if it came from
                // the server and if so just succeed immediately (no use re-uploading
                // an attachment that is already present on the server) - or if we want
                // it to be encrypted and it's not then encrypt it
                //
                // Note: The most common cases for this will be for LinkPreviews or Quotes
                guard
                    state != .downloaded ||
                    serverId == nil ||
                    downloadUrl == nil ||
                    !destination.shouldEncrypt ||
                    encryptionKey == nil ||
                    digest == nil
                else {
                    // Save the final upload info
                    _ = try? Attachment
                        .filter(id: attachmentId)
                        .updateAll(db, Attachment.Columns.state.set(to: Attachment.State.uploaded))
                    
                    return (nil, Attachment.fileId(for: self.downloadUrl), nil, nil)
                }
                
                var encryptionKey: NSData = NSData()
                var digest: NSData = NSData()
                
                // Encrypt the attachment if needed
                if destination.shouldEncrypt {
                    guard let ciphertext = Cryptography.encryptAttachmentData(data, shouldPad: true, outKey: &encryptionKey, outDigest: &digest) else {
                        SNLog("Couldn't encrypt attachment.")
                        throw AttachmentError.encryptionFailed
                    }
                    
                    data = ciphertext
                }
                
                // Check the file size
                SNLog("File size: \(data.count) bytes.")
                if data.count > FileServerAPI.maxFileSize { throw HTTPError.maxFileSizeExceeded }
                
                // Update the attachment to the 'uploading' state
                _ = try? Attachment
                    .filter(id: attachmentId)
                    .updateAll(db, Attachment.Columns.state.set(to: Attachment.State.uploading))
                
                // We need database access for OpenGroup uploads so generate prepared data
                let preparedSendData: OpenGroupAPI.PreparedSendData<FileUploadResponse>? = try {
                    switch destination {
                        case .openGroup(let openGroup):
                            return try OpenGroupAPI
                                .preparedUploadFile(
                                    db,
                                    bytes: data.bytes,
                                    to: openGroup.roomToken,
                                    on: openGroup.server
                                )
                        
                        default: return nil
                    }
                }()
                
                return (
                    preparedSendData,
                    nil,
                    (destination.shouldEncrypt ? encryptionKey as Data : nil),
                    (destination.shouldEncrypt ? digest as Data : nil)
                )
            }
            .flatMap { preparedSendData, existingFileId, encryptionKey, digest -> AnyPublisher<(String?, Data?, Data?), Error> in
                // No need to upload if the file was already uploaded
                if let fileId: String = existingFileId {
                    return Just((fileId, encryptionKey, digest))
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
                
                switch destination {
                    case .openGroup:
                        return OpenGroupAPI.send(data: preparedSendData)
                            .map { _, response -> (String, Data?, Data?) in (response.id, encryptionKey, digest) }
                            .eraseToAnyPublisher()
                        
                    case .fileServer:
                        return FileServerAPI.upload(data)
                            .map { response -> (String, Data?, Data?) in (response.id, encryptionKey, digest) }
                            .eraseToAnyPublisher()
                }
            }
            .flatMap { fileId, encryptionKey, digest -> AnyPublisher<String?, Error> in
                /// Save the final upload info
                ///
                /// **Note:** We **MUST** use the `.with` function here to ensure the `isValid` flag is
                /// updated correctly
                Storage.shared
                    .writePublisher { db in
                        try self
                            .with(
                                serverId: fileId,
                                state: .uploaded,
                                creationTimestamp: (
                                    self.creationTimestamp ??
                                    (TimeInterval(SnodeAPI.currentOffsetTimestampMs()) / 1000)
                                ),
                                downloadUrl: fileId.map { "\(FileServerAPI.server)/file/\($0)" },
                                encryptionKey: encryptionKey,
                                digest: digest
                            )
                            .saved(db)
                    }
                    .map { _ in fileId }
                    .eraseToAnyPublisher()
            }
            .handleEvents(
                receiveCompletion: { result in
                    switch result {
                        case .finished: break
                        case .failure:
                            Storage.shared.write { db in
                                try Attachment
                                    .filter(id: attachmentId)
                                    .updateAll(db, Attachment.Columns.state.set(to: Attachment.State.failedUpload))
                            }
                    }
                }
            )
            .eraseToAnyPublisher()
    }
}

// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import GRDB

public struct QuotedReplyModel {
    public let threadId: String
    public let authorId: String
    public let timestampMs: Int64
    public let body: String?
    public let attachment: Attachment?
    public let contentType: String?
    public let sourceFileName: String?
    public let thumbnailDownloadFailed: Bool
    public let currentUserPublicKey: String?
    public let currentUserBlinded15PublicKey: String?
    public let currentUserBlinded25PublicKey: String?
    
    // MARK: - Initialization
    
    init(
        threadId: String,
        authorId: String,
        timestampMs: Int64,
        body: String?,
        attachment: Attachment?,
        contentType: String?,
        sourceFileName: String?,
        thumbnailDownloadFailed: Bool,
        currentUserPublicKey: String?,
        currentUserBlinded15PublicKey: String?,
        currentUserBlinded25PublicKey: String?
    ) {
        self.attachment = attachment
        self.threadId = threadId
        self.authorId = authorId
        self.timestampMs = timestampMs
        self.body = body
        self.contentType = contentType
        self.sourceFileName = sourceFileName
        self.thumbnailDownloadFailed = thumbnailDownloadFailed
        self.currentUserPublicKey = currentUserPublicKey
        self.currentUserBlinded15PublicKey = currentUserBlinded15PublicKey
        self.currentUserBlinded25PublicKey = currentUserBlinded25PublicKey
    }
    
    public static func quotedReplyForSending(
        threadId: String,
        authorId: String,
        variant: Interaction.Variant,
        body: String?,
        timestampMs: Int64,
        attachments: [Attachment]?,
        linkPreviewAttachment: Attachment?,
        currentUserPublicKey: String?,
        currentUserBlinded15PublicKey: String?,
        currentUserBlinded25PublicKey: String?
    ) -> QuotedReplyModel? {
        guard variant == .standardOutgoing || variant == .standardIncoming else { return nil }
        guard (body != nil && body?.isEmpty == false) || attachments?.isEmpty == false else { return nil }
        
        let targetAttachment: Attachment? = (attachments?.first ?? linkPreviewAttachment)
        
        return QuotedReplyModel(
            threadId: threadId,
            authorId: authorId,
            timestampMs: timestampMs,
            body: body,
            attachment: targetAttachment,
            contentType: targetAttachment?.contentType,
            sourceFileName: targetAttachment?.sourceFilename,
            thumbnailDownloadFailed: false,
            currentUserPublicKey: currentUserPublicKey,
            currentUserBlinded15PublicKey: currentUserBlinded15PublicKey,
            currentUserBlinded25PublicKey: currentUserBlinded25PublicKey
        )
    }
}

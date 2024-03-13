// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import GRDB
import Sodium
import SessionSnodeKit
import SessionUtilitiesKit

extension MessageReceiver {
    @discardableResult public static func handleVisibleMessage(
        _ db: Database,
        threadId: String,
        threadVariant: SessionThread.Variant,
        message: VisibleMessage,
        serverExpirationTimestamp: TimeInterval?,
        associatedWithProto proto: SNProtoContent,
        using dependencies: Dependencies = Dependencies()
    ) throws -> Int64 {
        guard let sender: String = message.sender, let dataMessage = proto.dataMessage else {
            throw MessageReceiverError.invalidMessage
        }
        
        // Note: `message.sentTimestamp` is in ms (convert to TimeInterval before converting to
        // seconds to maintain the accuracy)
        let messageSentTimestamp: TimeInterval = (TimeInterval(message.sentTimestamp ?? 0) / 1000)
        let isMainAppActive: Bool = (UserDefaults.sharedLokiProject?[.isMainAppActive]).defaulting(to: false)
        
        // Update profile if needed (want to do this regardless of whether the message exists or
        // not to ensure the profile info gets sync between a users devices at every chance)
        if let profile = message.profile {
            try ProfileManager.updateProfileIfNeeded(
                db,
                publicKey: sender,
                name: profile.displayName,
                blocksCommunityMessageRequests: profile.blocksCommunityMessageRequests,
                avatarUpdate: {
                    guard
                        let profilePictureUrl: String = profile.profilePictureUrl,
                        let profileKey: Data = profile.profileKey
                    else { return .remove }
                    
                    return .updateTo(
                        url: profilePictureUrl,
                        key: profileKey,
                        fileName: nil
                    )
                }(),
                sentTimestamp: messageSentTimestamp,
                using: dependencies
            )
        }
        
        switch threadVariant {
            case .contact: break // Always continue
            
            case .community:
                // Only process visible messages for communities if they have an existing thread
                guard (try? SessionThread.exists(db, id: threadId)) == true else {
                    throw MessageReceiverError.noThread
                }
                        
            case .legacyGroup, .group:
                // Only process visible messages for groups if they have a ClosedGroup record
                guard (try? ClosedGroup.exists(db, id: threadId)) == true else {
                    throw MessageReceiverError.noThread
                }
        }
        
        // Store the message variant so we can run variant-specific behaviours
        let currentUserPublicKey: String = getUserHexEncodedPublicKey(db, using: dependencies)
        let thread: SessionThread = try SessionThread
            .fetchOrCreate(db, id: threadId, variant: threadVariant, shouldBeVisible: nil)
        let maybeOpenGroup: OpenGroup? = {
            guard threadVariant == .community else { return nil }
            
            return try? OpenGroup.fetchOne(db, id: threadId)
        }()
        let variant: Interaction.Variant = try {
            guard
                let senderSessionId: SessionId = SessionId(from: sender),
                let openGroup: OpenGroup = maybeOpenGroup
            else {
                return (sender == currentUserPublicKey ?
                    .standardOutgoing :
                    .standardIncoming
                )
            }

            // Need to check if the blinded id matches for open groups
            switch senderSessionId.prefix {
                case .blinded15, .blinded25:
                    guard
                        let userEdKeyPair: KeyPair = Identity.fetchUserEd25519KeyPair(db),
                        let blindedKeyPair: KeyPair = dependencies.crypto.generate(
                            .blindedKeyPair(
                                serverPublicKey: openGroup.publicKey,
                                edKeyPair: userEdKeyPair,
                                using: dependencies
                            )
                        )
                    else { return .standardIncoming }
                    
                    let senderIdCurrentUserBlinded: Bool = (
                        sender == SessionId(.blinded15, publicKey: blindedKeyPair.publicKey).hexString ||
                        sender == SessionId(.blinded25, publicKey: blindedKeyPair.publicKey).hexString
                    )
                    
                    return (senderIdCurrentUserBlinded ?
                        .standardOutgoing :
                        .standardIncoming
                    )
                    
                case .standard, .unblinded:
                    return (sender == currentUserPublicKey ?
                        .standardOutgoing :
                        .standardIncoming
                    )
                    
                case .group:
                    SNLog("Ignoring message with invalid sender.")
                    throw HTTPError.parsingFailed
            }
        }()
        
        // Handle emoji reacts first (otherwise it's essentially an invalid message)
        if let interactionId: Int64 = try handleEmojiReactIfNeeded(
            db,
            thread: thread,
            message: message,
            associatedWithProto: proto,
            sender: sender,
            messageSentTimestamp: messageSentTimestamp,
            openGroup: maybeOpenGroup
        ) {
            return interactionId
        }
        // Try to insert the interaction
        //
        // Note: There are now a number of unique constraints on the database which
        // prevent the ability to insert duplicate interactions at a database level
        // so we don't need to check for the existance of a message beforehand anymore
        let interaction: Interaction
        // Auto-mark sent messages or messages older than the 'lastReadTimestampMs' as read
        let wasRead: Bool = (
            variant == .standardOutgoing ||
            SessionUtil.timestampAlreadyRead(
                threadId: thread.id,
                threadVariant: thread.variant,
                timestampMs: Int64(messageSentTimestamp * 1000),
                userPublicKey: currentUserPublicKey,
                openGroup: maybeOpenGroup
            )
        )
        let messageExpirationInfo: Message.MessageExpirationInfo = Message.getMessageExpirationInfo(
            wasRead: wasRead,
            serverExpirationTimestamp: serverExpirationTimestamp,
            expiresInSeconds: message.expiresInSeconds,
            expiresStartedAtMs: message.expiresStartedAtMs
        )
        do {
            interaction = try Interaction(
                serverHash: message.serverHash, // Keep track of server hash
                threadId: thread.id,
                authorId: sender,
                variant: variant,
                body: message.text,
                timestampMs: Int64(messageSentTimestamp * 1000),
                wasRead: wasRead,
                hasMention: Interaction.isUserMentioned(
                    db,
                    threadId: thread.id,
                    body: message.text,
                    quoteAuthorId: dataMessage.quote?.author,
                    using: dependencies
                ),
                expiresInSeconds: messageExpirationInfo.expiresInSeconds,
                expiresStartedAtMs: messageExpirationInfo.expiresStartedAtMs,
                // OpenGroupInvitations are stored as LinkPreview's in the database
                linkPreviewUrl: (message.linkPreview?.url ?? message.openGroupInvitation?.url),
                // Keep track of the open group server message ID ↔ message ID relationship
                openGroupServerMessageId: message.openGroupServerMessageId.map { Int64($0) },
                openGroupWhisperMods: (message.recipient?.contains(".mods") == true),
                openGroupWhisperTo: {
                    guard
                        let recipientParts: [String] = message.recipient?.components(separatedBy: "."),
                        recipientParts.count >= 3  // 'server.roomToken.whisperTo.whisperMods'
                    else { return nil }
                    
                    return recipientParts[2]
                }()
            ).inserted(db)
        }
        catch {
            switch error {
                case DatabaseError.SQLITE_CONSTRAINT_UNIQUE:
                    guard
                        variant == .standardOutgoing,
                        let existingInteractionId: Int64 = try? thread.interactions
                            .select(.id)
                            .filter(Interaction.Columns.timestampMs == (messageSentTimestamp * 1000))
                            .filter(Interaction.Columns.variant == variant)
                            .filter(Interaction.Columns.authorId == sender)
                            .asRequest(of: Int64.self)
                            .fetchOne(db)
                    else { break }
                    
                    // If we receive an outgoing message that already exists in the database
                    // then we still need to update the recipient and read states for the
                    // message (even if we don't need to do anything else)
                    try updateRecipientAndReadStatesForOutgoingInteraction(
                        db,
                        thread: thread,
                        interactionId: existingInteractionId,
                        messageSentTimestamp: messageSentTimestamp,
                        variant: variant,
                        syncTarget: message.syncTarget
                    )
                    
                    Message.getExpirationForOutgoingDisappearingMessages(
                        db,
                        threadId: threadId,
                        variant: variant,
                        serverHash: message.serverHash,
                        expireInSeconds: message.expiresInSeconds
                    )
                    
                default: break
            }
            
            throw error
        }
        
        guard let interactionId: Int64 = interaction.id else { throw StorageError.failedToSave }
        
        // Update and recipient and read states as needed
        try updateRecipientAndReadStatesForOutgoingInteraction(
            db,
            thread: thread,
            interactionId: interactionId,
            messageSentTimestamp: messageSentTimestamp,
            variant: variant,
            syncTarget: message.syncTarget
        )
        
        if messageExpirationInfo.shouldUpdateExpiry {
            Message.updateExpiryForDisappearAfterReadMessages(
                db,
                threadId: threadId,
                serverHash: message.serverHash,
                expiresInSeconds: message.expiresInSeconds,
                expiresStartedAtMs: message.expiresStartedAtMs
            )
        }
        
        Message.getExpirationForOutgoingDisappearingMessages(
            db,
            threadId: threadId,
            variant: variant,
            serverHash: message.serverHash,
            expireInSeconds: message.expiresInSeconds
        )
        
        // Parse & persist attachments
        let attachments: [Attachment] = try dataMessage.attachments
            .compactMap { proto -> Attachment? in
                let attachment: Attachment = Attachment(proto: proto)
                
                // Attachments on received messages must have a 'downloadUrl' otherwise
                // they are invalid and we can ignore them
                return (attachment.downloadUrl != nil ? attachment : nil)
            }
            .enumerated()
            .map { index, attachment in
                let savedAttachment: Attachment = try attachment.saved(db)
                
                // Link the attachment to the interaction and add to the id lookup
                try InteractionAttachment(
                    albumIndex: index,
                    interactionId: interactionId,
                    attachmentId: savedAttachment.id
                ).insert(db)
                
                return savedAttachment
            }
        
        message.attachmentIds = attachments.map { $0.id }
        
        // Persist quote if needed
        let quote: Quote? = try? Quote(
            db,
            proto: dataMessage,
            interactionId: interactionId,
            thread: thread
        )?.inserted(db)
        
        // Parse link preview if needed
        let linkPreview: LinkPreview? = try? LinkPreview(
            db,
            proto: dataMessage,
            sentTimestampMs: (messageSentTimestamp * 1000)
        )?.saved(db)
        
        // Open group invitations are stored as LinkPreview values so create one if needed
        if
            let openGroupInvitationUrl: String = message.openGroupInvitation?.url,
            let openGroupInvitationName: String = message.openGroupInvitation?.name
        {
            try LinkPreview(
                url: openGroupInvitationUrl,
                timestamp: LinkPreview.timestampFor(sentTimestampMs: (messageSentTimestamp * 1000)),
                variant: .openGroupInvitation,
                title: openGroupInvitationName
            ).save(db)
        }
        
        // Start attachment downloads if needed (ie. trusted contact or group thread)
        // FIXME: Replace this to check the `autoDownloadAttachments` flag we are adding to threads
        let isContactTrusted: Bool = ((try? Contact.fetchOne(db, id: sender))?.isTrusted ?? false)

        if isContactTrusted || thread.variant != .contact {
            attachments
                .map { $0.id }
                .appending(quote?.attachmentId)
                .appending(linkPreview?.attachmentId)
                .forEach { attachmentId in
                    dependencies.jobRunner.add(
                        db,
                        job: Job(
                            variant: .attachmentDownload,
                            threadId: thread.id,
                            interactionId: interactionId,
                            details: AttachmentDownloadJob.Details(
                                attachmentId: attachmentId
                            )
                        ),
                        canStartJob: isMainAppActive,
                        using: dependencies
                    )
                }
        }
        
        // Cancel any typing indicators if needed
        if isMainAppActive {
            TypingIndicators.didStopTyping(db, threadId: thread.id, direction: .incoming)
        }
        
        // Update the contact's approval status of the current user if needed (if we are getting messages from
        // them outside of a group then we can assume they have approved the current user)
        //
        // Note: This is to resolve a rare edge-case where a conversation was started with a user on an old
        // version of the app and their message request approval state was set via a migration rather than
        // by using the approval process
        if thread.variant == .contact {
            try MessageReceiver.updateContactApprovalStatusIfNeeded(
                db,
                senderSessionId: sender,
                threadId: thread.id
            )
        }
        
        // Notify the user if needed
        guard variant == .standardIncoming && !interaction.wasRead else { return interactionId }
        
        // Use the same identifier for notifications when in backgroud polling to prevent spam
        Environment.shared?.notificationsManager.wrappedValue?
            .notifyUser(
                db,
                for: interaction,
                in: thread,
                applicationState: (isMainAppActive ? .active : .background)
            )
        
        return interactionId
    }
    
    private static func handleEmojiReactIfNeeded(
        _ db: Database,
        thread: SessionThread,
        message: VisibleMessage,
        associatedWithProto proto: SNProtoContent,
        sender: String,
        messageSentTimestamp: TimeInterval,
        openGroup: OpenGroup?
    ) throws -> Int64? {
        guard
            let reaction: VisibleMessage.VMReaction = message.reaction,
            proto.dataMessage?.reaction != nil
        else { return nil }
        
        let maybeInteractionId: Int64? = try? Interaction
            .select(.id)
            .filter(Interaction.Columns.threadId == thread.id)
            .filter(Interaction.Columns.timestampMs == reaction.timestamp)
            .filter(Interaction.Columns.authorId == reaction.publicKey)
            .filter(Interaction.Columns.variant != Interaction.Variant.standardIncomingDeleted)
            .asRequest(of: Int64.self)
            .fetchOne(db)
        
        guard let interactionId: Int64 = maybeInteractionId else {
            throw StorageError.objectNotFound
        }
        
        let sortId = Reaction.getSortId(
            db,
            interactionId: interactionId,
            emoji: reaction.emoji
        )
        
        switch reaction.kind {
            case .react:
                // Determine whether the app is active based on the prefs rather than the UIApplication state to avoid
                // requiring main-thread execution
                let isMainAppActive: Bool = (UserDefaults.sharedLokiProject?[.isMainAppActive]).defaulting(to: false)
                let timestampMs: Int64 = Int64(messageSentTimestamp * 1000)
                let currentUserPublicKey: String = getUserHexEncodedPublicKey(db)
                let reaction: Reaction = try Reaction(
                    interactionId: interactionId,
                    serverHash: message.serverHash,
                    timestampMs: timestampMs,
                    authorId: sender,
                    emoji: reaction.emoji,
                    count: 1,
                    sortId: sortId
                ).inserted(db)
                let timestampAlreadyRead: Bool = SessionUtil.timestampAlreadyRead(
                    threadId: thread.id,
                    threadVariant: thread.variant,
                    timestampMs: timestampMs,
                    userPublicKey: currentUserPublicKey,
                    openGroup: openGroup
                )
                
                // Don't notify if the reaction was added before the lastest read timestamp for
                // the conversation
                if sender != currentUserPublicKey && !timestampAlreadyRead {
                    Environment.shared?.notificationsManager.wrappedValue?
                        .notifyUser(
                            db,
                            forReaction: reaction,
                            in: thread,
                            applicationState: (isMainAppActive ? .active : .background)
                        )
                }
            case .remove:
                try Reaction
                    .filter(Reaction.Columns.interactionId == interactionId)
                    .filter(Reaction.Columns.authorId == sender)
                    .filter(Reaction.Columns.emoji == reaction.emoji)
                    .deleteAll(db)
        }
        
        return interactionId
    }
    
    private static func updateRecipientAndReadStatesForOutgoingInteraction(
        _ db: Database,
        thread: SessionThread,
        interactionId: Int64,
        messageSentTimestamp: TimeInterval,
        variant: Interaction.Variant,
        syncTarget: String?
    ) throws {
        guard variant == .standardOutgoing else { return }
        
        // Immediately update any existing outgoing message 'RecipientState' records to be 'sent'
        _ = try? RecipientState
            .filter(RecipientState.Columns.interactionId == interactionId)
            .filter(RecipientState.Columns.state != RecipientState.State.sent)
            .updateAll(db, RecipientState.Columns.state.set(to: RecipientState.State.sent))
        
        // Create any addiitonal 'RecipientState' records as needed
        switch thread.variant {
            case .contact:
                if let syncTarget: String = syncTarget {
                    try RecipientState(
                        interactionId: interactionId,
                        recipientId: syncTarget,
                        state: .sent
                    ).save(db)
                }
                
            case .legacyGroup, .group:
                try GroupMember
                    .filter(GroupMember.Columns.groupId == thread.id)
                    .fetchAll(db)
                    .forEach { member in
                        try RecipientState(
                            interactionId: interactionId,
                            recipientId: member.profileId,
                            state: .sent
                        ).save(db)
                    }
                
            case .community:
                try RecipientState(
                    interactionId: interactionId,
                    recipientId: thread.id, // For open groups this will always be the thread id
                    state: .sent
                ).save(db)
        }
    
        // For outgoing messages mark all older interactions as read (the user should have seen
        // them if they send a message - also avoids a situation where the user has "phantom"
        // unread messages that they need to scroll back to before they become marked as read)
        try Interaction.markAsRead(
            db,
            interactionId: interactionId,
            threadId: thread.id,
            threadVariant: thread.variant,
            includingOlder: true,
            trySendReadReceipt: false
        )
        
        // Process any PendingReadReceipt values
        let maybePendingReadReceipt: PendingReadReceipt? = try PendingReadReceipt
            .filter(PendingReadReceipt.Columns.threadId == thread.id)
            .filter(PendingReadReceipt.Columns.interactionTimestampMs == Int64(messageSentTimestamp * 1000))
            .fetchOne(db)
        
        if let pendingReadReceipt: PendingReadReceipt = maybePendingReadReceipt {
            try Interaction.markAsRead(
                db,
                recipientId: thread.id,
                timestampMsValues: [pendingReadReceipt.interactionTimestampMs],
                readTimestampMs: pendingReadReceipt.readTimestampMs
            )
            
            _ = try pendingReadReceipt.delete(db)
        }
    }
}

// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import GRDB
import SessionSnodeKit
import SessionUtilitiesKit

/// Abstract base class for `VisibleMessage` and `ControlMessage`.
public class Message: Codable {
    public var id: String?
    public var sentTimestamp: UInt64?
    public var receivedTimestamp: UInt64?
    public var recipient: String?
    public var sender: String?
    public var openGroupServerMessageId: UInt64?
    public var serverHash: String?
    public var ttl: UInt64 { 14 * 24 * 60 * 60 * 1000 }
    public var isSelfSendValid: Bool { false }
    
    public var shouldBeRetryable: Bool { false }
    
    // MARK: - Disappearing Messages
    public var expiresInSeconds: TimeInterval?
    public var expiresStartedAtMs: Double?

    // MARK: - Validation
    
    public var isValid: Bool {
        if let sentTimestamp = sentTimestamp { guard sentTimestamp > 0 else { return false } }
        if let receivedTimestamp = receivedTimestamp { guard receivedTimestamp > 0 else { return false } }
        return sender != nil && recipient != nil
    }
    
    // MARK: - Initialization
    
    public init(
        id: String? = nil,
        sentTimestamp: UInt64? = nil,
        receivedTimestamp: UInt64? = nil,
        recipient: String? = nil,
        sender: String? = nil,
        openGroupServerMessageId: UInt64? = nil,
        serverHash: String? = nil,
        expiresInSeconds: TimeInterval? = nil,
        expiresStartedAtMs: Double? = nil
    ) {
        self.id = id
        self.sentTimestamp = sentTimestamp
        self.receivedTimestamp = receivedTimestamp
        self.recipient = recipient
        self.sender = sender
        self.openGroupServerMessageId = openGroupServerMessageId
        self.serverHash = serverHash
        self.expiresInSeconds = expiresInSeconds
        self.expiresStartedAtMs = expiresStartedAtMs
    }

    // MARK: - Proto Conversion
    
    public class func fromProto(_ proto: SNProtoContent, sender: String) -> Self? {
        preconditionFailure("fromProto(_:sender:) is abstract and must be overridden.")
    }

    public func toProto(_ db: Database, threadId: String) -> SNProtoContent? {
        preconditionFailure("toProto(_:) is abstract and must be overridden.")
    }
    
    public func setDisappearingMessagesConfigurationIfNeeded(on proto: SNProtoContent.SNProtoContentBuilder) {
        if let expiresInSeconds = self.expiresInSeconds {
            proto.setExpirationTimer(UInt32(expiresInSeconds))
        } else {
            proto.setExpirationTimer(0)
            proto.setExpirationType(.unknown)
            return
        }
        
        if let expiresStartedAtMs = self.expiresStartedAtMs, UInt64(expiresStartedAtMs) == self.sentTimestamp {
            proto.setExpirationType(.deleteAfterSend)
        } else {
            proto.setExpirationType(.deleteAfterRead)
        }
    }
    
    public func attachDisappearingMessagesConfiguration(from proto: SNProtoContent) {
        let expiresInSeconds: TimeInterval? = proto.hasExpirationTimer ? TimeInterval(proto.expirationTimer) : nil
        let expiresStartedAtMs: Double? = {
            if proto.expirationType == .deleteAfterSend, let timestamp = self.sentTimestamp {
                return Double(timestamp)
            }
            return nil
        }()
        
        self.expiresInSeconds = expiresInSeconds
        self.expiresStartedAtMs = expiresStartedAtMs
    }
}

// MARK: - Message Parsing/Processing

public typealias ProcessedMessage = (
    threadId: String,
    threadVariant: SessionThread.Variant,
    proto: SNProtoContent,
    messageInfo: MessageReceiveJob.Details.MessageInfo
)

public extension Message {
    enum Variant: String, Codable {
        case readReceipt
        case typingIndicator
        case closedGroupControlMessage
        case dataExtractionNotification
        case expirationTimerUpdate
        case configurationMessage
        case unsendRequest
        case messageRequestResponse
        case visibleMessage
        case callMessage
        case sharedConfigMessage
        
        init?(from type: Message) {
            switch type {
                case is ReadReceipt: self = .readReceipt
                case is TypingIndicator: self = .typingIndicator
                case is ClosedGroupControlMessage: self = .closedGroupControlMessage
                case is DataExtractionNotification: self = .dataExtractionNotification
                case is ExpirationTimerUpdate: self = .expirationTimerUpdate
                case is ConfigurationMessage: self = .configurationMessage
                case is UnsendRequest: self = .unsendRequest
                case is MessageRequestResponse: self = .messageRequestResponse
                case is VisibleMessage: self = .visibleMessage
                case is CallMessage: self = .callMessage
                case is SharedConfigMessage: self = .sharedConfigMessage
                default: return nil
            }
        }
        
        var messageType: Message.Type {
            switch self {
                case .readReceipt: return ReadReceipt.self
                case .typingIndicator: return TypingIndicator.self
                case .closedGroupControlMessage: return ClosedGroupControlMessage.self
                case .dataExtractionNotification: return DataExtractionNotification.self
                case .expirationTimerUpdate: return ExpirationTimerUpdate.self
                case .configurationMessage: return ConfigurationMessage.self
                case .unsendRequest: return UnsendRequest.self
                case .messageRequestResponse: return MessageRequestResponse.self
                case .visibleMessage: return VisibleMessage.self
                case .callMessage: return CallMessage.self
                case .sharedConfigMessage: return SharedConfigMessage.self
            }
        }

        func decode<CodingKeys: CodingKey>(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Message {
            switch self {
                case .readReceipt: return try container.decode(ReadReceipt.self, forKey: key)
                case .typingIndicator: return try container.decode(TypingIndicator.self, forKey: key)
                
                case .closedGroupControlMessage:
                    return try container.decode(ClosedGroupControlMessage.self, forKey: key)
                    
                case .dataExtractionNotification:
                    return try container.decode(DataExtractionNotification.self, forKey: key)
                    
                case .expirationTimerUpdate: return try container.decode(ExpirationTimerUpdate.self, forKey: key)
                case .configurationMessage: return try container.decode(ConfigurationMessage.self, forKey: key)
                case .unsendRequest: return try container.decode(UnsendRequest.self, forKey: key)
                case .messageRequestResponse: return try container.decode(MessageRequestResponse.self, forKey: key)
                case .visibleMessage: return try container.decode(VisibleMessage.self, forKey: key)
                case .callMessage: return try container.decode(CallMessage.self, forKey: key)
                case .sharedConfigMessage: return try container.decode(SharedConfigMessage.self, forKey: key)
            }
        }
    }
    
    static func createMessageFrom(_ proto: SNProtoContent, sender: String) -> Message? {
        // Note: This array is ordered intentionally to ensure the correct types are processed
        // and aren't parsed as the wrong type
        let prioritisedVariants: [Variant] = [
            .readReceipt,
            .typingIndicator,
            .closedGroupControlMessage,
            .dataExtractionNotification,
            .expirationTimerUpdate,
            .configurationMessage,
            .unsendRequest,
            .messageRequestResponse,
            .visibleMessage,
            .callMessage,
            .sharedConfigMessage
        ]
        
        return prioritisedVariants
            .reduce(nil) { prev, variant in
                guard prev == nil else { return prev }
                
                return variant.messageType.fromProto(proto, sender: sender)
            }
    }
    
    static func requiresExistingConversation(message: Message, threadVariant: SessionThread.Variant) -> Bool {
        switch threadVariant {
            case .contact, .community: return false
                
            case .legacyGroup:
                switch message {
                    case let controlMessage as ClosedGroupControlMessage:
                        switch controlMessage.kind {
                            case .new: return false
                            default: return true
                        }
                        
                    default: return true
                }
                
            case .group:
                return false
        }
    }
    
    static func shouldSync(message: Message) -> Bool {
        switch message {
            case is VisibleMessage: return true
            case is ExpirationTimerUpdate: return true
            case is ConfigurationMessage: return true
            case is UnsendRequest: return true
            
            case let controlMessage as ClosedGroupControlMessage:
                switch controlMessage.kind {
                    case .new: return true
                    default: return false
                }
                
            case let callMessage as CallMessage:
                switch callMessage.kind {
                    case .answer, .endCall: return true
                    default: return false
                }
            
            default: return false
        }
    }
    
    static func threadId(forMessage message: Message, destination: Message.Destination) -> String {
        switch destination {
            case .contact(let publicKey):
                // Extract the 'syncTarget' value if there is one
                let maybeSyncTarget: String?
                
                switch message {
                    case let message as VisibleMessage: maybeSyncTarget = message.syncTarget
                    case let message as ExpirationTimerUpdate: maybeSyncTarget = message.syncTarget
                    default: maybeSyncTarget = nil
                }
                
                return (maybeSyncTarget ?? publicKey)
                
            case .closedGroup(let groupPublicKey): return groupPublicKey
            case .openGroup(let roomToken, let server, _, _, _):
                return OpenGroup.idFor(roomToken: roomToken, server: server)
            
            case .openGroupInbox(_, _, let blindedPublicKey): return blindedPublicKey
        }
    }
    
    static func processRawReceivedMessage(
        _ db: Database,
        rawMessage: SnodeReceivedMessage,
        using dependencies: Dependencies = Dependencies()
    ) throws -> ProcessedMessage? {
        guard let envelope = SNProtoEnvelope.from(rawMessage) else {
            throw MessageReceiverError.invalidMessage
        }
        
        do {
            let processedMessage: ProcessedMessage? = try processRawReceivedMessage(
                db,
                envelope: envelope,
                serverExpirationTimestamp: (TimeInterval(rawMessage.info.expirationDateMs) / 1000),
                serverHash: rawMessage.info.hash,
                handleClosedGroupKeyUpdateMessages: true,
                using: dependencies
            )
            
            // Ensure we actually want to de-dupe messages for this namespace, otherwise just
            // succeed early
            guard rawMessage.namespace.shouldDedupeMessages else {
                // If we want to track the last hash then upsert the raw message info (don't
                // want to fail if it already exsits because we don't want to dedupe messages
                // in this namespace)
                if rawMessage.namespace.shouldFetchSinceLastHash {
                    _ = try rawMessage.info.saved(db)
                }
                
                return processedMessage
            }
            
            // Retrieve the number of entries we have for the hash of this message
            let numExistingHashes: Int = (try? SnodeReceivedMessageInfo
                .filter(SnodeReceivedMessageInfo.Columns.hash == rawMessage.info.hash)
                .fetchCount(db))
                .defaulting(to: 0)
            
            // Try to insert the raw message info into the database (used for both request paging and
            // de-duping purposes)
            _ = try rawMessage.info.inserted(db)
            
            // If the above insertion worked then we hadn't processed this message for this specific
            // service node, but may have done so for another node - if the hash already existed in
            // the database before we inserted it for this node then we can ignore this message as a
            // duplicate
            guard numExistingHashes == 0 else { throw MessageReceiverError.duplicateMessageNewSnode }
            
            return processedMessage
        }
        catch {
            // For some error cases we want to update the last hash so do so
            if (error as? MessageReceiverError)?.shouldUpdateLastHash == true {
                _ = try? rawMessage.info.inserted(db)
            }
            
            throw error
        }
    }
    
    static func processRawReceivedMessage(
        _ db: Database,
        serializedData: Data,
        serverHash: String?,
        using dependencies: Dependencies = Dependencies()
    ) throws -> ProcessedMessage? {
        guard let envelope = try? SNProtoEnvelope.parseData(serializedData) else {
            throw MessageReceiverError.invalidMessage
        }
        
        return try processRawReceivedMessage(
            db,
            envelope: envelope,
            serverExpirationTimestamp: (
                (TimeInterval(SnodeAPI.currentOffsetTimestampMs()) / 1000) +
                ControlMessageProcessRecord.defaultExpirationSeconds
            ),
            serverHash: serverHash,
            handleClosedGroupKeyUpdateMessages: true,
            using: dependencies
        )
    }
    
    /// This method behaves slightly differently from the other `processRawReceivedMessage` methods as it doesn't
    /// insert the "message info" for deduping (we want the poller to re-process the message) and also avoids handling any
    /// closed group key update messages (the `NotificationServiceExtension` does this itself)
    static func processRawReceivedMessageAsNotification(
        _ db: Database,
        envelope: SNProtoEnvelope,
        using dependencies: Dependencies = Dependencies()
    ) throws -> ProcessedMessage? {
        let processedMessage: ProcessedMessage? = try processRawReceivedMessage(
            db,
            envelope: envelope,
            serverExpirationTimestamp: (
                (TimeInterval(SnodeAPI.currentOffsetTimestampMs()) / 1000) +
                ControlMessageProcessRecord.defaultExpirationSeconds
            ),
            serverHash: nil,
            handleClosedGroupKeyUpdateMessages: false,
            using: dependencies
        )
        
        return processedMessage
    }
    
    static func processReceivedOpenGroupMessage(
        _ db: Database,
        openGroupId: String,
        openGroupServerPublicKey: String,
        message: OpenGroupAPI.Message,
        data: Data,
        using dependencies: Dependencies = Dependencies()
    ) throws -> ProcessedMessage? {
        // Need a sender in order to process the message
        guard let sender: String = message.sender, let timestamp = message.posted else { return nil }
        
        // Note: The `posted` value is in seconds but all messages in the database use milliseconds for timestamps
        let envelopeBuilder = SNProtoEnvelope.builder(type: .sessionMessage, timestamp: UInt64(floor(timestamp * 1000)))
        envelopeBuilder.setContent(data)
        envelopeBuilder.setSource(sender)
        
        guard let envelope = try? envelopeBuilder.build() else {
            throw MessageReceiverError.invalidMessage
        }
        
        return try processRawReceivedMessage(
            db,
            envelope: envelope,
            serverExpirationTimestamp: nil,
            serverHash: nil,
            openGroupId: openGroupId,
            openGroupMessageServerId: message.id,
            openGroupServerPublicKey: openGroupServerPublicKey,
            handleClosedGroupKeyUpdateMessages: false,
            using: dependencies
        )
    }
    
    static func processReceivedOpenGroupDirectMessage(
        _ db: Database,
        openGroupServerPublicKey: String,
        message: OpenGroupAPI.DirectMessage,
        data: Data,
        isOutgoing: Bool? = nil,
        otherBlindedPublicKey: String? = nil,
        using dependencies: Dependencies = Dependencies()
    ) throws -> ProcessedMessage? {
        // Note: The `posted` value is in seconds but all messages in the database use milliseconds for timestamps
        let envelopeBuilder = SNProtoEnvelope.builder(type: .sessionMessage, timestamp: UInt64(floor(message.posted * 1000)))
        envelopeBuilder.setContent(data)
        envelopeBuilder.setSource(message.sender)
        
        guard let envelope = try? envelopeBuilder.build() else {
            throw MessageReceiverError.invalidMessage
        }
        
        return try processRawReceivedMessage(
            db,
            envelope: envelope,
            serverExpirationTimestamp: nil,
            serverHash: nil,
            openGroupId: nil,   // Explicitly null since it shouldn't be handled as an open group message
            openGroupMessageServerId: message.id,
            openGroupServerPublicKey: openGroupServerPublicKey,
            isOutgoing: isOutgoing,
            otherBlindedPublicKey: otherBlindedPublicKey,
            handleClosedGroupKeyUpdateMessages: false,
            using: dependencies
        )
    }
    
    static func processRawReceivedReactions(
        _ db: Database,
        openGroupId: String,
        message: OpenGroupAPI.Message,
        associatedPendingChanges: [OpenGroupAPI.PendingChange],
        using dependencies: Dependencies = Dependencies()
    ) -> [Reaction] {
        var results: [Reaction] = []
        guard let reactions = message.reactions else { return results }
        let userPublicKey: String = getUserHexEncodedPublicKey(db, using: dependencies)
        let blinded15UserPublicKey: String? = SessionThread
            .getUserHexEncodedBlindedKey(
                db,
                threadId: openGroupId,
                threadVariant: .community,
                blindingPrefix: .blinded15,
                using: dependencies
            )
        let blinded25UserPublicKey: String? = SessionThread
            .getUserHexEncodedBlindedKey(
                db,
                threadId: openGroupId,
                threadVariant: .community,
                blindingPrefix: .blinded25,
                using: dependencies
            )
        
        for (encodedEmoji, rawReaction) in reactions {
            if let decodedEmoji = encodedEmoji.removingPercentEncoding,
               rawReaction.count > 0,
               let reactors = rawReaction.reactors
            {
                // Decide whether we need to ignore all reactions
                let pendingChangeRemoveAllReaction: Bool = associatedPendingChanges.contains { pendingChange in
                    if case .reaction(_, let emoji, let action) = pendingChange.metadata {
                        return emoji == decodedEmoji && action == .removeAll
                    }
                    return false
                }
                
                // Decide whether we need to add an extra reaction from current user
                let pendingChangeSelfReaction: Bool? = {
                    // Find the newest 'PendingChange' entry with a matching emoji, if one exists, and
                    // set the "self reaction" value based on it's action
                    let maybePendingChange: OpenGroupAPI.PendingChange? = associatedPendingChanges
                        .sorted(by: { lhs, rhs -> Bool in (lhs.seqNo ?? Int64.max) >= (rhs.seqNo ?? Int64.max) })
                        .first { pendingChange in
                            if case .reaction(_, let emoji, _) = pendingChange.metadata {
                                return emoji == decodedEmoji
                            }
                            
                            return false
                        }
                    
                    // If there is no pending change for this reaction then return nil
                    guard
                        let pendingChange: OpenGroupAPI.PendingChange = maybePendingChange,
                        case .reaction(_, _, let action) = pendingChange.metadata
                    else { return nil }

                    // Otherwise add/remove accordingly
                    return action == .add
                }()
                let shouldAddSelfReaction: Bool = (
                    pendingChangeSelfReaction ??
                    ((rawReaction.you || reactors.contains(userPublicKey)) && !pendingChangeRemoveAllReaction)
                )
                
                let count: Int64 = rawReaction.you ? rawReaction.count - 1 : rawReaction.count
                
                let timestampMs: Int64 = SnodeAPI.currentOffsetTimestampMs()
                let maxLength: Int = shouldAddSelfReaction ? 4 : 5
                let desiredReactorIds: [String] = reactors
                    .filter { id -> Bool in
                        id != blinded15UserPublicKey &&
                        id != blinded25UserPublicKey &&
                        id != userPublicKey
                    } // Remove current user for now, will add back if needed
                    .prefix(maxLength)
                    .map{ $0 }

                results = results
                    .appending( // Add the first reaction (with the count)
                        pendingChangeRemoveAllReaction ?
                        nil :
                        desiredReactorIds.first
                            .map { reactor in
                                Reaction(
                                    interactionId: message.id,
                                    serverHash: nil,
                                    timestampMs: timestampMs,
                                    authorId: reactor,
                                    emoji: decodedEmoji,
                                    count: count,
                                    sortId: rawReaction.index
                                )
                            }
                    )
                    .appending( // Add all other reactions
                        contentsOf: desiredReactorIds.count <= 1 || pendingChangeRemoveAllReaction ?
                            [] :
                            desiredReactorIds
                                .suffix(from: 1)
                                .map { reactor in
                                    Reaction(
                                        interactionId: message.id,
                                        serverHash: nil,
                                        timestampMs: timestampMs,
                                        authorId: reactor,
                                        emoji: decodedEmoji,
                                        count: 0,   // Only want this on the first reaction
                                        sortId: rawReaction.index
                                    )
                                }
                    )
                    .appending( // Add the current user reaction (if applicable and not already included)
                        !shouldAddSelfReaction ?
                            nil :
                            Reaction(
                                interactionId: message.id,
                                serverHash: nil,
                                timestampMs: timestampMs,
                                authorId: userPublicKey,
                                emoji: decodedEmoji,
                                count: 1,
                                sortId: rawReaction.index
                            )
                    )
            }
        }
        return results
    }
    
    private static func processRawReceivedMessage(
        _ db: Database,
        envelope: SNProtoEnvelope,
        serverExpirationTimestamp: TimeInterval?,
        serverHash: String?,
        openGroupId: String? = nil,
        openGroupMessageServerId: Int64? = nil,
        openGroupServerPublicKey: String? = nil,
        isOutgoing: Bool? = nil,
        otherBlindedPublicKey: String? = nil,
        handleClosedGroupKeyUpdateMessages: Bool,
        using dependencies: Dependencies
    ) throws -> ProcessedMessage? {
        let (message, proto, threadId, threadVariant) = try MessageReceiver.parse(
            db,
            envelope: envelope,
            serverExpirationTimestamp: serverExpirationTimestamp,
            openGroupId: openGroupId,
            openGroupMessageServerId: openGroupMessageServerId,
            openGroupServerPublicKey: openGroupServerPublicKey,
            isOutgoing: isOutgoing,
            otherBlindedPublicKey: otherBlindedPublicKey,
            using: dependencies
        )
        message.serverHash = serverHash
        
        // Ignore invalid messages and hashes for messages we have previously handled
        guard let variant: Message.Variant = Message.Variant(from: message) else {
            throw MessageReceiverError.invalidMessage
        }
        
        /// **Note:** We want to immediately handle any `ClosedGroupControlMessage` with the kind `encryptionKeyPair` as
        /// we need the keyPair in storage in order to be able to parse and messages which were signed with the new key (also no need to add
        /// these as jobs as they will be fully handled in here)
        if handleClosedGroupKeyUpdateMessages {
            switch message {
                case let closedGroupControlMessage as ClosedGroupControlMessage:
                    switch closedGroupControlMessage.kind {
                        case .encryptionKeyPair:
                            try MessageReceiver.handleClosedGroupControlMessage(
                                db,
                                threadId: threadId,
                                threadVariant: threadVariant,
                                message: closedGroupControlMessage,
                                using: dependencies
                            )
                            return nil
                            
                        default: break
                    }
                
                default: break
            }
        }
        
        // Prevent ControlMessages from being handled multiple times if not supported
        do {
            try ControlMessageProcessRecord(
                threadId: threadId,
                message: message,
                serverExpirationTimestamp: serverExpirationTimestamp
            )?.insert(db)
        }
        catch {
            // We want to custom handle this 
            if case DatabaseError.SQLITE_CONSTRAINT_UNIQUE = error {
                throw MessageReceiverError.duplicateControlMessage
            }
            
            throw error
        }
        
        return (
            threadId,
            threadVariant,
            proto,
            try MessageReceiveJob.Details.MessageInfo(
                message: message,
                variant: variant,
                threadVariant: threadVariant,
                serverExpirationTimestamp: serverExpirationTimestamp,
                proto: proto
            )
        )
    }
    
    // MARK: - TTL for disappearing messages
    
    internal static func getSpecifiedTTL(
        message: Message,
        isGroupMessage: Bool,
        isSyncMessage: Bool
    ) -> UInt64 {
        guard Features.useNewDisappearingMessagesConfig else { return message.ttl }
        // Not disappearing messages
        guard let expiresInSeconds = message.expiresInSeconds else { return message.ttl }
        
        // Sync message should be read already, it is the same for disappear after read and disappear after sent
        guard !isSyncMessage else { return UInt64(expiresInSeconds * 1000) }
        
        // Disappear after read messages that have not be read
        guard let expiresStartedAtMs = message.expiresStartedAtMs else { return message.ttl }
        
        // Disappear after read messages that have already be read
        guard message.sentTimestamp == UInt64(expiresStartedAtMs) else { return message.ttl }
        
        // Disappear after sent messages with exceptions
        switch message {
            case is ClosedGroupControlMessage, is UnsendRequest:
                return message.ttl
            case is ExpirationTimerUpdate:
                return isGroupMessage ? message.ttl : UInt64(expiresInSeconds * 1000)
            default:
                return UInt64(expiresInSeconds * 1000)
        }
    }
}

// MARK: - Mutation

public extension Message {
    func with(sentTimestamp: UInt64) -> Self {
        self.sentTimestamp = sentTimestamp
        return self
    }
    
    func with(_ disappearingMessagesConfiguration: DisappearingMessagesConfiguration?) -> Self {
        self.expiresInSeconds = disappearingMessagesConfiguration?.durationSeconds
        if disappearingMessagesConfiguration?.type == .disappearAfterSend, let sentTimestamp = self.sentTimestamp {
            self.expiresStartedAtMs =  Double(sentTimestamp)
        }
        return self
    }
    
    func with(
        expiresInSeconds: TimeInterval?,
        expiresStartedAtMs: Double? = nil
    ) -> Self {
        self.expiresInSeconds = expiresInSeconds
        self.expiresStartedAtMs = expiresStartedAtMs
        return self
    }
}

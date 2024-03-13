// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import GRDB
import SessionUtilitiesKit

public enum MessageReceiveJob: JobExecutor {
    public static var maxFailureCount: Int = 10
    public static var requiresThreadId: Bool = true
    public static let requiresInteractionId: Bool = false
    
    public static func run(
        _ job: Job,
        queue: DispatchQueue,
        success: @escaping (Job, Bool, Dependencies) -> (),
        failure: @escaping (Job, Error?, Bool, Dependencies) -> (),
        deferred: @escaping (Job, Dependencies) -> (),
        using dependencies: Dependencies = Dependencies()
    ) {
        guard
            let threadId: String = job.threadId,
            let detailsData: Data = job.details,
            let details: Details = try? JSONDecoder().decode(Details.self, from: detailsData)
        else {
            return failure(job, JobRunnerError.missingRequiredDetails, true, dependencies)
        }
        
        // Ensure no config messages are sent through this job
        guard !details.messages.contains(where: { $0.variant == .sharedConfigMessage }) else {
            SNLog("[MessageReceiveJob] Config messages incorrectly sent to the 'messageReceive' job")
            return failure(job, MessageReceiverError.invalidSharedConfigMessageHandling, true, dependencies)
        }
        
        var updatedJob: Job = job
        var lastError: Error?
        var remainingMessagesToProcess: [Details.MessageInfo] = []
        let messageData: [(info: Details.MessageInfo, proto: SNProtoContent)] = details.messages
            .filter { $0.variant != .sharedConfigMessage }
            .compactMap { messageInfo -> (info: Details.MessageInfo, proto: SNProtoContent)? in
                do {
                    return (messageInfo, try SNProtoContent.parseData(messageInfo.serializedProtoData))
                }
                catch {
                    SNLog("Couldn't receive message due to error: \(error)")
                    lastError = error
                    
                    // We failed to process this message but it is a retryable error
                    // so add it to the list to re-process
                    remainingMessagesToProcess.append(messageInfo)
                    return nil
                }
            }
        
        dependencies.storage.write { db in
            for (messageInfo, protoContent) in messageData {
                do {
                    try MessageReceiver.handle(
                        db,
                        threadId: threadId,
                        threadVariant: messageInfo.threadVariant,
                        message: messageInfo.message,
                        serverExpirationTimestamp: messageInfo.serverExpirationTimestamp,
                        associatedWithProto: protoContent
                    )
                }
                catch {
                    // If the current message is a permanent failure then override it with the
                    // new error (we want to retry if there is a single non-permanent error)
                    switch error {
                        // Ignore duplicate and self-send errors (these will usually be caught during
                        // parsing but sometimes can get past and conflict at database insertion - eg.
                        // for open group messages) we also don't bother logging as it results in
                        // excessive logging which isn't useful)
                        case DatabaseError.SQLITE_CONSTRAINT_UNIQUE,
                            MessageReceiverError.duplicateMessage,
                            MessageReceiverError.duplicateControlMessage,
                            MessageReceiverError.selfSend:
                            break
                        
                        case let receiverError as MessageReceiverError where !receiverError.isRetryable:
                            SNLog("MessageReceiveJob permanently failed message due to error: \(error)")
                            continue
                        
                        default:
                            SNLog("Couldn't receive message due to error: \(error)")
                            lastError = error
                            
                            // We failed to process this message but it is a retryable error
                            // so add it to the list to re-process
                            remainingMessagesToProcess.append(messageInfo)
                    }
                }
            }
            
            // If any messages failed to process then we want to update the job to only include
            // those failed messages
            guard !remainingMessagesToProcess.isEmpty else { return }
            
            updatedJob = try job
                .with(
                    details: Details(
                        messages: remainingMessagesToProcess,
                        calledFromBackgroundPoller: details.calledFromBackgroundPoller
                    )
                )
                .defaulting(to: job)
                .saved(db)
        }
        
        // Handle the result
        switch lastError {
            case let error as MessageReceiverError where !error.isRetryable:
                failure(updatedJob, error, true, dependencies)
                
            case .some(let error):
                failure(updatedJob, error, false, dependencies)
                
            case .none:
                success(updatedJob, false, dependencies)
        }
    }
}

// MARK: - MessageReceiveJob.Details

extension MessageReceiveJob {
    public struct Details: Codable {
        typealias SharedConfigInfo = (message: SharedConfigMessage, serializedProtoData: Data)
        
        public struct MessageInfo: Codable {
            private enum CodingKeys: String, CodingKey {
                case message
                case variant
                case threadVariant
                case serverExpirationTimestamp
                case serializedProtoData
            }
            
            public let message: Message
            public let variant: Message.Variant
            public let threadVariant: SessionThread.Variant
            public let serverExpirationTimestamp: TimeInterval?
            public let serializedProtoData: Data
            
            public init(
                message: Message,
                variant: Message.Variant,
                threadVariant: SessionThread.Variant,
                serverExpirationTimestamp: TimeInterval?,
                proto: SNProtoContent
            ) throws {
                self.message = message
                self.variant = variant
                self.threadVariant = threadVariant
                self.serverExpirationTimestamp = serverExpirationTimestamp
                self.serializedProtoData = try proto.serializedData()
            }
            
            private init(
                message: Message,
                variant: Message.Variant,
                threadVariant: SessionThread.Variant,
                serverExpirationTimestamp: TimeInterval?,
                serializedProtoData: Data
            ) {
                self.message = message
                self.variant = variant
                self.threadVariant = threadVariant
                self.serverExpirationTimestamp = serverExpirationTimestamp
                self.serializedProtoData = serializedProtoData
            }
            
            // MARK: - Codable
            
            public init(from decoder: Decoder) throws {
                let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
                
                guard let variant: Message.Variant = try? container.decode(Message.Variant.self, forKey: .variant) else {
                    SNLog("Unable to decode messageReceive job due to missing variant")
                    throw StorageError.decodingFailed
                }
                
                self = MessageInfo(
                    message: try variant.decode(from: container, forKey: .message),
                    variant: variant,
                    threadVariant: (try? container.decode(SessionThread.Variant.self, forKey: .threadVariant))
                        .defaulting(to: {
                            /// We used to store a 'groupPublicKey' value within the 'Message' type which was used to
                            /// determine the thread variant, now we just encode the variant directly but there may be
                            /// some legacy jobs which still have `groupPublicKey` so we have this mechanism
                            ///
                            /// **Note:** This can probably be removed a couple of releases after the user config
                            /// update release (ie. after June 2023)
                            class LegacyGroupPubkey: Codable {
                                let groupPublicKey: String?
                            }
                            
                            if (try? container.decode(LegacyGroupPubkey.self, forKey: .message))?.groupPublicKey != nil {
                                return .legacyGroup
                            }
                            
                            return .contact
                        }()),
                    serverExpirationTimestamp: try? container.decode(TimeInterval.self, forKey: .serverExpirationTimestamp),
                    serializedProtoData: try container.decode(Data.self, forKey: .serializedProtoData)
                )
            }
            
            public func encode(to encoder: Encoder) throws {
                var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)
                
                guard let variant: Message.Variant = Message.Variant(from: message) else {
                    SNLog("Unable to encode messageReceive job due to unsupported variant")
                    throw StorageError.objectNotFound
                }

                try container.encode(message, forKey: .message)
                try container.encode(variant, forKey: .variant)
                try container.encode(threadVariant, forKey: .threadVariant)
                try container.encodeIfPresent(serverExpirationTimestamp, forKey: .serverExpirationTimestamp)
                try container.encode(serializedProtoData, forKey: .serializedProtoData)
            }
        }
        
        public let messages: [MessageInfo]
        private let isBackgroundPoll: Bool
        
        // Renamed variable for clarity (and didn't want to migrate old MessageReceiveJob
        // values so didn't rename the original)
        public var calledFromBackgroundPoller: Bool { isBackgroundPoll }
        
        public init(
            messages: [MessageInfo],
            calledFromBackgroundPoller: Bool
        ) {
            self.messages = messages
            self.isBackgroundPoll = calledFromBackgroundPoller
        }
    }
}

// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import GRDB
import SessionSnodeKit
import SessionUtilitiesKit

public extension Message {
    enum Destination: Codable, Hashable {
        case contact(publicKey: String)
        case closedGroup(groupPublicKey: String)
        case openGroup(
            roomToken: String,
            server: String,
            whisperTo: String? = nil,
            whisperMods: Bool = false,
            fileIds: [String]? = nil
        )
        case openGroupInbox(server: String, openGroupPublicKey: String, blindedPublicKey: String)
        
        public var defaultNamespace: SnodeAPI.Namespace? {
            switch self {
                case .contact: return .`default`
                case .closedGroup: return .legacyClosedGroup
                default: return nil
            }
        }
        
        public static func from(
            _ db: Database,
            threadId: String,
            threadVariant: SessionThread.Variant,
            fileIds: [String]? = nil
        ) throws -> Message.Destination {
            switch threadVariant {
                case .contact:
                    let prefix: SessionId.Prefix? = SessionId.Prefix(from: threadId)
                    
                    if prefix == .blinded15 || prefix == .blinded25 {
                        guard let lookup: BlindedIdLookup = try? BlindedIdLookup.fetchOne(db, id: threadId) else {
                            preconditionFailure("Attempting to send message to blinded id without the Open Group information")
                        }
                        
                        return .openGroupInbox(
                            server: lookup.openGroupServer,
                            openGroupPublicKey: lookup.openGroupPublicKey,
                            blindedPublicKey: threadId
                        )
                    }
                    
                    return .contact(publicKey: threadId)
                
                case .legacyGroup, .group:
                    return .closedGroup(groupPublicKey: threadId)
                
                case .community:
                    guard let openGroup: OpenGroup = try OpenGroup.fetchOne(db, id: threadId) else {
                        throw StorageError.objectNotFound
                    }
                    
                    return .openGroup(roomToken: openGroup.roomToken, server: openGroup.server, fileIds: fileIds)
            }
        }
        
        func with(fileIds: [String]) -> Message.Destination {
            // Only Open Group messages support receiving the 'fileIds'
            switch self {
                case .openGroup(let roomToken, let server, let whisperTo, let whisperMods, _):
                    return .openGroup(
                        roomToken: roomToken,
                        server: server,
                        whisperTo: whisperTo,
                        whisperMods: whisperMods,
                        fileIds: fileIds
                    )
                    
                default: return self
            }
        }
    }
}

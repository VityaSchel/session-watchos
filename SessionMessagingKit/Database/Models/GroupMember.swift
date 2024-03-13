// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import GRDB
import SessionUtilitiesKit

public struct GroupMember: Codable, Equatable, Hashable, FetchableRecord, PersistableRecord, TableRecord, ColumnExpressible {
    public static var databaseTableName: String { "groupMember" }
    internal static let openGroupForeignKey = ForeignKey([Columns.groupId], to: [OpenGroup.Columns.threadId])
    internal static let closedGroupForeignKey = ForeignKey([Columns.groupId], to: [ClosedGroup.Columns.threadId])
    public static let openGroup = belongsTo(OpenGroup.self, using: openGroupForeignKey)
    public static let closedGroup = belongsTo(ClosedGroup.self, using: closedGroupForeignKey)
    public static let profile = hasOne(Profile.self, using: Profile.groupMemberForeignKey)
    
    public typealias Columns = CodingKeys
    public enum CodingKeys: String, CodingKey, ColumnExpression {
        case groupId
        case profileId
        case role
        case isHidden
    }
    
    public enum Role: Int, Codable, DatabaseValueConvertible {
        case standard
        case zombie
        case moderator
        case admin
    }

    public let groupId: String
    public let profileId: String
    public let role: Role
    public let isHidden: Bool
    
    // MARK: - Relationships
    
    public var openGroup: QueryInterfaceRequest<OpenGroup> {
        request(for: GroupMember.openGroup)
    }
    
    public var closedGroup: QueryInterfaceRequest<ClosedGroup> {
        request(for: GroupMember.closedGroup)
    }
    
    public var profile: QueryInterfaceRequest<Profile> {
        request(for: GroupMember.profile)
    }
    
    // MARK: - Initialization
    
    public init(
        groupId: String,
        profileId: String,
        role: Role,
        isHidden: Bool
    ) {
        self.groupId = groupId
        self.profileId = profileId
        self.role = role
        self.isHidden = isHidden
    }
}

// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import GRDB
import SessionUtilitiesKit
import SessionSnodeKit

/// This migration removes the legacy YapDatabase files
enum _004_RemoveLegacyYDB: Migration {
    static let target: TargetMigrations.Identifier = .messagingKit
    static let identifier: String = "RemoveLegacyYDB" // stringlint:disable
    static let needsConfigSync: Bool = false
    static let minExpectedRunDuration: TimeInterval = 0.1
    static let fetchedTables: [(TableRecord & FetchableRecord).Type] = []
    static let createdOrAlteredTables: [(TableRecord & FetchableRecord).Type] = []

    static func migrate(_ db: Database) throws {
        try? SUKLegacy.deleteLegacyDatabaseFilesAndKey()
        Storage.update(progress: 1, for: self, in: target) // In case this is the last migration
    }
}

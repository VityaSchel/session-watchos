// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import Combine
import GRDB
import Sodium
import SessionSnodeKit
import SessionUtilitiesKit

public final class CurrentUserPoller: Poller {
    public static var namespaces: [SnodeAPI.Namespace] = [
        .default, .configUserProfile, .configContacts, .configConvoInfoVolatile, .configUserGroups
    ]

    // MARK: - Settings
    
    override var namespaces: [SnodeAPI.Namespace] { CurrentUserPoller.namespaces }
    
    /// After polling a given snode this many times we always switch to a new one.
    ///
    /// The reason for doing this is that sometimes a snode will be giving us successful responses while
    /// it isn't actually getting messages from other snodes.
    override var maxNodePollCount: UInt { 6 }
    
    private let pollInterval: TimeInterval = 1.5
    private let retryInterval: TimeInterval = 0.25
    private let maxRetryInterval: TimeInterval = 15
    
    // MARK: - Convenience Functions
    
    public func start(using dependencies: Dependencies = Dependencies()) {
        let publicKey: String = getUserHexEncodedPublicKey(using: dependencies)
        
        guard isPolling.wrappedValue[publicKey] != true else { return }
        
        SNLog("Started polling.")
        super.startIfNeeded(for: publicKey, using: dependencies)
    }
    
    public func stop() {
        SNLog("Stopped polling.")
        super.stopAllPollers()
    }
    
    // MARK: - Abstract Methods
    
    override func pollerName(for publicKey: String) -> String {
        return "Main Poller"
    }
    
    override func nextPollDelay(for publicKey: String, using dependencies: Dependencies) -> TimeInterval {
        let failureCount: TimeInterval = TimeInterval(failureCount.wrappedValue[publicKey] ?? 0)
        
        // If there have been no failures then just use the 'minPollInterval'
        guard failureCount > 0 else { return pollInterval }
        
        // Otherwise use a simple back-off with the 'retryInterval'
        let nextDelay: TimeInterval = (retryInterval * (failureCount * 1.2))
                                       
        return min(maxRetryInterval, nextDelay)
    }
    
    override func handlePollError(_ error: Error, for publicKey: String, using dependencies: Dependencies) -> Bool {
        if UserDefaults.sharedLokiProject?[.isMainAppActive] != true {
            // Do nothing when an error gets throws right after returning from the background (happens frequently)
        }
        else if let targetSnode: Snode = targetSnode.wrappedValue {
            SNLog("Main Poller polling \(targetSnode) failed; dropping it and switching to next snode.")
            self.targetSnode.mutate { $0 = nil }
            SnodeAPI.dropSnodeFromSwarmIfNeeded(targetSnode, publicKey: publicKey)
        }
        else {
            SNLog("Polling failed due to having no target service node.")
        }
        
        return true
    }
}

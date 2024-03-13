// Copyright © 2022 Rangeproof Pty Ltd. All rights reserved.

import Foundation
import GRDB
import SessionUtilitiesKit

public enum UpdateProfilePictureJob: JobExecutor {
    public static let maxFailureCount: Int = -1
    public static let requiresThreadId: Bool = false
    public static let requiresInteractionId: Bool = false
    
    public static func run(
        _ job: Job,
        queue: DispatchQueue,
        success: @escaping (Job, Bool, Dependencies) -> (),
        failure: @escaping (Job, Error?, Bool, Dependencies) -> (),
        deferred: @escaping (Job, Dependencies) -> (),
        using dependencies: Dependencies
    ) {
        // Don't run when inactive or not in main app
        guard (UserDefaults.sharedLokiProject?[.isMainAppActive]).defaulting(to: false) else {
            return deferred(job, dependencies) // Don't need to do anything if it's not the main app
        }
        
        // Only re-upload the profile picture if enough time has passed since the last upload
        guard
            let lastProfilePictureUpload: Date = dependencies.standardUserDefaults[.lastProfilePictureUpload],
            dependencies.dateNow.timeIntervalSince(lastProfilePictureUpload) > (14 * 24 * 60 * 60)
        else {
            // Reset the `nextRunTimestamp` value just in case the last run failed so we don't get stuck
            // in a loop endlessly deferring the job
            if let jobId: Int64 = job.id {
                dependencies.storage.write { db in
                    try Job
                        .filter(id: jobId)
                        .updateAll(db, Job.Columns.nextRunTimestamp.set(to: 0))
                }
            }

            SNLog("[UpdateProfilePictureJob] Deferred as not enough time has passed since the last update")
            return deferred(job, dependencies)
        }
        
        // Note: The user defaults flag is updated in ProfileManager
        let profile: Profile = Profile.fetchOrCreateCurrentUser(using: dependencies)
        let profilePictureData: Data? = profile.profilePictureFileName
            .map { ProfileManager.loadProfileData(with: $0) }
        
        ProfileManager.updateLocal(
            queue: queue,
            profileName: profile.name,
            avatarUpdate: (profilePictureData.map { .uploadImageData($0) } ?? .none),
            success: { db in
                // Need to call the 'success' closure asynchronously on the queue to prevent a reentrancy
                // issue as it will write to the database and this closure is already called within
                // another database write
                queue.async {
                    SNLog("[UpdateProfilePictureJob] Profile successfully updated")
                    success(job, false, dependencies)
                }
            },
            failure: { error in
                SNLog("[UpdateProfilePictureJob] Failed to update profile")
                failure(job, error, false, dependencies)
            }
        )
    }
}

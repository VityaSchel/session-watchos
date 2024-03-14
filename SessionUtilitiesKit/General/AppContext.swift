// Copyright © 2024 Rangeproof Pty Ltd. All rights reserved.

import SignalCoreKit

// MARK: - Singleton

public extension Singleton {
    // FIXME: This will be reworked to be part of dependencies in the Groups Rebuild branch
    fileprivate static var _appContext: Atomic<AppContext?> = Atomic(nil)
    static var appContext: AppContext { _appContext.wrappedValue! }
    static var hasAppContext: Bool { _appContext.wrappedValue != nil }
    
    static func setup(appContext: AppContext) { _appContext.mutate { $0 = appContext } }
}

// MARK: - AppContext

public protocol AppContext: AnyObject {
    var _temporaryDirectory: String? { get set }
    var isMainApp: Bool { get }
    var isMainAppAndActive: Bool { get }
    var isShareExtension: Bool { get }
    var reportedApplicationState: /*UIApplication.State*/ Any { get }
    var mainWindow: /*UIWindow*/Any? { get }
    var isRTL: Bool { get }
    var frontmostViewController: /*UIViewController*/Any? { get }
    
    func setMainWindow(_ mainWindow: /*UIWindow*/Any)
    func ensureSleepBlocking(_ shouldBeBlocking: Bool, blockingObjects: [Any])
    func beginBackgroundTask(expirationHandler: @escaping () -> ()) -> /*UIBackgroundTaskIdentifier*/Any
    func endBackgroundTask(_ backgroundTaskIdentifier: /*UIBackgroundTaskIdentifier*/Any)
    
    /// **Note:** We need to call this method on launch _and_ every time the app becomes active,
    /// since file protection may prevent it from succeeding in the background.
    func clearOldTemporaryDirectories()
}

// MARK: - Defaults

public extension AppContext {
    var isMainApp: Bool { false }
    var isMainAppAndActive: Bool { false }
    var isShareExtension: Bool { false }
    var mainWindow: /*UIWindow*/Any? { nil }
    var frontmostViewController: /*UIViewController*/Any? { nil }
    
    var isInBackground: Bool { /*reportedApplicationState == .background*/false }
    var isAppForegroundAndActive: Bool { /*reportedApplicationState == .active*/true }
    
    // MARK: - Paths
    
    var appUserDefaults: UserDefaults {
        return (UserDefaults.sharedLokiProject ?? UserDefaults.standard)
    }
    
    var temporaryDirectory: String {
        if let dir: String = _temporaryDirectory { return dir }
        
        let dirName: String = "ows_temp_\(UUID().uuidString)"
        let dirPath: String = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(dirName)
            .path
        _temporaryDirectory = dirPath
        OWSFileSystem.ensureDirectoryExists(dirPath, fileProtectionType: .complete)
        
        return dirPath
    }
    
    var temporaryDirectoryAccessibleAfterFirstAuth: String {
        let dirPath: String = NSTemporaryDirectory()
        OWSFileSystem.ensureDirectoryExists(dirPath, fileProtectionType: .completeUntilFirstUserAuthentication)
        
        return dirPath;
    }
    
    var appDocumentDirectoryPath: String {
        let targetPath: String? = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .last?
            .path
        owsAssertDebug(targetPath != nil)
        
        return (targetPath ?? "")
    }
    
    // MARK: - Functions
    
    func setMainWindow(_ mainWindow: Any) {}
    func ensureSleepBlocking(_ shouldBeBlocking: Bool, blockingObjects: [Any]) {}
    func beginBackgroundTask(expirationHandler: @escaping () -> ()) -> Any { return 0 }
    func endBackgroundTask(_ backgroundTaskIdentifier: Any) {}
    
    func clearOldTemporaryDirectories() {}
}

// MARK: - Objective C Support

// FIXME: Remove this once the OWSFileSystem has been refactored to Swift
@objc public class OWSCurrentAppContext: NSObject {
    @objc public static var isRTL: Bool { /*Singleton.appContext.isRTL*/ false }
    @objc public static var isMainApp: Bool { /*Singleton.appContext.isMainApp*/ true }
    @objc public static var isMainAppAndActive: Bool { Singleton.appContext.isMainAppAndActive }
    @objc public static var isAppForegroundAndActive: Bool { Singleton.appContext.isAppForegroundAndActive }
    @objc public static var temporaryDirectory: String { Singleton.appContext.temporaryDirectory }
    @objc public static var appUserDefaults: UserDefaults { Singleton.appContext.appUserDefaults }
    @objc public static var appDocumentDirectoryPath: String { Singleton.appContext.appDocumentDirectoryPath }
    
    // FIXME: This will be reworked to be part of dependencies in the Groups Rebuild branch
    @objc static var appSharedDataDirectoryPath: String {
        let targetPath: String? = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: UserDefaults.applicationGroup)?
            .path
        owsAssertDebug(targetPath != nil)
        
        return (targetPath ?? "")
    }
    
    @objc static func beginBackgroundTask(expirationHandler: @escaping () -> ()) -> /*UIBackgroundTaskIdentifier*/Any {
        return Singleton.appContext.beginBackgroundTask { expirationHandler() }
    }
    
    @objc static func endBackgroundTask(_ backgroundTaskIdentifier: /*UIBackgroundTaskIdentifier*/Any) {
        Singleton.appContext.endBackgroundTask(backgroundTaskIdentifier)
    }
}

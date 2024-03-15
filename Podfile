platform :watchos, '10.0'

use_frameworks!
inhibit_all_warnings!

install! 'cocoapods', :warn_for_unused_master_specs_repo => false

# Dependencies to be included in the app and all extensions/frameworks
abstract_target 'GlobalDependencies' do
  # FIXME: If https://github.com/jedisct1/swift-sodium/pull/249 gets resolved then revert this back to the standard pod
  pod 'Sodium', :git => 'https://github.com/oxen-io/session-ios-swift-sodium.git', branch: 'session-build'
  pod 'GRDB.swift/SQLCipher'
  
  # FIXME: Would be nice to migrate from CocoaPods to SwiftPackageManager (should allow us to speed up build time), haven't gone through all of the dependencies but currently unfortunately SQLCipher doesn't support SPM (for more info see: https://github.com/sqlcipher/sqlcipher/issues/371)
  pod 'SQLCipher', '~> 4.5.3'

  # FIXME: We want to remove this once it's been long enough since the migration to GRDB
  pod 'YapDatabase/SQLCipher', :git => 'https://github.com/oxen-io/session-ios-yap-database.git', branch: 'signal-release'
#  pod 'WebRTC-lib'
  
#  target 'Session' do
#    pod 'Reachability'
#    pod 'PureLayout', '~> 3.1.8'
#    pod 'NVActivityIndicatorView'
#    pod 'YYImage/libwebp', git: 'https://github.com/signalapp/YYImage'
#    pod 'DifferenceKit'
#    
##    target 'SessionTests' do
##      inherit! :complete
##      
##      pod 'Quick'
##      pod 'Nimble'
##    end
#  end

#pod 'OpenSSL-Universal', :path => './OpenSSL/'
  
  # Dependencies to be included only in all extensions/frameworks
  abstract_target 'FrameworkAndExtensionDependencies' do
#    pod 'Curve25519Kit', git: 'https://github.com/oxen-io/session-ios-curve-25519-kit.git', branch: 'session-version'
    pod 'Curve25519Kit', :path => './session-ios-curve-25519-kit/'
#    pod 'SignalCoreKit', git: 'https://github.com/oxen-io/session-ios-core-kit', branch: 'session-version'
    pod 'SignalCoreKit', :path => './session-ios-core-kit/'
    pod 'OpenSSL-Universal', :path => './OpenSSL/'
    
#    target 'SessionNotificationServiceExtension'
    target 'SessionSnodeKit'
    
    # Dependencies that are shared across a number of extensions/frameworks but not all
    abstract_target 'ExtendedDependencies' do
#      pod 'PureLayout', '~> 3.1.8'
      
#      target 'SessionShareExtension' do
#        pod 'NVActivityIndicatorView'
#        pod 'DifferenceKit'
#      end
      
      target 'SignalUtilitiesKit' do
#        pod 'NVActivityIndicatorView'
#        pod 'Reachability'
        pod 'Reachability', :path => './Reachability'
        pod 'SAMKeychain'
        pod 'SwiftProtobuf', '~> 1.5.0'
        pod 'Curve25519Kit', :path => './session-ios-curve-25519-kit/'
#        pod 'YYImage/libwebp', git: 'https://github.com/signalapp/YYImage'
        pod 'DifferenceKit'
      end
      
      target 'SessionMessagingKit' do
#        pod 'Reachability'
        pod 'Reachability', :path => './Reachability'
        pod 'SAMKeychain'
        pod 'SwiftProtobuf', '~> 1.5.0'
        pod 'DifferenceKit'
        
#        target 'SessionMessagingKitTests' do
#          inherit! :complete
#          
#          pod 'Quick'
#          pod 'Nimble'
#          
#          # Need to include this for the tests because otherwise it won't actually build
#          pod 'YYImage/libwebp', git: 'https://github.com/signalapp/YYImage'
#        end
      end
      
      target 'SessionUtilitiesKit' do
        pod 'SAMKeychain'
        pod 'Curve25519Kit', :path => './session-ios-curve-25519-kit/'
#        pod 'YYImage/libwebp', git: 'https://github.com/signalapp/YYImage'
        pod 'DifferenceKit'
        
#        target 'SessionUtilitiesKitTests' do
#          inherit! :complete
#          
#          pod 'Quick'
#          pod 'Nimble'
#        end
      end
    end
  end
  
#  target 'SessionUIKit' do
#    pod 'GRDB.swift/SQLCipher'
#    pod 'DifferenceKit'
#    pod 'YYImage/libwebp', git: 'https://github.com/signalapp/YYImage'
#  end
end

# Actions to perform post-install
post_install do |installer|
  set_minimum_deployment_target(installer)
end

def set_minimum_deployment_target(installer)
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |build_configuration|
      build_configuration.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
    end
  end
end

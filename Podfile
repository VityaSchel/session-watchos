platform :watchos, '10.0'

use_frameworks!
inhibit_all_warnings!

install! 'cocoapods', :warn_for_unused_master_specs_repo => false
  
target 'session-ui' do
  pod 'Reachability', :path => './Reachability'
  pod 'DSF_QRCode', '~> 18.0.0'
  pod 'CryptoSwift', '~> 1.8.1'
  # FIXME: If https://github.com/jedisct1/swift-sodium/pull/249 gets resolved then revert this back
  pod 'Sodium', :git => 'https://github.com/oxen-io/session-ios-swift-sodium.git', branch: 'session-build'
  pod 'SwiftUIIntrospect', '~> 1.0'
end

def set_minimum_deployment_target(installer)
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |build_configuration|
      build_configuration.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '10.0'
      build_configuration.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
    end
  end
end

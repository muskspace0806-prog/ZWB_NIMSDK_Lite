platform :ios, '13.0'

target 'ZWB_NIMSDK' do
  use_frameworks!

  pod 'NEChatKit',      '10.9.10'

  # 本地源码，方便修改（首次使用需执行 scripts/setup_local_pods.sh）
  pod 'NEChatUIKit',              :path => './LocalPods/NEChatUIKit'
  pod 'NELocalConversationUIKit', :path => './LocalPods/NELocalConversationUIKit'
  pod 'NEContactUIKit',           :path => './LocalPods/NEContactUIKit'

  pod 'Kingfisher', '~> 7.0'
  pod 'SnapKit',    '~> 5.0'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end

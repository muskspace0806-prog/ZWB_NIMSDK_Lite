platform :ios, '13.0'

target 'ZWB_NIMSDK_Lite' do
  use_frameworks!

  # 云信 IM 核心 SDK（纯数据层，不含任何 UIKit/Kit 封装）
  pod 'NIMSDK_LITE', '10.9.71'

  # 图片加载 / 布局
  pod 'Kingfisher', '~> 7.0'
  pod 'SnapKit',    '~> 5.0'
  pod 'IQKeyboardManager'
  pod 'TZImagePickerController/Basic'  #仅用最简单的功能,如果需要全功能就是使用这个 pod 'TZImagePickerController'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end

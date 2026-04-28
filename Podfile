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

# ============================================================
# post_install：
# 1. 统一部署目标
# 2. 自动注入 attachment.parse() 到 ChatMessageHelper（两处）
#    每次 pod install 自动检查并注入，无需手动修改
# ============================================================
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end

  helper_path = File.join(
    File.dirname(__FILE__),
    'LocalPods/NEChatUIKit/NEChatUIKit/Classes/Chat/Helper/ChatMessageHelper.swift'
  )

  unless File.exist?(helper_path)
    puts "[ZWB] ⚠️ 未找到 ChatMessageHelper.swift，请先运行 scripts/setup_local_pods.sh"
    next
  end

  content      = File.read(helper_path)
  inject_code  = "    if let attachment = message.attachment as? V2NIMMessageCustomAttachment {\n      attachment.parse(attachment.raw)\n    }\n"
  marker_sync  = "  public static func modelFromMessage(message: V2NIMMessage) -> MessageModel {\n    var model: MessageModel"
  marker_async = "  public static func modelFromMessage(message: V2NIMMessage, _ completion: @escaping (MessageModel) -> Void) {\n    var model: MessageModel"

  modified = false

  [marker_sync, marker_async].each do |marker|
    injected_marker = marker.sub("    var model: MessageModel", inject_code + "    var model: MessageModel")
    unless content.include?(inject_code)
      if content.include?(marker)
        content  = content.sub(marker, injected_marker)
        modified = true
      end
    end
  end

  if modified
    File.write(helper_path, content)
    puts '[ZWB] ✅ ChatMessageHelper 注入成功'
  else
    puts '[ZWB] ChatMessageHelper 已注入或无需修改'
  end
end

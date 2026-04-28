//
//  ZWB_IMManager.swift
//  ZWB_NIMSDK
//
//  IM SDK 统一初始化管理，隔离 pod 变化对业务层的影响
//

import UIKit
import NIMSDK
import NECoreIM2Kit
import NEChatKit
import NEChatUIKit
import NELocalConversationUIKit
import NEContactUIKit

/// IM 初始化配置
struct ZWB_IMConfig {
    /// 云信控制台的 AppKey
    var appKey: String
    /// APNs 推送证书名（有推送时填写，否则传 nil）
    var apnsCerName: String? = nil
}

/// IM 登录参数
struct ZWB_IMLoginParam {
    /// 云信账号（accid）
    var account: String
    /// 服务端下发的登录 token
    var token: String
}

/// IM 管理单例，封装所有 pod 的初始化/登录/登出
class ZWB_IMManager {

    static let shared = ZWB_IMManager()
    private init() {}

    // MARK: - 初始化 SDK（在 AppDelegate didFinishLaunching 中调用）

    func setupIM(config: ZWB_IMConfig) {
        guard !config.appKey.isEmpty else { return }

        let option = NIMSDKOption(appKey: config.appKey)
        option.appKey      = config.appKey
        option.apnsCername = config.apnsCerName

        // 本地会话模式，不需要开启云端会话
        let v2Option = V2NIMSDKOption()
        v2Option.enableV2CloudConversation = false

        // setupIM2 同时初始化 Kit 层和底层 NIMSDK
        IMKitClient.instance.setupIM2(option, v2Option)

        // 注册消息事件到本地会话服务（收到消息 → 会话列表刷新）
        ChatKitClient.shared.setupInit(isFun: false)
        ChatKitClient.shared.registerInit(NELocalConversationService.shared)

        // 各 UIKit 模块服务注册（必须调用，否则消息监听不生效）
        NELocalConversationLoaderService.shared.setupInit()
        NEChatLoaderService.shared.setupInit()
        NEContactLoaderService.shared.setupInit()

        // 注册各 UIKit 路由（必须调用，否则页面跳转不生效）
        ChatRouter.register()
        LocalConversationRouter.register()
        ContactRouter.register()

        // 注册自定义消息 cell（必须在任何消息解析之前注册）
        // key 为 ZWB_CellType.rawValue，与 ZWB_CustomAttachment 里写入的 "type" 字段对应
        NEChatUIKitClient.instance.regsiterCustomCell([
            "\(ZWB_CellType.imageText.rawValue)": ZWB_ImageTextMessageCell.self,
            "\(ZWB_CellType.customXib.rawValue)": ZWB_CustomXibCell.self,
        ])

        // 注册自定义消息附件解析器（将 raw JSON 解析成对应的 attachment 对象）
        ZWB_CustomAttachmentParser.register()
    }

    // MARK: - 登录（服务端创建账号后，将 accid + token 下发给客户端再调用）

    func login(param: ZWB_IMLoginParam, completion: @escaping (Error?) -> Void) {
        IMKitClient.instance.login(param.account, param.token, nil) { error in
            completion(error)
        }
    }

    // MARK: - 登出

    func logout(completion: @escaping (Error?) -> Void) {
        IMKitClient.instance.logoutIM { error in
            completion(error)
        }
    }

    // MARK: - 是否已登录

    /// 判断当前是否已登录（用于 App 启动时决定跳转到登录页还是会话列表）
    var isLoggedIn: Bool {
        return IMKitClient.instance.hasLogined()
    }

    // MARK: - 打开单聊

    /// 通过 conversationId 打开单聊页面
    /// - Parameters:
    ///   - conversationId: 会话 ID（格式：V2NIMConversationIdUtil.p2pConversationId(accid)）
    ///   - nav: 当前导航控制器
    func openP2pChat(conversationId: String, nav: UINavigationController?) {
        let chatVC = ZWB_ChatViewController(conversationId: conversationId)
        nav?.pushViewController(chatVC, animated: true)
    }
}

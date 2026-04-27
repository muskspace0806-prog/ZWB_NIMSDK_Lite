//
//  ZWB_IMManager.swift
//  ZWB_NIMSDK
//

import UIKit
import NIMSDK
import NECoreIM2Kit
import NEChatKit
import NEChatUIKit
import NELocalConversationUIKit
import NEContactUIKit

struct ZWB_IMConfig {
    var appKey: String
    var apnsCerName: String? = nil
}

struct ZWB_IMLoginParam {
    var account: String
    var token: String
}

class ZWB_IMManager {

    static let shared = ZWB_IMManager()
    private init() {}

    // MARK: - 初始化 SDK

    func setupIM(config: ZWB_IMConfig) {
        guard !config.appKey.isEmpty else { return }

        let option = NIMSDKOption(appKey: config.appKey)
        option.appKey      = config.appKey
        option.apnsCername = config.apnsCerName

        // 本地会话不需要开启 enableV2CloudConversation
        let v2Option = V2NIMSDKOption()
        v2Option.enableV2CloudConversation = false

        // setupIM2 同时初始化 Kit 层和底层 NIMSDK，无需再单独调用 NIMSDK.shared().register
        IMKitClient.instance.setupIM2(option, v2Option)

        // 注册消息事件到本地会话服务（收到消息 → 会话列表刷新）
        ChatKitClient.shared.setupInit(isFun: false)
        ChatKitClient.shared.registerInit(NELocalConversationService.shared)

        // 各 UIKit 模块服务注册
        NELocalConversationLoaderService.shared.setupInit()
        NEChatLoaderService.shared.setupInit()
        NEContactLoaderService.shared.setupInit()

        // 注册路由
        ChatRouter.register()
        LocalConversationRouter.register()
        ContactRouter.register()

        print("[ZWB_IM] 初始化完成 AppKey: \(config.appKey)")
    }

    // MARK: - 登录

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

    var isLoggedIn: Bool {
        return IMKitClient.instance.hasLogined()
    }

    // MARK: - 打开单聊

    func openP2pChat(conversationId: String, nav: UINavigationController?) {
        let chatVC = ZWB_ChatViewController(conversationId: conversationId)
        nav?.pushViewController(chatVC, animated: true)
    }
}

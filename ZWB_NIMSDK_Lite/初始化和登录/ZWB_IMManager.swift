//
//  ZWB_IMManager.swift
//  ZWB_NIMSDK_Lite
//
//  IM SDK 统一初始化管理 — 只依赖 NIMSDK_LITE
//

import UIKit
import NIMSDK

// MARK: - 配置 & 参数

struct ZWB_IMConfig {
    var appKey: String
    var apnsCerName: String? = nil
}

struct ZWB_IMLoginParam {
    var account: String
    var token: String
}

// MARK: - 管理单例

class ZWB_IMManager {

    static let shared = ZWB_IMManager()
    private init() {}

    // MARK: 初始化 SDK

    func setupIM(config: ZWB_IMConfig) {
        guard !config.appKey.isEmpty else { return }

        let option = NIMSDKOption(appKey: config.appKey)
        option.apnsCername = config.apnsCerName

        // V2 API 必须用 registerWithOptionV2，否则 v2LoginService 不可用
        let v2Option = V2NIMSDKOption()
        v2Option.enableV2CloudConversation = false  // 使用本地会话模式
        NIMSDK.shared().register(withOptionV2: option, v2Option: v2Option)

        ZWB_CustomAttachmentParser.register()
    }

    // MARK: 登录（completion 传 V2NIMError? 而非 Error?）

    func login(param: ZWB_IMLoginParam, completion: @escaping (V2NIMError?) -> Void) {
        NIMSDK.shared().v2LoginService.login(
            param.account,
            token: param.token,
            option: nil
        ) {
            completion(nil)
        } failure: { error in
            completion(error)
        }
    }

    // MARK: 登出

    func logout(completion: @escaping (V2NIMError?) -> Void) {
        NIMSDK.shared().v2LoginService.logout {
            completion(nil)
        } failure: { error in
            completion(error)
        }
    }

    // MARK: 是否已登录

    var isLoggedIn: Bool {
        // V2NIM_LOGIN_STATUS_LOGINED = 1
        return NIMSDK.shared().v2LoginService.getLoginStatus().rawValue == 1
    }

    // MARK: 当前登录账号

    var currentAccount: String {
        return NIMSDK.shared().v2LoginService.getLoginUser() ?? ""
    }
}

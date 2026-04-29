//
//  ZWB_IMManager.swift
//  ZWB_NIMSDK_Lite
//
//  IM SDK 统一初始化管理 — 只依赖 NIMSDK_LITE，不引入任何 UIKit/Kit 封装
//  所有业务层通过此单例与 SDK 交互，隔离 SDK 变化对业务的影响
//

import UIKit
import NIMSDK

// MARK: - SDK 初始化配置

/// SDK 初始化所需参数
struct ZWB_IMConfig {
    /// 云信控制台的 AppKey
    var appKey: String
    /// APNs 推送证书名，无推送需求时传 nil
    var apnsCerName: String? = nil
}

// MARK: - 登录参数

/// 登录所需参数，由服务端下发给客户端
struct ZWB_IMLoginParam {
    /// 云信账号（accid）
    var account: String
    /// 服务端下发的登录 token
    var token: String
}

// MARK: - IM 管理单例

/// IM SDK 统一管理单例
/// - 初始化：`setupIM(config:)`
/// - 登录：`login(param:completion:)`
/// - 登出：`logout(completion:)`
class ZWB_IMManager {

    /// 全局单例
    static let shared = ZWB_IMManager()
    private init() {}

    // MARK: - 初始化 SDK

    /// 初始化 SDK，必须在登录前调用
    /// - 使用本地会话模式（enableV2CloudConversation = false）
    /// - 注册自定义消息附件解析器
    /// - Parameter config: SDK 初始化配置
    func setupIM(config: ZWB_IMConfig) {
        guard !config.appKey.isEmpty else { return }

        let option = NIMSDKOption(appKey: config.appKey)
        option.apnsCername = config.apnsCerName

        // 必须使用 registerWithOptionV2，否则 v2LoginService 等 V2 API 不可用
        let v2Option = V2NIMSDKOption()
        v2Option.enableV2CloudConversation = false  // 本地会话模式，不使用云端会话
        NIMSDK.shared().register(withOptionV2: option, v2Option: v2Option)

        // 注册自定义消息附件解析器，必须在任何消息收发之前调用
        ZWB_CustomAttachmentParser.register()
    }

    // MARK: - 登录

    /// 登录云信 IM
    /// - Note: 回调类型为 V2NIMError?，不是 Swift 原生 Error
    /// - Parameters:
    ///   - param: 登录参数（account + token）
    ///   - completion: 登录结果回调，成功时 error 为 nil
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

    // MARK: - 登出

    /// 登出云信 IM
    /// - Parameter completion: 登出结果回调，成功时 error 为 nil
    func logout(completion: @escaping (V2NIMError?) -> Void) {
        NIMSDK.shared().v2LoginService.logout {
            completion(nil)
        } failure: { error in
            completion(error)
        }
    }

    // MARK: - 登录状态

    /// 是否已登录
    /// - Note: V2NIM_LOGIN_STATUS_LOGINED rawValue = 1
    var isLoggedIn: Bool {
        return NIMSDK.shared().v2LoginService.getLoginStatus().rawValue == 1
    }

    // MARK: - 当前账号

    /// 当前登录的账号（accid），未登录时返回空字符串
    var currentAccount: String {
        return NIMSDK.shared().v2LoginService.getLoginUser() ?? ""
    }
}

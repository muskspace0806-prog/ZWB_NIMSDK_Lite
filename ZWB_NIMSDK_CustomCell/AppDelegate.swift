//
//  AppDelegate.swift
//  ZWB_NIMSDK
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        let appKey  = UserDefaults.standard.string(forKey: "zwb_appKey") ?? ""
        let cerName = UserDefaults.standard.string(forKey: "zwb_cerName")
        let account = UserDefaults.standard.string(forKey: "zwb_account") ?? ""
        let token   = UserDefaults.standard.string(forKey: "zwb_token") ?? ""

        guard !appKey.isEmpty else { return true }

        // 初始化 SDK
        let config = ZWB_IMConfig(appKey: appKey, apnsCerName: cerName)
        ZWB_IMManager.shared.setupIM(config: config)

        // 有登录信息则自动重新登录，恢复 SDK 连接
        if !account.isEmpty && !token.isEmpty {
            let param = ZWB_IMLoginParam(account: account, token: token)
            ZWB_IMManager.shared.login(param: param) { error in
                if let error = error {
                    print("[ZWB_IM] 自动登录失败: \(error)")
                } else {
                    print("[ZWB_IM] 自动登录成功")
                }
            }
        }

        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}
}

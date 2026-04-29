//
//  AppDelegate.swift
//  ZWB_NIMSDK_Lite
//

import UIKit
import NIMSDK
import IQKeyboardManager

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // 全局键盘管理
        IQKeyboardManager.shared().isEnabled = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKickedOffline(_:)),
            name: .zwbIMKickedOffline,
            object: nil
        )

        let appKey  = UserDefaults.standard.string(forKey: "zwb_appKey") ?? ""
        let cerName = UserDefaults.standard.string(forKey: "zwb_cerName")
        let account = UserDefaults.standard.string(forKey: "zwb_account") ?? ""
        let token   = UserDefaults.standard.string(forKey: "zwb_token") ?? ""
        let isLoggedIn = !account.isEmpty && !token.isEmpty

        // 设置初始根视图
        window = UIWindow(frame: UIScreen.main.bounds)

        if isLoggedIn && !appKey.isEmpty {
            // 有登录信息：先初始化 SDK，显示会话列表（会话列表内部等 onDataSync 完成后再拉数据）
            let config = ZWB_IMConfig(appKey: appKey, apnsCerName: cerName)
            ZWB_IMManager.shared.setupIM(config: config)

            let param = ZWB_IMLoginParam(account: account, token: token)
            ZWB_IMManager.shared.login(param: param) { error in
                if let error = error {
                    print("[ZWB_IM] 自动登录失败: \(error.desc ?? "")")
                } else {
                    print("[ZWB_IM] 自动登录成功")
                }
            }

            // 直接显示会话列表，内部会等 onDataSync 完成后拉取数据
            window?.rootViewController = UINavigationController(
                rootViewController: ZWB_ConversationListViewController()
            )
        } else {
            // 未登录：显示登录页
            window?.rootViewController = UINavigationController(
                rootViewController: ZWB_LoginViewController()
            )
        }

        window?.makeKeyAndVisible()
        return true
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleKickedOffline(_ notification: Notification) {
        let detail = notification.object as? V2NIMKickedOfflineDetail
        let reason = detail?.reasonDesc?.isEmpty == false ? (detail?.reasonDesc ?? "") : "当前账号已在其他设备登录"
        gotoLoginPage(message: reason)
    }

    private func gotoLoginPage(message: String?) {
        DispatchQueue.main.async {
            UserDefaults.standard.removeObject(forKey: "zwb_account")
            UserDefaults.standard.removeObject(forKey: "zwb_token")

            let nav = UINavigationController(rootViewController: ZWB_LoginViewController())
            guard let window = self.window else { return }
            window.rootViewController = nav
            window.makeKeyAndVisible()
            UIView.transition(with: window,
                              duration: 0.25,
                              options: .transitionCrossDissolve,
                              animations: nil)

            if let message = message, !message.isEmpty {
                let alert = UIAlertController(title: "提示", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确定", style: .default))
                nav.present(alert, animated: true)
            }
        }
    }
}

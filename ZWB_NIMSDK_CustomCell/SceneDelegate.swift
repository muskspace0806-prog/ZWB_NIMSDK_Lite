//
//  SceneDelegate.swift
//  ZWB_NIMSDK
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)

        // 用本地持久化的 account/token 判断是否已登录
        // 不依赖 SDK 的 hasLogined()，避免异步恢复导致判断失败
        let account = UserDefaults.standard.string(forKey: "zwb_account") ?? ""
        let token   = UserDefaults.standard.string(forKey: "zwb_token") ?? ""
        let isLoggedIn = !account.isEmpty && !token.isEmpty

        let rootVC: UIViewController
        if isLoggedIn {
            rootVC = UINavigationController(rootViewController: ZWB_ConversationListViewController())
        } else {
            rootVC = UINavigationController(rootViewController: ZWB_LoginViewController())
        }

        window?.rootViewController = rootVC
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}

//
//  ZWB_ConversationListViewController.swift
//  ZWB_NIMSDK
//
//  嵌入 LocalConversationController 作为子 VC（对应 v9 的 NEConversationListCtrl 用法）
//

import UIKit
import NELocalConversationUIKit
import NECoreIM2Kit

class ZWB_ConversationListViewController: UIViewController {

    private let listCtrl = LocalConversationController()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息"
        view.backgroundColor = .white
        embedListCtrl()
        IMKitClient.instance.addLoginListener(self)
    }

    deinit {
        IMKitClient.instance.removeLoginListener(self)
    }

    private func embedListCtrl() {
        addChild(listCtrl)
        listCtrl.view.frame = view.bounds
        listCtrl.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(listCtrl.view)
        listCtrl.didMove(toParent: self)
    }
}

extension ZWB_ConversationListViewController: NEIMKitClientListener {

    func onKickedOffline(_ detail: V2NIMKickedOfflineDetail) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: "您已被踢下线",
                                          message: "账号在其他设备登录，请重新登录",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                UserDefaults.standard.removeObject(forKey: "zwb_account")
                UserDefaults.standard.removeObject(forKey: "zwb_token")
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else { return }
                let nav = UINavigationController(rootViewController: ZWB_LoginViewController())
                window.rootViewController = nav
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
            })
            self?.present(alert, animated: true)
        }
    }
}

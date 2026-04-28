//
//  ZWB_ConversationListViewController.swift
//  ZWB_NIMSDK
//
//  入口页面：会话列表，cell 点击跳转 ZWB_ChatViewController
//

import UIKit
import NELocalConversationUIKit
import NEChatUIKit
import NEChatKit
import SnapKit

class ZWB_ConversationListViewController: UIViewController {

    // MARK: - 子页面

    /// pod 提供的会话列表（继承版）
    private let podVC = LocalConversationController()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息"
        view.backgroundColor = .white
        embedPodVC()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 拦截 pod 内部跳转，替换为 ZWB_ChatViewController
        navigationController?.delegate = self
    }

    // MARK: - 嵌入 pod 会话列表

    private func embedPodVC() {
        addChild(podVC)
        view.addSubview(podVC.view)
        podVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        podVC.didMove(toParent: self)
    }
}

// MARK: - UINavigationControllerDelegate
// 拦截 LocalConversationController cell 点击后 push 的 P2PChatViewController，
// 替换为 ZWB_ChatViewController（注入了自定义 ViewModel）

extension ZWB_ConversationListViewController: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        guard viewController is P2PChatViewController,
              !(viewController is ZWB_ChatViewController) else { return }

        let conversationId = ChatRepo.conversationId
        guard !conversationId.isEmpty else { return }

        let zwbChatVC = ZWB_ChatViewController(conversationId: conversationId)
        var vcs = navigationController.viewControllers
        if let idx = vcs.indices.last {
            vcs[idx] = zwbChatVC
            navigationController.setViewControllers(vcs, animated: false)
        }
    }
}

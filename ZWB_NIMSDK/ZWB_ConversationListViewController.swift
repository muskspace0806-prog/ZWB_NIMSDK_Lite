//
//  ZWB_ConversationListViewController.swift
//  ZWB_NIMSDK
//
//  容器页面，包含两种会话列表模式：
//  1. 继承版（pod）：使用 LocalConversationController，UI 由云信提供
//  2. 自定义版：使用 ZWB_CustomConversationListViewController，UI 完全自定义
//
//  两个悬浮按钮：
//  - 左侧：切换会话列表模式（继承版 / 自定义版）
//  - 右侧：切换跳转方式（云信默认 / 自定义跳转），仅继承模式下显示
//
//  跳转拦截原理：
//  viewWillDisappear 不清除 delegate，避免 push 时 delegate 被置 nil
//  willShow 检测到 P2PChatViewController 时，根据 useCustomChat 决定是否替换
//

import UIKit
import NELocalConversationUIKit
import NEChatUIKit
import NEChatKit
import SnapKit

class ZWB_ConversationListViewController: UIViewController {

    // MARK: - State

    /// 当前是否处于完全自定义会话列表模式
    private var isCustomMode: Bool = false {
        didSet {
            switchMode()
            chatSwitchButton.isHidden = isCustomMode
        }
    }

    /// 继承版模式下，cell 点击是否使用自定义跳转（ZWB_ChatViewController）
    private var useCustomChat: Bool = false {
        didSet { updateChatSwitchButtonTitle() }
    }

    // MARK: - Child VCs

    private let podVC    = LocalConversationController()
    private let customVC = ZWB_CustomConversationListViewController()

    // MARK: - UI

    /// 左侧按钮：切换会话列表模式
    private lazy var listSwitchButton: UIButton = makeFloatButton(action: #selector(listSwitchTapped))

    /// 右侧按钮：切换跳转方式（仅继承模式下显示）
    private lazy var chatSwitchButton: UIButton = makeFloatButton(action: #selector(chatSwitchTapped))

    private func makeFloatButton(action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        btn.layer.cornerRadius = 18
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.2
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 4
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息"
        view.backgroundColor = .white
        setupButtons()
        switchMode()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 设置 delegate，用于拦截继承版 push 跳转
        navigationController?.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 注意：不在这里清除 delegate
        // push 到聊天页时也会触发 viewWillDisappear，清除 delegate 会导致 willShow 收不到回调
    }

    // MARK: - Layout

    private func setupButtons() {
        view.addSubview(listSwitchButton)
        view.addSubview(chatSwitchButton)

        listSwitchButton.snp.makeConstraints { make in
            make.leading.equalTo(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(36)
        }

        chatSwitchButton.snp.makeConstraints { make in
            make.trailing.equalTo(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(36)
        }

        updateListSwitchButtonTitle()
        updateChatSwitchButtonTitle()
    }

    // MARK: - 按钮点击

    @objc private func listSwitchTapped() {
        isCustomMode.toggle()
    }

    @objc private func chatSwitchTapped() {
        let alert = UIAlertController(
            title: "选择跳转方式",
            message: "点击会话 cell 后跳转到哪个页面",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "云信默认 (P2PChatViewController)", style: .default) { [weak self] _ in
            self?.useCustomChat = false
        })
        alert.addAction(UIAlertAction(title: "自定义 (ZWB_ChatViewController)", style: .default) { [weak self] _ in
            self?.useCustomChat = true
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - 切换模式

    private func switchMode() {
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }
        let target: UIViewController = isCustomMode ? customVC : podVC
        addChild(target)
        view.insertSubview(target.view, belowSubview: listSwitchButton)
        target.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        target.didMove(toParent: self)
        updateListSwitchButtonTitle()
    }

    private func updateListSwitchButtonTitle() {
        listSwitchButton.setTitle(isCustomMode ? "继承版列表" : "自定义列表", for: .normal)
    }

    private func updateChatSwitchButtonTitle() {
        chatSwitchButton.setTitle(useCustomChat ? "自定义跳转" : "云信默认跳转", for: .normal)
    }
}

// MARK: - UINavigationControllerDelegate
// 继承版模式下，拦截 pod 内部 push P2PChatViewController
// useCustomChat = true 时替换成 ZWB_ChatViewController

extension ZWB_ConversationListViewController: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        guard !isCustomMode else { return }
        guard viewController is P2PChatViewController else { return }

        let conversationId = ChatRepo.conversationId
        guard !conversationId.isEmpty else { return }

        if useCustomChat {
            // 自定义跳转：替换成 ZWB_ChatViewController
            let zwbChatVC = ZWB_ChatViewController(conversationId: conversationId)
            var vcs = navigationController.viewControllers
            if let idx = vcs.indices.last {
                vcs[idx] = zwbChatVC
                navigationController.setViewControllers(vcs, animated: false)
            }
        }
        // useCustomChat = false：不做替换，保持云信默认 P2PChatViewController
    }
}

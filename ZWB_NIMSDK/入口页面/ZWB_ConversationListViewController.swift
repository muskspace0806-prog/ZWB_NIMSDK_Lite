//
//  ZWB_ConversationListViewController.swift
//  ZWB_NIMSDK
//
//  入口页面：管理两种会话列表模式 + 两种跳转方式的切换
//
//  两个悬浮按钮：
//  - 左下角：切换跳转方式（云信默认跳转 / 自定义跳转 ZWB_ChatViewController）
//  - 右下角：切换会话列表（继承版 LocalConversationController / 完全自定义版）
//
//  继承版跳转拦截：
//  通过 UINavigationControllerDelegate.willShow 检测到 P2PChatViewController 时，
//  根据 useCustomChat 决定是否替换成 ZWB_ChatViewController
//

import UIKit
import NELocalConversationUIKit
import NEChatUIKit
import NEChatKit
import SnapKit

class ZWB_ConversationListViewController: UIViewController {

    // MARK: - 状态

    /// 当前是否处于完全自定义会话列表模式
    private var isCustomMode: Bool = false {
        didSet {
            switchMode()
            // 自定义模式下隐藏跳转切换按钮（自定义列表自己处理跳转）
            chatSwitchButton.isHidden = isCustomMode
        }
    }

    /// 继承版模式下，cell 点击是否使用自定义跳转（ZWB_ChatViewController）
    private var useCustomChat: Bool = false {
        didSet { updateChatSwitchButtonTitle() }
    }

    // MARK: - 子页面

    /// pod 提供的会话列表（继承版），UI 由云信 UIKit 提供
    private let podVC    = LocalConversationController()

    /// 完全自定义的会话列表，UI 和数据逻辑均由业务层控制
    private let customVC = ZWB_CustomConversationListViewController()

    // MARK: - UI

    /// 左下角按钮：切换跳转方式（云信默认 / 自定义 ZWB_ChatViewController）
    private lazy var chatSwitchButton: UIButton = makeFloatButton(action: #selector(chatSwitchTapped))

    /// 右下角按钮：切换会话列表模式（继承版 / 完全自定义版）
    private lazy var listSwitchButton: UIButton = makeFloatButton(action: #selector(listSwitchTapped))

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

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息"
        view.backgroundColor = .white
        setupButtons()
        switchMode()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 设置导航代理，用于拦截继承版 cell 点击后的跳转
        // 注意：不在 viewWillDisappear 里清除，否则 push 时会被清掉
        navigationController?.delegate = self
    }

    // MARK: - 布局

    private func setupButtons() {
        view.addSubview(chatSwitchButton)
        view.addSubview(listSwitchButton)

        // 左下角：切换跳转方式
        chatSwitchButton.snp.makeConstraints { make in
            make.leading.equalTo(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(36)
        }

        // 右下角：切换会话列表
        listSwitchButton.snp.makeConstraints { make in
            make.trailing.equalTo(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(36)
        }

        updateChatSwitchButtonTitle()
        updateListSwitchButtonTitle()
    }

    // MARK: - 按钮点击

    /// 切换跳转方式（弹窗选择）
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

    /// 切换会话列表模式
    @objc private func listSwitchTapped() {
        isCustomMode.toggle()
    }

    // MARK: - 切换模式

    private func switchMode() {
        // 移除当前所有子 VC
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }

        // 嵌入目标子 VC（插入到按钮下方，保证按钮始终可见）
        let target: UIViewController = isCustomMode ? customVC : podVC
        addChild(target)
        view.insertSubview(target.view, belowSubview: chatSwitchButton)
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
// 拦截继承版（LocalConversationController）cell 点击后的跳转
// useCustomChat = true 时替换成 ZWB_ChatViewController

extension ZWB_ConversationListViewController: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        // 只在继承模式下拦截，自定义模式由 ZWB_CustomConversationListViewController 自己处理
        guard !isCustomMode else { return }

        // 检测到 pod 内部即将 push P2PChatViewController
        guard viewController is P2PChatViewController else { return }

        // ChatRepo.conversationId 是 NEChatKit 的类属性，存储当前正在打开的会话 ID
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

//
//  ZWB_ConversationListViewController.swift
//  ZWB_NIMSDK
//
//  容器页面：默认嵌入 pod 的 LocalConversationController（继承版）
//  悬浮按钮可切换到完全自定义版本 ZWB_CustomConversationListViewController
//
//  继承版跳转拦截原理：
//  LocalConversationController 点击 cell 后，内部通过 ChatRouter 调用
//  Router.shared.use(url, parameters:) push 一个 P2PChatViewController。
//  这里通过实现 UINavigationControllerDelegate，在 push 发生前拦截，
//  检测到目标是 P2PChatViewController 时，替换成 ZWB_ChatViewController，
//  从而统一使用我们自定义的聊天页面，方便后续业务扩展。
//

import UIKit
import NELocalConversationUIKit
import NEChatUIKit
import SnapKit

class ZWB_ConversationListViewController: UIViewController {

    // MARK: - State

    /// 当前是否处于自定义模式（false = pod 继承版，true = 完全自定义版）
    private var isCustomMode: Bool = false {
        didSet { switchMode() }
    }

    // MARK: - Child VCs

    /// pod 提供的会话列表（继承版），UI 由云信 UIKit 提供
    private let podVC    = LocalConversationController()

    /// 完全自定义的会话列表，UI 和数据逻辑均由业务层控制
    private let customVC = ZWB_CustomConversationListViewController()

    // MARK: - UI

    private lazy var switchButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        btn.layer.cornerRadius = 20
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.2
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 4
        btn.addTarget(self, action: #selector(toggleMode), for: .touchUpInside)
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息"
        view.backgroundColor = .white
        setupSwitchButton()
        switchMode()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 设置导航栏代理，用于拦截继承版的 push 跳转
        // 必须在 viewDidAppear 设置，确保 navigationController 已存在
        navigationController?.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 离开页面时移除代理，避免影响其他页面的导航行为
        if navigationController?.delegate === self {
            navigationController?.delegate = nil
        }
    }

    // MARK: - Layout

    private func setupSwitchButton() {
        view.addSubview(switchButton)
        switchButton.snp.makeConstraints { make in
            make.trailing.equalTo(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.height.equalTo(40)
            make.width.greaterThanOrEqualTo(120)
        }
        view.bringSubviewToFront(switchButton)
        updateButtonTitle()
    }

    // MARK: - 切换模式

    @objc private func toggleMode() {
        isCustomMode.toggle()
    }

    private func switchMode() {
        // 移除当前所有子 VC
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }

        // 嵌入目标子 VC（插入到 switchButton 下方，保证按钮始终可见）
        let target: UIViewController = isCustomMode ? customVC : podVC
        addChild(target)
        view.insertSubview(target.view, belowSubview: switchButton)
        target.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        target.didMove(toParent: self)

        updateButtonTitle()
    }

    private func updateButtonTitle() {
        let title = isCustomMode ? "切换到继承页面" : "切换到自定义页面"
        switchButton.setTitle(title, for: .normal)
    }
}

// MARK: - UINavigationControllerDelegate
// 拦截继承版（LocalConversationController）的 push 跳转
// 当 pod 内部 push P2PChatViewController 时，替换成 ZWB_ChatViewController

extension ZWB_ConversationListViewController: UINavigationControllerDelegate {

    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        // 只在继承模式下拦截，自定义模式由 ZWB_CustomConversationListViewController 自己处理
        guard !isCustomMode else { return }

        // 检测到 pod 内部即将 push P2PChatViewController
        guard let p2pVC = viewController as? P2PChatViewController else { return }

        // 从 viewModel 取出 conversationId（nullable，需要保护）
        guard let conversationId = p2pVC.viewModel.conversationId,
              !conversationId.isEmpty else { return }

        // 用 ZWB_ChatViewController 替换，保持 conversationId 一致
        let zwbChatVC = ZWB_ChatViewController(conversationId: conversationId)

        // 替换导航栈中的 P2PChatViewController -> ZWB_ChatViewController
        var vcs = navigationController.viewControllers
        if let idx = vcs.firstIndex(where: { $0 === p2pVC }) {
            vcs[idx] = zwbChatVC
            navigationController.setViewControllers(vcs, animated: false)
        }
    }
}

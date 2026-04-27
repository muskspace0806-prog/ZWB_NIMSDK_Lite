//
//  ZWB_ConversationListViewController.swift
//  ZWB_NIMSDK
//
//  容器页面：默认嵌入 pod 的 LocalConversationController（继承版）
//  悬浮按钮可切换到完全自定义版本 ZWB_CustomConversationListViewController
//

import UIKit
import NELocalConversationUIKit
import SnapKit

class ZWB_ConversationListViewController: UIViewController {

    // MARK: - State

    private var isCustomMode: Bool = false {
        didSet { switchMode() }
    }

    // MARK: - Child VCs

    private let podVC    = LocalConversationController()
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
        switchMode()   // 默认加载 pod 继承版
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
        // 移除当前子 VC
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }

        // 嵌入目标子 VC
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

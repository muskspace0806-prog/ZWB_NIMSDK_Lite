//
//  ZWB_ChatViewController.swift
//  ZWB_NIMSDK
//
//  单聊页面，嵌入 P2PChatViewController 作为子 VC
//
//  自定义消息 cell 通过 ZWB_IMManager.setupIM 里的 regsiterCustomCell 统一注册
//  自定义消息高度通过 ZWB_ChatMessageHelper+Swizzle 里的 Swizzle 注入
//

import UIKit
import NEChatUIKit

class ZWB_ChatViewController: UIViewController {

    /// 当前会话 ID
    private var conversationId: String

    /// 云信提供的单聊 VC，作为子 VC 嵌入
    private let chatVC: P2PChatViewController

    /// 通过会话 ID 初始化
    init(conversationId: String) {
        self.conversationId = conversationId
        self.chatVC = P2PChatViewController(conversationId: conversationId)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // 将 P2PChatViewController 作为子 VC 嵌入，充满整个视图
        addChild(chatVC)
        chatVC.view.frame = view.bounds
        chatVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(chatVC.view)
        chatVC.didMove(toParent: self)
    }
}

//
//  ZWB_ChatViewController.swift
//  ZWB_NIMSDK
//
//  嵌入 P2PChatViewController 作为子 VC
//

import UIKit
import NEChatUIKit

class ZWB_ChatViewController: UIViewController {

    private var conversationId: String
    private var chatVC: P2PChatViewController

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
        addChild(chatVC)
        chatVC.view.frame = view.bounds
        chatVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(chatVC.view)
        chatVC.didMove(toParent: self)
    }
}

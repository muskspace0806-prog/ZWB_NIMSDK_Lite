//
//  ZWB_ChatViewController.swift
//  ZWB_NIMSDK
//
//  单聊页面，继承 P2PChatViewController，注入自定义 ViewModel
//
//  方案说明：
//  直接继承 P2PChatViewController，在 init 中将 viewModel 替换为
//  ZWB_P2PChatViewModel，从而 override modelFromMessage 补调 parse，
//  解决历史消息 raw["type"] 缺失的问题。
//
//  注意：super.init 内部已调用 addListener()（绑定旧 ViewModel），
//  替换 viewModel 后需重新调用 addListener()，否则新 ViewModel 收不到事件。
//
//  不修改任何 LocalPods 文件。
//

import NEChatUIKit
import NIMSDK

class ZWB_ChatViewController: P2PChatViewController {

    /// 通过会话 ID 初始化（无锚点消息）
    override public init(conversationId: String) {
        super.init(conversationId: conversationId)
        // 替换为自定义 ViewModel，override modelFromMessage 补调 parse
        viewModel = ZWB_P2PChatViewModel(conversationId: conversationId, anchor: nil)
        // super.init 已绑定旧 ViewModel 的 listener，替换后重新绑定
        viewModel.addListener()
    }

    /// 通过会话 ID + 锚点消息初始化
    override public init(conversationId: String, anchor: V2NIMMessage?) {
        super.init(conversationId: conversationId)
        viewModel = ZWB_P2PChatViewModel(conversationId: conversationId, anchor: anchor)
        viewModel.addListener()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

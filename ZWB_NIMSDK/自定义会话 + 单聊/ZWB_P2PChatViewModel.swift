//
//  ZWB_P2PChatViewModel.swift
//  ZWB_NIMSDK
//
//  P2PChatViewModel 子类，override modelFromMessage
//
//  解决历史消息（数据库恢复）不调用 Parser 导致 raw["type"] 缺失的问题。
//  新消息由 ZWB_CustomAttachmentParser 处理，历史消息在此补调 parse。
//
//  调用链：
//  ChatViewModel.getHistoryMessage
//      └── modelFromMessage(message:)          ← override ✅
//      └── modelFromMessage(message:completion:) ← override ✅
//          └── ChatMessageHelper.modelFromMessage()  ← static，不可 override
//              └── NECustomUtils.typeOfCustomMessage() ← 读 raw["type"]
//

import NEChatUIKit
import NECoreIM2Kit
import NIMSDK

class ZWB_P2PChatViewModel: P2PChatViewModel {

    // MARK: - 同步版本（用于部分历史消息加载场景）

    override func modelFromMessage(message: V2NIMMessage) -> MessageModel {
        // 补调 parse，确保 raw["type"] 被写入，让 NECustomUtils.typeOfCustomMessage 能取到
        if let attachment = message.attachment as? V2NIMMessageCustomAttachment {
            attachment.parse(attachment.raw)
        }
        return super.modelFromMessage(message: message)
    }

    // MARK: - 异步版本（用于主要消息加载场景）

    override func modelFromMessage(message: V2NIMMessage,
                                   _ completion: @escaping (MessageModel) -> Void) {
        // 补调 parse，确保 raw["type"] 被写入
        if let attachment = message.attachment as? V2NIMMessageCustomAttachment {
            attachment.parse(attachment.raw)
        }
        super.modelFromMessage(message: message, completion)
    }
}

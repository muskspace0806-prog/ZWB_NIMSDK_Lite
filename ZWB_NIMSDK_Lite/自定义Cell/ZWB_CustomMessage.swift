//
//  ZWB_CustomMessage.swift
//  ZWB_NIMSDK_Lite
//
//  自定义消息：附件模型 + 解析器（合并在一个文件，职责紧密）
//
//  ┌─────────────────────────────────────────────────────────┐
//  │  服务端自定义消息 JSON 格式                               │
//  │  {                                                      │
//  │    "first":  10,      // 一级类型                        │
//  │    "second": 101,     // 二级类型                        │
//  │    "data": {          // 业务字段                        │
//  │      "title":  "标题",                                   │
//  │      "desc":   "描述",                                   │
//  │      "picUrl": "https://...",                           │
//  │      "webUrl": "https://..."                            │
//  │    }                                                    │
//  │  }                                                      │
//  └─────────────────────────────────────────────────────────┘
//
//  新增自定义消息类型步骤：
//  1. ZWB_CellType 加 case
//  2. ZWB_CellType.from() 加 first+second 映射
//  3. 新建对应 Cell 文件（继承 ZWB_BaseChatCell）
//  4. ZWB_ChatViewController.cellForRowAt 的 .MESSAGE_TYPE_CUSTOM 分支加 case
//

import Foundation
import NIMSDK

// MARK: - 自定义消息类型枚举

/// 自定义消息类型，与服务端 first+second 字段对应
/// Cell 通过此枚举决定使用哪个 Cell 类渲染
enum ZWB_CellType {
    /// 图文卡片（first=10, second=101）显示：标题 + 描述 + 图片
    case imageText
    // 新增类型在此处添加 case，例如：
    // case redPacket   // 红包消息
    // case voiceCall   // 语音通话记录

    /// 根据 first + second 返回对应类型，未知类型返回 nil
    static func from(first: Int, second: Int) -> ZWB_CellType? {
        switch (first, second) {
        case (10, 101): return .imageText
        // 新增类型在此处添加映射，例如：
        // case (20, 1):   return .redPacket
        default:        return nil
        }
    }
}

// MARK: - 自定义消息附件模型

/// 自定义消息附件，所有自定义类型共用此模型
/// Cell 通过 cellType 判断类型，按需取用对应字段
class ZWB_CustomAttachment: V2NIMMessageCustomAttachment {

    /// 消息类型，nil 表示未知类型
    var cellType: ZWB_CellType?

    /// 服务端 first 字段（一级类型）
    var first: Int = -1

    /// 服务端 second 字段（二级类型）
    var second: Int = -1

    /// 标题（imageText 类型使用）
    var title: String?

    /// 描述文字（所有类型通用）
    var desc: String?

    /// 图片 URL（所有类型通用）
    var picUrl: String?

    /// 跳转链接（imageText 类型使用）
    var webUrl: String?

    required override init() { super.init() }

    /// 解析服务端下发的 JSON 字符串，填充各字段
    /// - Parameter attach: 服务端下发的 attachment JSON 字符串
    override func parse(_ attach: String) {
        self.raw = attach

        guard let data  = attach.data(using: .utf8),
              let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let inner = json["data"] as? [String: Any] else { return }

        first    = json["first"]  as? Int ?? -1
        second   = json["second"] as? Int ?? -1
        cellType = ZWB_CellType.from(first: first, second: second)

        // 解析业务字段，Cell 按需取用
        title  = inner["title"]  as? String
        desc   = inner["desc"]   as? String
        picUrl = inner["picUrl"] as? String
        webUrl = inner["webUrl"] as? String
    }
}

// MARK: - 自定义消息附件解析器

/// 向 SDK 注册的自定义消息解析器
/// SDK 收到自定义消息时自动调用 parse()，将 JSON 转为 ZWB_CustomAttachment
/// 解析后可通过 `message.attachment as? ZWB_CustomAttachment` 取到数据
class ZWB_CustomAttachmentParser: NSObject, V2NIMMessageCustomAttachmentParser {

    /// 向 SDK 注册解析器，在 ZWB_IMManager.setupIM 中调用一次即可
    static func register() {
        NIMSDK.shared().v2MessageService.register(ZWB_CustomAttachmentParser())
    }

    /// SDK 收到自定义消息时回调，返回解析后的附件对象
    /// - Parameters:
    ///   - subType: SDK 内部子类型，当前未使用
    ///   - attach: 服务端下发的 attachment JSON 字符串
    /// - Returns: 解析成功返回 ZWB_CustomAttachment，未知类型返回 nil
    func parse(_ subType: Int32, attach: String) -> Any? {
        let att = ZWB_CustomAttachment()
        att.parse(attach)
        // cellType 为 nil 说明是未知类型，返回 nil 让 SDK 走默认处理
        return att.cellType != nil ? att : nil
    }
}

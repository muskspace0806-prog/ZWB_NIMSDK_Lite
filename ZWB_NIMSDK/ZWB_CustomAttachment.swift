//
//  ZWB_CustomAttachment.swift
//  ZWB_NIMSDK
//
//  自定义消息附件模型
//
//  消息 JSON 格式：
//  {
//    "first":  10,   // 一级类型
//    "second": 101,  // 二级类型
//    "data":   {...} // 具体内容
//  }
//
//  已知类型（从日志分析）：
//  first=10, second=101 → 图文消息（title + desc + picUrl）
//  first=42, second=1   → 用户信息消息（uid + nick + avatar）
//  first=42, second=2   → 用户信息消息（uid + nick + avatar）
//
//  关键说明：
//  NECustomUtils.typeOfCustomMessage 从 raw JSON 的顶层 "type" 字段取值，
//  用于匹配 getRegisterCustomCell 注册的 key。
//  由于服务端消息没有顶层 "type"，在 parse 里根据 first+second 计算出
//  ZWB_CellType.rawValue 并写入 raw 的 "type" 字段。
//

import Foundation
import NIMSDK

// MARK: - Cell 类型枚举（对应 getRegisterCustomCell 的 key）

enum ZWB_CellType: Int {
    case imageText = 1001  // first=10, second=101
    case user      = 1042  // first=42, second=1/2

    /// 根据 first + second 联合判断类型
    static func from(first: Int, second: Int) -> ZWB_CellType? {
        switch (first, second) {
        case (10, 101): return .imageText
        case (42, 1):   return .user
        case (42, 2):   return .user
        default:        return nil
        }
    }
}

// MARK: - 附件基类

class ZWB_BaseCustomAttachment: V2NIMMessageCustomAttachment {

    var first:    Int = -1
    var second:   Int = -1
    var cellType: ZWB_CellType?

    required override init() { super.init() }

    override func parse(_ attach: String) {
        self.raw = attach
    }

    func conversationText() -> String { return "[自定义消息]" }
    func cellHeight() -> CGFloat { return 60 }

    /// 解析 first/second，计算 cellType，并把 cellType.rawValue 写入 raw 的 "type" 字段
    /// NECustomUtils.typeOfCustomMessage 从 raw["type"] 取值匹配 cell
    func parseBaseFields(_ json: inout [String: Any]) {
        first  = json["first"]  as? Int ?? -1
        second = json["second"] as? Int ?? -1
        cellType = ZWB_CellType.from(first: first, second: second)

        if let ct = cellType {
            // 写入顶层 "type"，让 NECustomUtils.typeOfCustomMessage 能取到
            json["type"] = ct.rawValue
            if let newData = try? JSONSerialization.data(withJSONObject: json),
               let newRaw = String(data: newData, encoding: .utf8) {
                self.raw = newRaw
            }
        }
    }
}

// MARK: - 图文消息（first=10, second=101）

class ZWB_ImageTextAttachment: ZWB_BaseCustomAttachment {

    var title:  String?
    var desc:   String?
    var picUrl: String?
    var webUrl: String?

    override func parse(_ attach: String) {
        super.parse(attach)
        guard let data = attach.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let innerData = json["data"] as? [String: Any] else { return }

        title  = innerData["title"]  as? String
        desc   = innerData["desc"]   as? String
        picUrl = innerData["picUrl"] as? String
        webUrl = innerData["webUrl"] as? String

        // 写入 type 字段（必须在取完 innerData 之后调用）
        parseBaseFields(&json)
    }

    override func conversationText() -> String {
        return "[\(title ?? "图文消息")]"
    }

    override func cellHeight() -> CGFloat {
        let contentW: CGFloat = 230
        let padding:  CGFloat = 12
        let imageH:   CGFloat = picUrl != nil ? 120 : 0
        let spacing:  CGFloat = 8
        var h: CGFloat = padding * 2

        if let t = title, !t.isEmpty {
            let titleH = (t as NSString).boundingRect(
                with: CGSize(width: contentW - padding * 2, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: UIFont.systemFont(ofSize: 15, weight: .medium)],
                context: nil
            ).height
            h += ceil(titleH) + spacing
        }
        if imageH > 0 { h += imageH + spacing }
        if let d = desc, !d.isEmpty {
            let descH = (d as NSString).boundingRect(
                with: CGSize(width: contentW - padding * 2, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: UIFont.systemFont(ofSize: 13)],
                context: nil
            ).height
            h += ceil(descH)
        }
        return h + 16
    }
}

// MARK: - 用户消息（first=42, second=1/2）

class ZWB_UserAttachment: ZWB_BaseCustomAttachment {

    var uid:    Int?
    var nick:   String?
    var avatar: String?

    override func parse(_ attach: String) {
        super.parse(attach)
        guard let data = attach.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let innerData = json["data"] as? [String: Any] else { return }

        uid    = innerData["uid"]    as? Int
        nick   = innerData["nick"]   as? String
        avatar = innerData["avatar"] as? String

        parseBaseFields(&json)
    }

    override func conversationText() -> String {
        return "[\(nick ?? "用户消息")]"
    }

    override func cellHeight() -> CGFloat { return 72 }
}

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
//  已知类型：
//  first=10, second=101 → 图文消息（title + desc + picUrl）
//  first=99, second=2   → xib 自定义消息
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
// 新增类型：① 加 case ② 在 from() 加映射

enum ZWB_CellType: Int {
    
    case imageText =  9902  // first=99, second=2
    case customXib = 10101  // first=10, second=101

    static func from(first: Int, second: Int) -> ZWB_CellType? {
        switch (first, second) {
        case (99 ,2): return .imageText
        case (10, 101):   return .customXib
        default:        return nil
        }
    }
}

// MARK: - 附件基类
// 把 first+second 映射成 type 写入 raw，框架层逻辑，不动

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

    /// 解析 first/second，写入顶层 "type" 字段
    /// 必须在子类解析完业务字段后调用
    func parseBaseFields(_ json: inout [String: Any]) {
        first  = json["first"]  as? Int ?? -1
        second = json["second"] as? Int ?? -1
        cellType = ZWB_CellType.from(first: first, second: second)

        if let ct = cellType {
            json["type"] = ct.rawValue
            if let newData = try? JSONSerialization.data(withJSONObject: json),
               let newRaw = String(data: newData, encoding: .utf8) {
                self.raw = newRaw
            }
        }
    }
}



//MARK: 每一种自定义CellAttachment都写在斜下边



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

        parseBaseFields(&json)  // ⚠️ 最后调用，写入 raw["type"]
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

// MARK: - xib 自定义消息（first=99, second=2）
// 字段对标 ZWB_ImageTextAttachment：picUrl（图片）+ title（文字）
class ZWB_CustomXibAttachment: ZWB_BaseCustomAttachment {

    var title:  String?
    var picUrl: String?

    override func parse(_ attach: String) {
        super.parse(attach)
        guard let data = attach.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let innerData = json["data"] as? [String: Any] else { return }

        title  = innerData["title"]  as? String
        picUrl = innerData["picUrl"] as? String

        parseBaseFields(&json)  // ⚠️ 最后调用，写入 raw["type"]
    }

    override func conversationText() -> String {
        return "[\(title ?? "自定义消息")]"
    }

    // xib 固定高度：12(top) + 120(图片) + 12(间距) + 约20(label) + 12(bottom)
    override func cellHeight() -> CGFloat {
        return 176
    }
}

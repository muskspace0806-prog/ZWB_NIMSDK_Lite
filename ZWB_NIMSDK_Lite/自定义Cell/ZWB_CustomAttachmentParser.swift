//
//  ZWB_CustomAttachmentParser.swift
//  ZWB_NIMSDK
//
//  自定义消息附件解析器
//  根据 first + second 联合判断消息类型，返回对应的附件对象
//  parse 内部会把 ZWB_CellType.rawValue 写入 raw["type"]，
//  让 NECustomUtils.typeOfCustomMessage 能取到正确的 key
//

import Foundation
import NIMSDK

class ZWB_CustomAttachmentParser: NSObject, V2NIMMessageCustomAttachmentParser {

    static func register() {
        NIMSDK.shared().v2MessageService.register(ZWB_CustomAttachmentParser())
        print("[ZWB_Parser] ✅ 自定义消息解析器注册成功")
    }

    func parse(_ subType: Int32, attach: String) -> Any? {
        guard let data = attach.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let first  = json["first"]  as? Int ?? -1
        let second = json["second"] as? Int ?? -1

        // 根据 first + second 联合判断，返回对应的附件对象
        switch ZWB_CellType.from(first: first, second: second) {
        case .imageText:
            let attachment = ZWB_ImageTextAttachment()
            attachment.parse(attach)
            return attachment
        case .customXib:
            let attachment = ZWB_CustomXibAttachment()
            attachment.parse(attach)
            return attachment
        case .none:
            print("[ZWB_Parser] ⚠️ 未知类型 first=\(first) second=\(second)")
            return nil
        }
    }
}

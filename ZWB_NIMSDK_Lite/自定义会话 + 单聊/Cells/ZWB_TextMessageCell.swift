//
//  ZWB_TextMessageCell.swift
//  ZWB_NIMSDK_Lite
//
//  文本消息气泡（MESSAGE_TYPE_TEXT）
//  显示：纯文字，支持多行自动换行
//

import UIKit
import NIMSDK
import SnapKit

class ZWB_TextMessageCell: ZWB_BaseChatCell {

    /// TableView 复用标识符
    static let reuseId = "ZWB_TextMessageCell"

    // MARK: - UI

    /// 消息文字标签
    /// 注意：不能命名为 textLabel，与 UITableViewCell 父类属性冲突
    private let msgLabel: UILabel = {
        let lb = UILabel()
        lb.font          = .systemFont(ofSize: 15)
        lb.numberOfLines = 0       // 支持多行
        lb.textColor     = .black
        return lb
    }()

    // MARK: - 初始化

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        bubbleView.addSubview(msgLabel)
        msgLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 数据绑定

    /// 绑定消息数据
    /// - Parameters:
    ///   - message: 云信消息对象
    ///   - isSend: 是否为发送方消息
    func configure(message: V2NIMMessage, isSend: Bool) {
        applyLayout(isSend: isSend)
        msgLabel.text = message.text ?? ""
    }
}

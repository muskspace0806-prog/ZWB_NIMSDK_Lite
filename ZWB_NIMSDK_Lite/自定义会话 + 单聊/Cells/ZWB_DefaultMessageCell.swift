//
//  ZWB_DefaultMessageCell.swift
//  ZWB_NIMSDK_Lite
//
//  兜底消息气泡
//  用于暂不支持渲染的消息类型（语音、视频、文件、位置等）
//  显示对应类型的中文描述文字
//

import UIKit
import NIMSDK
import SnapKit

class ZWB_DefaultMessageCell: ZWB_BaseChatCell {

    /// TableView 复用标识符
    static let reuseId = "ZWB_DefaultMessageCell"

    // MARK: - UI

    /// 消息类型描述标签
    private let typeLabel: UILabel = {
        let lb = UILabel()
        lb.font          = .systemFont(ofSize: 13)
        lb.textColor     = .secondaryLabel
        lb.textAlignment = .center
        return lb
    }()

    // MARK: - 初始化

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        bubbleView.addSubview(typeLabel)
        typeLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 数据绑定

    /// 绑定消息数据，根据消息类型显示对应描述
    /// - Parameters:
    ///   - message: 云信消息对象
    ///   - isSend: 是否为发送方消息
    func configure(message: V2NIMMessage, isSend: Bool) {
        applyLayout(isSend: isSend)
        switch message.messageType {
        case .MESSAGE_TYPE_AUDIO:    typeLabel.text = "[语音消息]"
        case .MESSAGE_TYPE_VIDEO:    typeLabel.text = "[视频消息]"
        case .MESSAGE_TYPE_FILE:     typeLabel.text = "[文件消息]"
        case .MESSAGE_TYPE_LOCATION: typeLabel.text = "[位置消息]"
        default:                     typeLabel.text = "[\(message.messageType.rawValue) 类型消息]"
        }
    }
}

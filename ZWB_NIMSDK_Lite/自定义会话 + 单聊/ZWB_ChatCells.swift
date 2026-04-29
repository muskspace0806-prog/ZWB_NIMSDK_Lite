//
//  ZWB_ChatCells.swift
//  ZWB_NIMSDK_Lite
//
//  聊天页面所有消息 Cell — 纯自定义 UI，不依赖任何 UIKit pod
//
//  包含：
//  - ZWB_BaseChatCell      气泡基类（头像 + 气泡容器，左右布局）
//  - ZWB_TextMessageCell   文本消息
//  - ZWB_ImageMessageCell  图片消息
//  - ZWB_CustomMessageCell 自定义消息（图文卡片）
//  - ZWB_DefaultMessageCell 兜底（显示消息类型名）
//

import UIKit
import NIMSDK
import SnapKit

// MARK: - 气泡基类

class ZWB_BaseChatCell: UITableViewCell {

    // MARK: 公共控件

    let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 18
        iv.backgroundColor = .systemGray4
        iv.image = UIImage(systemName: "person.circle.fill")
        iv.tintColor = .systemGray2
        return iv
    }()

    /// 气泡容器，子类把内容 addSubview 到这里
    let bubbleView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        return v
    }()

    // MARK: 内部约束（子类通过 isSend 切换）

    private var bubbleLeading: Constraint?
    private var bubbleTrailing: Constraint?
    private var avatarLeading: Constraint?
    private var avatarTrailing: Constraint?

    // MARK: Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .none
        contentView.addSubview(avatarView)
        contentView.addSubview(bubbleView)
        setupBaseConstraints()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupBaseConstraints() {
        avatarView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.width.height.equalTo(36)
            avatarLeading  = $0.leading.equalToSuperview().offset(12).constraint
            avatarTrailing = $0.trailing.equalToSuperview().offset(-12).constraint
        }
        avatarTrailing?.deactivate()

        bubbleView.snp.makeConstraints {
            $0.top.equalTo(avatarView)
            $0.bottom.equalToSuperview().offset(-8)
            $0.width.lessThanOrEqualTo(260)
            bubbleLeading  = $0.leading.equalTo(avatarView.snp.trailing).offset(8).constraint
            bubbleTrailing = $0.trailing.equalTo(avatarView.snp.leading).offset(-8).constraint
        }
        bubbleTrailing?.deactivate()
    }

    // MARK: 切换左右布局

    func applyLayout(isSend: Bool) {
        if isSend {
            avatarLeading?.deactivate()
            avatarTrailing?.activate()
            bubbleLeading?.deactivate()
            bubbleTrailing?.activate()
            bubbleView.backgroundColor = UIColor(red: 0.56, green: 0.85, blue: 0.44, alpha: 1) // 微信绿
        } else {
            avatarTrailing?.deactivate()
            avatarLeading?.activate()
            bubbleTrailing?.deactivate()
            bubbleLeading?.activate()
            bubbleView.backgroundColor = .white
        }
    }
}

// MARK: - 文本消息 Cell

class ZWB_TextMessageCell: ZWB_BaseChatCell {

    static let reuseId = "ZWB_TextMessageCell"

    // 避免与 UITableViewCell.textLabel 冲突，改名为 msgTextLabel
    private let msgTextLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 15)
        lb.numberOfLines = 0
        return lb
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        bubbleView.addSubview(msgTextLabel)
        msgTextLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(message: V2NIMMessage, isSend: Bool) {
        applyLayout(isSend: isSend)
        msgTextLabel.text      = message.text ?? ""
        msgTextLabel.textColor = .black
    }
}

// MARK: - 图片消息 Cell

class ZWB_ImageMessageCell: ZWB_BaseChatCell {

    static let reuseId = "ZWB_ImageMessageCell"

    private let imageContentView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.image = UIImage(systemName: "photo")
        iv.tintColor = .systemGray3
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        bubbleView.addSubview(imageContentView)
        imageContentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(160)
            $0.height.equalTo(160)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(message: V2NIMMessage, isSend: Bool) {
        applyLayout(isSend: isSend)
        bubbleView.backgroundColor = .clear

        guard let attachment = message.attachment as? V2NIMMessageImageAttachment,
              let urlStr = attachment.url, let url = URL(string: urlStr) else {
            imageContentView.image = UIImage(systemName: "photo")
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async { self?.imageContentView.image = img }
            }
        }.resume()
    }
}

// MARK: - 自定义消息 Cell（图文卡片）

class ZWB_CustomMessageCell: ZWB_BaseChatCell {

    static let reuseId = "ZWB_CustomMessageCell"

    private let cardImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.layer.cornerRadius = 6
        return iv
    }()

    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 14, weight: .medium)
        lb.numberOfLines = 2
        return lb
    }()

    private let descLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 12)
        lb.textColor = .secondaryLabel
        lb.numberOfLines = 2
        return lb
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let stack = UIStackView(arrangedSubviews: [cardImageView, titleLabel, descLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .fill

        bubbleView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(10)
            $0.width.equalTo(200)
        }
        cardImageView.snp.makeConstraints { $0.height.equalTo(100) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(message: V2NIMMessage, isSend: Bool) {
        applyLayout(isSend: isSend)

        // 从已解析的 attachment 取数据
        if let att = message.attachment as? ZWB_ImageTextAttachment {
            titleLabel.text = att.title
            descLabel.text  = att.desc
            loadImage(urlStr: att.picUrl)
        } else if let att = message.attachment as? ZWB_CustomXibAttachment {
            titleLabel.text = att.desc
            descLabel.text  = nil
            loadImage(urlStr: att.picUrl)
        } else {
            titleLabel.text = "[自定义消息]"
            descLabel.text  = nil
            cardImageView.image = UIImage(systemName: "rectangle.and.text.magnifyingglass")
        }
    }

    private func loadImage(urlStr: String?) {
        guard let urlStr = urlStr, let url = URL(string: urlStr) else {
            cardImageView.image = UIImage(systemName: "photo")
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async { self?.cardImageView.image = img }
            }
        }.resume()
    }
}

// MARK: - 兜底 Cell

class ZWB_DefaultMessageCell: ZWB_BaseChatCell {

    static let reuseId = "ZWB_DefaultMessageCell"

    private let typeLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 13)
        lb.textColor = .secondaryLabel
        lb.textAlignment = .center
        return lb
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        bubbleView.addSubview(typeLabel)
        typeLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(message: V2NIMMessage, isSend: Bool) {
        applyLayout(isSend: isSend)
        typeLabel.text = "[\(message.messageType.rawValue) 类型消息]"
    }
}

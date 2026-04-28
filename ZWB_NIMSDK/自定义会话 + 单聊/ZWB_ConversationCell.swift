//
//  ZWB_ConversationCell.swift
//  ZWB_NIMSDK
//

import UIKit
import NIMSDK
import Kingfisher
import SnapKit

class ZWB_ConversationCell: UITableViewCell {

    static let reuseId = "ZWB_ConversationCell"

    private let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.layer.cornerRadius = 22
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.contentMode = .scaleAspectFill
        return iv
    }()

    private let nameLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 16, weight: .medium)
        return lb
    }()

    private let lastMsgLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 13)
        lb.textColor = .secondaryLabel
        return lb
    }()

    private let timeLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 12)
        lb.textColor = .tertiaryLabel
        return lb
    }()

    private let badgeLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 11, weight: .bold)
        lb.textColor = .white
        lb.backgroundColor = .systemRed
        lb.textAlignment = .center
        lb.layer.cornerRadius = 9
        lb.clipsToBounds = true
        lb.isHidden = true
        return lb
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(lastMsgLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(badgeLabel)

        avatarView.snp.makeConstraints { make in
            make.leading.equalTo(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(44)
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(10)
            make.top.equalTo(12)
            make.trailing.equalTo(timeLabel.snp.leading).offset(-8)
        }

        lastMsgLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.trailing.equalTo(badgeLabel.snp.leading).offset(-8)
        }

        timeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(-12)
            make.top.equalTo(nameLabel)
        }

        badgeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(-12)
            make.centerY.equalTo(lastMsgLabel)
            make.width.greaterThanOrEqualTo(18)
            make.height.equalTo(18)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with session: NIMRecentSession) {
        nameLabel.text = session.session?.sessionId ?? "未知"

        // 头像（用 Kingfisher 加载，暂时用占位图）
        avatarView.kf.setImage(with: URL(string: ""), placeholder: UIImage(systemName: "person.circle.fill"))

        // 最后一条消息
        if let msg = session.lastMessage {
            switch msg.messageType {
            case .text:   lastMsgLabel.text = msg.text ?? ""
            case .image:  lastMsgLabel.text = "[图片]"
            case .audio:  lastMsgLabel.text = "[语音]"
            case .video:  lastMsgLabel.text = "[视频]"
            default:      lastMsgLabel.text = "[消息]"
            }
        } else {
            lastMsgLabel.text = ""
        }

        // 时间
        let date = Date(timeIntervalSince1970: session.updateTime)
        timeLabel.text = formatTime(date)

        // 未读数
        let unread = session.unreadCount
        if unread > 0 {
            badgeLabel.isHidden = false
            badgeLabel.text = unread > 99 ? "99+" : "\(unread)"
        } else {
            badgeLabel.isHidden = true
        }
    }

    private func formatTime(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            return fmt.string(from: date)
        } else if cal.isDateInYesterday(date) {
            return "昨天"
        } else {
            let fmt = DateFormatter()
            fmt.dateFormat = "MM/dd"
            return fmt.string(from: date)
        }
    }
}

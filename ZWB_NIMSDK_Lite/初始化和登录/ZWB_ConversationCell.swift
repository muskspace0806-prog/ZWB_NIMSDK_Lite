//
//  ZWB_ConversationCell.swift
//  ZWB_NIMSDK_Lite
//
//  Created by hule on 2026/4/29.
//

import UIKit
import NIMSDK
import SnapKit
import Kingfisher

// MARK: - Cell

class ZWB_ConversationCell: UITableViewCell {

    static let reuseId = "ZWB_ConversationCell"

    private let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode        = .scaleAspectFill
        iv.clipsToBounds      = true
        iv.layer.cornerRadius = 22
        iv.backgroundColor    = .systemGray4
        iv.image              = UIImage(systemName: "person.circle.fill")
        iv.tintColor          = .systemGray2
        return iv
    }()

    private let nameLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 16, weight: .medium)
        return lb
    }()

    private let lastMsgLabel: UILabel = {
        let lb = UILabel()
        lb.font          = .systemFont(ofSize: 13)
        lb.textColor     = .secondaryLabel
        lb.numberOfLines = 2
        return lb
    }()

    private let timeLabel: UILabel = {
        let lb = UILabel()
        lb.font          = .systemFont(ofSize: 12)
        lb.textColor     = .tertiaryLabel
        lb.textAlignment = .right
        return lb
    }()

    private let badgeLabel: UILabel = {
        let lb = UILabel()
        lb.font               = .systemFont(ofSize: 11, weight: .bold)
        lb.textColor          = .white
        lb.backgroundColor    = .systemRed
        lb.textAlignment      = .center
        lb.layer.cornerRadius = 9
        lb.clipsToBounds      = true
        lb.isHidden           = true
        return lb
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        [avatarView, nameLabel, lastMsgLabel, timeLabel, badgeLabel].forEach { contentView.addSubview($0) }

        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.top.equalToSuperview().offset(12)
            $0.width.height.equalTo(44)
        }
        timeLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.trailing.equalToSuperview().offset(-16)
            $0.width.equalTo(50)
        }
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.equalTo(avatarView.snp.trailing).offset(12)
            $0.trailing.equalTo(timeLabel.snp.leading).offset(-8)
        }
        badgeLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-16)
            $0.top.equalTo(lastMsgLabel)
            $0.width.greaterThanOrEqualTo(18)
            $0.height.equalTo(18)
        }
        lastMsgLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
            $0.leading.equalTo(nameLabel)
            $0.trailing.equalTo(badgeLabel.snp.leading).offset(-8)
            $0.bottom.equalToSuperview().offset(-12)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with item: ZWB_ConversationItem) {
        nameLabel.text      = item.name
        lastMsgLabel.text   = item.lastMessage
        timeLabel.text      = item.lastTime
        badgeLabel.isHidden = item.unreadCount == 0
        if item.unreadCount > 0 {
            badgeLabel.text = item.unreadCount > 99 ? "99+" : "\(item.unreadCount)"
        }

        // 每次复用先重置为默认头像，防止复用时显示上一行的头像
        avatarView.image = UIImage(systemName: "person.circle.fill")
        // 用 conversationId 作为 tag，异步回调时校验是否还是同一行
        let currentId = item.conversationId
        avatarView.accessibilityIdentifier = currentId

        let loadAvatar: (String) -> Void = { [weak self] urlStr in
            guard let url = URL(string: urlStr) else { return }
            self?.avatarView.kf.setImage(with: url, placeholder: UIImage(systemName: "person.circle.fill"))
        }

        if let urlStr = item.avatarUrl, !urlStr.isEmpty {
            loadAvatar(urlStr)
        } else {
            loadUserAvatar(conversationId: item.conversationId, load: loadAvatar)
        }
    }

    /// 从 conversationId 解析对方 accid，查询用户头像 URL 后回调加载
    private func loadUserAvatar(conversationId: String, load: @escaping (String) -> Void) {
        let parts = conversationId.split(separator: "|")
        guard parts.count >= 3, String(parts[1]) == "1" else { return }

        let accid = String(parts[0])
        let user  = NIMSDK.shared().v2UserService.getUserInfo(accid, error: nil)
        guard let urlStr = user.avatar, !urlStr.isEmpty else { return }
        load(urlStr)
    }
}

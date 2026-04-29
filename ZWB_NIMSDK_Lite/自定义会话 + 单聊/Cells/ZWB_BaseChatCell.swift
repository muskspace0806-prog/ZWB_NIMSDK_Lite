//
//  ZWB_BaseChatCell.swift
//  ZWB_NIMSDK_Lite
//
//  聊天气泡基类
//
//  职责：
//  - 管理头像（avatarView）和气泡容器（bubbleView）的左右布局
//  - 根据 isSend 切换发送方（右侧绿色）/ 接收方（左侧白色）布局
//
//  子类使用方式：
//  1. 在 init 中把内容控件 addSubview 到 bubbleView
//  2. 实现 configure(message:isSend:) 或 configure(attachment:isSend:)
//  3. configure 内第一行调用 applyLayout(isSend:) 切换左右布局
//

import UIKit
import NIMSDK
import SnapKit
import Kingfisher

class ZWB_BaseChatCell: UITableViewCell {

    /// 头像点击回调（具体业务由外层页面处理）
    var onAvatarTapped: (() -> Void)?

    // MARK: - 公共控件（子类可直接访问）

    /// 头像视图，圆形，默认显示系统占位图
    let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode        = .scaleAspectFill
        iv.clipsToBounds      = true
        iv.layer.cornerRadius = 18
        iv.backgroundColor    = .systemGray4
        iv.image              = UIImage(systemName: "person.circle.fill")
        iv.tintColor          = .systemGray2
        return iv
    }()

    /// 气泡容器，子类把所有内容控件 addSubview 到这里
    let bubbleView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 12
        v.clipsToBounds      = true
        return v
    }()

    // MARK: - 内部布局约束（通过 applyLayout 动态切换）

    private var bubbleLeading:  Constraint?  // 气泡左对齐（接收方）
    private var bubbleTrailing: Constraint?  // 气泡右对齐（发送方）
    private var avatarLeading:  Constraint?  // 头像左对齐（接收方）
    private var avatarTrailing: Constraint?  // 头像右对齐（发送方）

    // MARK: - 初始化

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .none
        contentView.addSubview(avatarView)
        contentView.addSubview(bubbleView)
        avatarView.isUserInteractionEnabled = true
        avatarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(avatarTapped)))
        setupConstraints()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 约束初始化（默认接收方布局，头像左、气泡右）

    private func setupConstraints() {
        avatarView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.width.height.equalTo(36)
            avatarLeading  = $0.leading.equalToSuperview().offset(12).constraint   // 接收方：头像靠左
            avatarTrailing = $0.trailing.equalToSuperview().offset(-12).constraint  // 发送方：头像靠右
        }
        avatarTrailing?.deactivate()  // 默认接收方，右侧约束先关闭

        bubbleView.snp.makeConstraints {
            $0.top.equalTo(avatarView)
            $0.bottom.equalToSuperview().offset(-8)
            $0.width.lessThanOrEqualTo(260)
            bubbleLeading  = $0.leading.equalTo(avatarView.snp.trailing).offset(8).constraint   // 接收方：气泡在头像右侧
            bubbleTrailing = $0.trailing.equalTo(avatarView.snp.leading).offset(-8).constraint  // 发送方：气泡在头像左侧
        }
        bubbleTrailing?.deactivate()  // 默认接收方，右侧约束先关闭
    }

    // MARK: - 切换左右布局

    /// 根据消息方向切换头像和气泡的左右位置及颜色，同时加载发送者头像
    /// - Parameters:
    ///   - isSend: true = 发送方（右侧绿色气泡），false = 接收方（左侧白色气泡）
    ///   - senderId: 消息发送者 accid，用于查询头像
    func applyLayout(isSend: Bool, senderId: String = "") {
        if isSend {
            avatarLeading?.deactivate();  avatarTrailing?.activate()
            bubbleLeading?.deactivate();  bubbleTrailing?.activate()
            bubbleView.backgroundColor = UIColor(red: 0.56, green: 0.85, blue: 0.44, alpha: 1)
        } else {
            avatarTrailing?.deactivate(); avatarLeading?.activate()
            bubbleTrailing?.deactivate(); bubbleLeading?.activate()
            bubbleView.backgroundColor = .white
        }
        loadAvatar(accountId: senderId)
    }

    /// 根据 accid 查询用户头像并加载，Kingfisher 自动处理缓存和复用取消
    private func loadAvatar(accountId: String) {
        guard !accountId.isEmpty else {
            avatarView.image = UIImage(systemName: "person.circle.fill")
            return
        }
        let user = NIMSDK.shared().v2UserService.getUserInfo(accountId, error: nil)
        if let urlStr = user.avatar, !urlStr.isEmpty, let url = URL(string: urlStr) {
            avatarView.kf.setImage(with: url, placeholder: UIImage(systemName: "person.circle.fill"))
        } else {
            avatarView.image = UIImage(systemName: "person.circle.fill")
        }
    }

    @objc private func avatarTapped() {
        onAvatarTapped?()
    }
}

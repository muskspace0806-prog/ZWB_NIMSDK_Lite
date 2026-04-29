//
//  ZWB_ImageTextCell.swift
//  ZWB_NIMSDK_Lite
//
//  图文卡片消息（ZWB_CellType.imageText，first=10, second=101）
//  显示：标题 + 描述 + 图片，竖向排列
//

import UIKit
import NIMSDK
import SnapKit
import Kingfisher

class ZWB_ImageTextCell: ZWB_BaseChatCell {

    /// TableView 复用标识符
    static let reuseId = "ZWB_ImageTextCell"

    // MARK: - UI

    /// 卡片图片
    private let cardImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode        = .scaleAspectFill
        iv.clipsToBounds      = true
        iv.backgroundColor    = .systemGray5
        iv.layer.cornerRadius = 6
        return iv
    }()

    /// 标题标签，最多显示 2 行
    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.font          = .systemFont(ofSize: 14, weight: .medium)
        lb.numberOfLines = 2
        return lb
    }()

    /// 描述标签，最多显示 2 行
    private let descLabel: UILabel = {
        let lb = UILabel()
        lb.font          = .systemFont(ofSize: 12)
        lb.textColor     = .secondaryLabel
        lb.numberOfLines = 2
        return lb
    }()

    // MARK: - 初始化

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        // 竖向排列：图片 → 标题 → 描述
        let stack = UIStackView(arrangedSubviews: [cardImageView, titleLabel, descLabel])
        stack.axis      = .vertical
        stack.spacing   = 6
        stack.alignment = .fill

        bubbleView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(10)
            $0.width.equalTo(200)  // 固定卡片宽度
        }
        cardImageView.snp.makeConstraints { $0.height.equalTo(100) }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 数据绑定

    /// 绑定自定义消息附件数据
    /// - Parameters:
    ///   - attachment: 已解析的 ZWB_CustomAttachment，cellType 为 .imageText
    ///   - isSend: 是否为发送方消息
    func configure(attachment: ZWB_CustomAttachment, isSend: Bool) {
        applyLayout(isSend: isSend)

        titleLabel.text = attachment.title
        descLabel.text  = attachment.desc

        // Kingfisher 加载卡片图片，自动缓存
        if let urlStr = attachment.picUrl, let url = URL(string: urlStr) {
            cardImageView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
        } else {
            cardImageView.image = UIImage(systemName: "photo")
        }
    }
}

//
//  ZWB_CustomCell.swift
//  ZWB_NIMSDK_Lite
//
//  图片+描述消息（first=99, second=2）
//  显示：描述 + 图片
//

import UIKit
import NIMSDK
import SnapKit
import Kingfisher

class ZWB_CustomCell: ZWB_BaseChatCell {

    static let reuseId = "ZWB_CustomXibCell"

    private let photoView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode        = .scaleAspectFill
        iv.clipsToBounds      = true
        iv.backgroundColor    = .systemGray5
        iv.layer.cornerRadius = 6
        return iv
    }()

    private let descLabel: UILabel = {
        let lb = UILabel()
        lb.font          = .systemFont(ofSize: 13)
        lb.textColor     = .secondaryLabel
        lb.numberOfLines = 2
        return lb
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let stack = UIStackView(arrangedSubviews: [photoView, descLabel])
        stack.axis      = .vertical
        stack.spacing   = 8
        stack.alignment = .fill

        bubbleView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(10)
            $0.width.equalTo(180)
        }
        photoView.snp.makeConstraints { $0.height.equalTo(120) }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(attachment: ZWB_CustomAttachment, isSend: Bool) {
        applyLayout(isSend: isSend)

        descLabel.text = attachment.desc

        // Kingfisher 加载图片，自动缓存
        if let urlStr = attachment.picUrl, let url = URL(string: urlStr) {
            photoView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
        } else {
            photoView.image = UIImage(systemName: "photo")
        }
    }
}

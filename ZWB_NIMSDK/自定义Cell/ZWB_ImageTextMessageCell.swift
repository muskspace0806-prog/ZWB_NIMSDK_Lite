//
//  ZWB_ImageTextMessageCell.swift
//  ZWB_NIMSDK
//
//  图文消息 Cell（type=10101，first=10, second=101）
//  继承 ZWB_BaseCustomCell，只需实现 makeContentView + bindData
//

import UIKit
import SnapKit
import Kingfisher
import NEChatUIKit

class ZWB_ImageTextMessageCell: ZWB_BaseCustomCell {

    // MARK: - 内容视图（纯代码）

    override func makeContentView() -> UIView {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.tag = 1
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.numberOfLines = 2

        let imageView = UIImageView()
        imageView.tag = 2
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 6
        imageView.backgroundColor = .systemGray5

        let descLabel = UILabel()
        descLabel.tag = 3
        descLabel.font = .systemFont(ofSize: 13)
        descLabel.textColor = .secondaryLabel
        descLabel.numberOfLines = 3

        let stack = UIStackView(arrangedSubviews: [titleLabel, imageView, descLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        container.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        imageView.snp.makeConstraints { make in
            make.height.equalTo(120)
        }

        return container
    }

    // MARK: - 纯赋值，不用管 isSend

    override func bindData(to contentView: UIView, attachment: ZWB_BaseCustomAttachment) {
        guard let attachment = attachment as? ZWB_ImageTextAttachment else { return }

        let titleLabel = contentView.viewWithTag(1) as? UILabel
        let imageView  = contentView.viewWithTag(2) as? UIImageView
        let descLabel  = contentView.viewWithTag(3) as? UILabel

        titleLabel?.text = attachment.title
        titleLabel?.isHidden = attachment.title?.isEmpty ?? true

        descLabel?.text = attachment.desc
        descLabel?.isHidden = attachment.desc?.isEmpty ?? true

        if let urlStr = attachment.picUrl, let url = URL(string: urlStr) {
            imageView?.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
            imageView?.isHidden = false
        } else {
            imageView?.isHidden = true
        }
    }
}

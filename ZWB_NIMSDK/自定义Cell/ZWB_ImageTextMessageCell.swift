//
//  ZWB_ImageTextMessageCell.swift
//  ZWB_NIMSDK
//
//  图文自定义消息 Cell
//  继承 NEBaseChatMessageCell，左右气泡、头像由父类处理
//  只需在 bubbleImageLeft/bubbleImageRight 里添加内容视图
//

import UIKit
import SnapKit
import Kingfisher
import NEChatUIKit
import NECoreIM2Kit

class ZWB_ImageTextMessageCell: NEBaseChatMessageCell {

    // MARK: - 内容视图（左右各一套，父类根据方向控制显隐）

    // 左侧（接收方）
    private let titleLabelLeft  = ZWB_ImageTextMessageCell.makeTitleLabel()
    private let imageViewLeft   = ZWB_ImageTextMessageCell.makeImageView()
    private let descLabelLeft   = ZWB_ImageTextMessageCell.makeDescLabel()

    // 右侧（发送方）
    private let titleLabelRight = ZWB_ImageTextMessageCell.makeTitleLabel()
    private let imageViewRight  = ZWB_ImageTextMessageCell.makeImageView()
    private let descLabelRight  = ZWB_ImageTextMessageCell.makeDescLabel()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupContentViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 布局（添加到父类的 bubbleImageLeft/bubbleImageRight）
    // 使用 UIStackView 自动处理空视图间距，避免 title/desc 为空时出现多余空白

    private func setupContentViews() {
        let padding: CGFloat = 12

        // 左侧气泡内容
        let stackLeft = makeContentStack()
        stackLeft.addArrangedSubview(titleLabelLeft)
        stackLeft.addArrangedSubview(imageViewLeft)
        stackLeft.addArrangedSubview(descLabelLeft)
        bubbleImageLeft.addSubview(stackLeft)
        stackLeft.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(padding)
        }
        imageViewLeft.snp.makeConstraints { make in
            make.height.equalTo(120)
        }

        // 右侧气泡内容
        let stackRight = makeContentStack()
        stackRight.addArrangedSubview(titleLabelRight)
        stackRight.addArrangedSubview(imageViewRight)
        stackRight.addArrangedSubview(descLabelRight)
        bubbleImageRight.addSubview(stackRight)
        stackRight.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(padding)
        }
        imageViewRight.snp.makeConstraints { make in
            make.height.equalTo(120)
        }
    }

    /// 创建内容 StackView
    private func makeContentStack() -> UIStackView {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 8
        sv.alignment = .fill
        sv.distribution = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }

    // MARK: - 数据绑定（pod 调用）

    override func setModel(_ model: MessageContentModel, _ isSend: Bool) {
        // 保底：确保 contentSize 已设置，避免气泡宽高为 0 导致空白
        if let attachment = model.message?.attachment as? ZWB_ImageTextAttachment {
            if model.contentSize.width == 0 {
                let h = attachment.cellHeight()
                model.contentSize = CGSize(width: 230, height: h)
                model.height = h + 16
            }
        }

        super.setModel(model, isSend)

        // 从 attachment 取数据绑定 UI
        guard let attachment = model.message?.attachment as? ZWB_ImageTextAttachment else {
            return
        }

        let titleLabel = isSend ? titleLabelRight : titleLabelLeft
        let imageView  = isSend ? imageViewRight  : imageViewLeft
        let descLabel  = isSend ? descLabelRight  : descLabelLeft

        titleLabel.text = attachment.title
        // title 为空时隐藏，StackView 自动收起不占空间
        titleLabel.isHidden = attachment.title?.isEmpty ?? true

        descLabel.text = attachment.desc
        // desc 为空时隐藏
        descLabel.isHidden = attachment.desc?.isEmpty ?? true

        if let urlStr = attachment.picUrl, let url = URL(string: urlStr) {
            imageView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
            imageView.isHidden = false
        } else {
            imageView.isHidden = true
        }
    }

    // MARK: - 左右显隐（父类调用，控制左右内容显示）

    override func showLeftOrRight(showRight: Bool) {
        super.showLeftOrRight(showRight: showRight)
        titleLabelLeft.isHidden  = showRight
        imageViewLeft.isHidden   = showRight
        descLabelLeft.isHidden   = showRight
        titleLabelRight.isHidden = !showRight
        imageViewRight.isHidden  = !showRight
        descLabelRight.isHidden  = !showRight
    }

    // MARK: - UI 工厂方法

    private static func makeTitleLabel() -> UILabel {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 15, weight: .medium)
        lb.numberOfLines = 2
        lb.translatesAutoresizingMaskIntoConstraints = false
        return lb
    }

    private static func makeImageView() -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = .systemGray5
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }

    private static func makeDescLabel() -> UILabel {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 13)
        lb.textColor = .secondaryLabel
        lb.numberOfLines = 3
        lb.translatesAutoresizingMaskIntoConstraints = false
        return lb
    }
}

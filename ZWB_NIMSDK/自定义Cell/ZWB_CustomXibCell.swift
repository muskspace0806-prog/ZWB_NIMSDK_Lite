//
//  ZWB_CustomXibCell.swift
//  ZWB_NIMSDK
//
//  xib 自定义消息 Cell（type=9902，first=99, second=2）
//  布局在 ZWB_CustomXibCell.xib 中完成：上方 iconView（图片），下方 contentLabel（文字）
//
//  加载方式：
//  UINib 实例化时走 init?(coder:)，正常 super 即可。
//  左右气泡各实例化一份 xib cell，取其 outlet 绑数据，
//  把 contentView 嵌入父类的 bubbleImageLeft / bubbleImageRight。
//

import UIKit
import SnapKit
import Kingfisher
import NEChatUIKit
import NECoreIM2Kit

class ZWB_CustomXibCell: NEBaseChatMessageCell {

    // MARK: - xib outlet（xib 实例化时由 coder 注入）

    @IBOutlet weak var iconView:     UIImageView!
    @IBOutlet weak var contentLabel: UILabel!

    // MARK: - 左右各一份 xib 实例的 outlet 引用

    private var iconViewLeft:      UIImageView?
    private var contentLabelLeft:  UILabel?

    private var iconViewRight:     UIImageView?
    private var contentLabelRight: UILabel?

    // MARK: - Init

    /// 框架注册复用时走这里（正常使用入口）
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupXibViews()
    }

    /// UINib 实例化 xib 时走这里（用于加载左右内容视图）
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        // xib 实例只作为内容视图载体，不需要额外初始化
    }

    // MARK: - 加载 xib，嵌入气泡容器

    private func setupXibViews() {
        if let left = ZWB_CustomXibCell.loadFromXib() {
            bubbleImageLeft.addSubview(left.contentView)
            left.contentView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            iconViewLeft     = left.iconView
            contentLabelLeft = left.contentLabel
            // 用 remakeConstraints 覆盖 xib 里图片的所有约束，固定高度
            left.iconView?.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview().inset(12)
                make.height.equalTo(120)
            }
        }

        if let right = ZWB_CustomXibCell.loadFromXib() {
            bubbleImageRight.addSubview(right.contentView)
            right.contentView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            iconViewRight     = right.iconView
            contentLabelRight = right.contentLabel
            right.iconView?.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview().inset(12)
                make.height.equalTo(120)
            }
        }
    }

    /// 用 UINib 实例化一份 xib cell，走 init?(coder:) 路径
    private static func loadFromXib() -> ZWB_CustomXibCell? {
        let nib = UINib(nibName: "ZWB_CustomXibCell", bundle: nil)
        return nib.instantiate(withOwner: nil, options: nil).first as? ZWB_CustomXibCell
    }

    // MARK: - 数据绑定（框架调用）

    override func setModel(_ model: MessageContentModel, _ isSend: Bool) {
        if let attachment = model.message?.attachment as? ZWB_CustomXibAttachment,
           model.contentSize.width == 0 {
            let h = attachment.cellHeight()
            model.contentSize = CGSize(width: 230, height: h)
            model.height = h + 16
        }

        super.setModel(model, isSend)

        guard let attachment = model.message?.attachment as? ZWB_CustomXibAttachment else { return }

        let iconView     = isSend ? iconViewRight     : iconViewLeft
        let contentLabel = isSend ? contentLabelRight : contentLabelLeft

        contentLabel?.text = attachment.title ?? ""
        contentLabel?.isHidden = false

        if let urlStr = attachment.picUrl, let url = URL(string: urlStr) {
            iconView?.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
        } else {
            iconView?.image = UIImage(systemName: "photo")
        }
    }

    // MARK: - 左右显隐（框架调用）
    // bubbleImageLeft/Right 由父类整体控制显隐，子控件不需要单独处理

    override func showLeftOrRight(showRight: Bool) {
        super.showLeftOrRight(showRight: showRight)
    }
}

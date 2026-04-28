//
//  ZWB_CustomXibCell.swift
//  ZWB_NIMSDK
//
//  xib 消息 Cell（type=9902，first=99, second=2）
//  继承 ZWB_BaseCustomCell，makeContentView 从 xib 加载，bindData 纯赋值
//

import UIKit
import SnapKit
import Kingfisher
import NEChatUIKit

class ZWB_CustomXibCell: ZWB_BaseCustomCell {

    // MARK: - xib outlet（xib 实例化时由 coder 注入）

    @IBOutlet weak var iconView:     UIImageView!
    @IBOutlet weak var contentLabel: UILabel!

    // MARK: - 从 xib 加载内容视图

    override func makeContentView() -> UIView {
        // 用 UINib 实例化一份 xib cell（走 init?(coder:)），取其 contentView
        let nib = UINib(nibName: "ZWB_CustomXibCell", bundle: nil)
        guard let cell = nib.instantiate(withOwner: nil, options: nil).first as? ZWB_CustomXibCell else {
            return UIView()
        }
        let view = cell.contentView

        // 覆盖 xib 图片约束，固定高度
        cell.iconView?.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(120)
        }

        // 把 outlet 引用存到 contentView 的 tag，bindData 里通过 tag 取回
        cell.iconView?.tag     = 10
        cell.contentLabel?.tag = 11

        return view
    }

    // MARK: - 纯赋值，不用管 isSend

    override func bindData(to contentView: UIView, attachment: ZWB_BaseCustomAttachment) {
        guard let attachment = attachment as? ZWB_CustomXibAttachment else { return }

        let iconView     = contentView.viewWithTag(10) as? UIImageView
        let contentLabel = contentView.viewWithTag(11) as? UILabel

        contentLabel?.text = attachment.desc ?? ""
        contentLabel?.isHidden = false

        if let urlStr = attachment.picUrl, let url = URL(string: urlStr) {
            iconView?.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
        } else {
            iconView?.image = UIImage(systemName: "photo")
        }
    }
}

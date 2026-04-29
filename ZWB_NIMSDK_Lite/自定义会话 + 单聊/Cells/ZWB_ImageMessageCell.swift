//
//  ZWB_ImageMessageCell.swift
//  ZWB_NIMSDK_Lite
//
//  图片消息气泡（MESSAGE_TYPE_IMAGE）
//  显示：固定 160×160 的图片，异步加载
//

import UIKit
import NIMSDK
import SnapKit

class ZWB_ImageMessageCell: ZWB_BaseChatCell {

    /// TableView 复用标识符
    static let reuseId = "ZWB_ImageMessageCell"

    // MARK: - UI

    /// 图片展示视图
    private let photoView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode     = .scaleAspectFill
        iv.clipsToBounds   = true
        iv.backgroundColor = .systemGray5
        iv.image           = UIImage(systemName: "photo")  // 加载前的占位图
        iv.tintColor       = .systemGray3
        return iv
    }()

    // MARK: - 初始化

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        bubbleView.addSubview(photoView)
        photoView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.height.equalTo(160)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 数据绑定

    /// 绑定消息数据，异步加载图片
    /// - Parameters:
    ///   - message: 云信消息对象，attachment 为 V2NIMMessageImageAttachment
    ///   - isSend: 是否为发送方消息
    func configure(message: V2NIMMessage, isSend: Bool) {
        applyLayout(isSend: isSend)
        bubbleView.backgroundColor = .clear  // 图片消息气泡透明，不显示背景色

        guard let att    = message.attachment as? V2NIMMessageImageAttachment,
              let urlStr = att.url,
              let url    = URL(string: urlStr) else {
            photoView.image = UIImage(systemName: "photo")
            return
        }

        // 异步加载图片
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async { self?.photoView.image = img }
            }
        }.resume()
    }
}

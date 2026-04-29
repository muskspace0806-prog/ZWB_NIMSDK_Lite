//
//  ZWB_ImageMessageCell.swift
//  ZWB_NIMSDK_Lite
//
//  图片消息气泡（MESSAGE_TYPE_IMAGE）
//  显示：固定 160×160 的图片，优先本地路径，兜底远端 URL
//

import UIKit
import NIMSDK
import SnapKit
import Kingfisher

class ZWB_ImageMessageCell: ZWB_BaseChatCell {

    /// TableView 复用标识符
    static let reuseId = "ZWB_ImageMessageCell"

    // MARK: - UI

    /// 图片展示视图
    private let photoView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .systemGray5
        iv.image = UIImage(systemName: "photo")
        iv.tintColor = .systemGray3
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

    /// 绑定消息数据，优先展示本地图片（发送中），无本地路径时再走远端 URL
    /// - Parameters:
    ///   - message: 云信消息对象，attachment 为 V2NIMMessageImageAttachment
    ///   - isSend: 是否为发送方消息
    func configure(message: V2NIMMessage, isSend: Bool) {
        applyLayout(isSend: isSend, senderId: message.senderId ?? "")
        bubbleView.backgroundColor = .clear

        guard let att = message.attachment as? V2NIMMessageImageAttachment else {
            photoView.image = UIImage(systemName: "photo")
            return
        }

        if let localPath = att.path,
           !localPath.isEmpty,
           FileManager.default.fileExists(atPath: localPath),
           let localImage = UIImage(contentsOfFile: localPath) {
            photoView.image = localImage
            return
        }

        if let urlStr = att.url, let url = URL(string: urlStr) {
            photoView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
        } else {
            photoView.image = UIImage(systemName: "photo")
        }
    }
}

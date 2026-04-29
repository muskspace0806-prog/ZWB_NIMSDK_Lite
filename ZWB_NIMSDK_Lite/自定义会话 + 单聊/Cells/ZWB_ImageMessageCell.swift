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
    /// 图片点击回调，回传当前显示图（若已加载）
    var onImageTapped: ((UIImage?) -> Void)?
    /// 当前可用于预览的图片（仅在真实图片加载成功后非空）
    var imageForPreview: UIImage? { hasValidImage ? photoView.image : nil }

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

    private var hasValidImage = false

    // MARK: - 初始化

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        bubbleView.addSubview(photoView)
        photoView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.height.equalTo(160)
        }
        photoView.isUserInteractionEnabled = true
        photoView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(imageTapped)))
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
        hasValidImage = false

        guard let att = message.attachment as? V2NIMMessageImageAttachment else {
            photoView.image = UIImage(systemName: "photo")
            return
        }

        if let localPath = att.path,
           !localPath.isEmpty,
           FileManager.default.fileExists(atPath: localPath),
           let localImage = UIImage(contentsOfFile: localPath) {
            photoView.image = localImage
            hasValidImage = true
            return
        }

        if let urlStr = att.url, let url = URL(string: urlStr) {
            photoView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo")) { [weak self] result in
                switch result {
                case .success:
                    self?.hasValidImage = true
                case .failure:
                    self?.hasValidImage = false
                }
            }
        } else {
            photoView.image = UIImage(systemName: "photo")
        }
    }

    @objc private func imageTapped() {
        onImageTapped?(hasValidImage ? photoView.image : nil)
    }
}

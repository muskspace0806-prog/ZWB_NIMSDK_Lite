//
//  ZWB_DefaultMessageCell.swift
//  ZWB_NIMSDK_Lite
//
//  兜底消息气泡
//  - 语音消息：展示可点击播放样式（图标 + 时长）
//  - 其他类型：显示文本兜底
//

import UIKit
import NIMSDK
import SnapKit

class ZWB_DefaultMessageCell: ZWB_BaseChatCell {

    /// TableView 复用标识符
    static let reuseId = "ZWB_DefaultMessageCell"

    /// 语音消息点击回调
    var onAudioTapped: (() -> Void)?
    /// 当前语音消息 ID（用于外层刷新播放态）
    private(set) var audioMessageId: String?

    // MARK: - UI

    /// 消息类型描述标签（非语音）
    private let typeLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 13)
        lb.textColor = .secondaryLabel
        lb.textAlignment = .center
        return lb
    }()

    private let audioIconView: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "speaker.wave.2.fill"))
        iv.tintColor = UIColor.systemBlue
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let audioDurationLabel: UILabel = {
        let lb = UILabel()
        lb.font = .systemFont(ofSize: 15, weight: .medium)
        lb.textColor = .label
        lb.text = "0\""
        return lb
    }()

    private lazy var audioStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [audioIconView, audioDurationLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        return stack
    }()

    private var normalAudioTintColor: UIColor = .systemBlue
    private var isAudioPlaying = false

    // MARK: - 初始化

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        bubbleView.addSubview(typeLabel)
        bubbleView.addSubview(audioStack)

        typeLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
        }

        audioStack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(10)
            $0.leading.trailing.equalToSuperview().inset(12)
        }
        audioIconView.snp.makeConstraints {
            $0.width.height.equalTo(18)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(audioTapped))
        bubbleView.addGestureRecognizer(tap)
        bubbleView.isUserInteractionEnabled = true

        updateAudioUI(isAudio: false)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 数据绑定

    /// 绑定消息数据，根据消息类型显示对应描述
    /// - Parameters:
    ///   - message: 云信消息对象
    ///   - isSend: 是否为发送方消息
    func configure(message: V2NIMMessage, isSend: Bool) {
        applyLayout(isSend: isSend, senderId: message.senderId ?? "")
        onAudioTapped = nil
        audioMessageId = nil
        setAudioPlaying(false)

        if message.messageType == .MESSAGE_TYPE_AUDIO,
           let att = message.attachment as? V2NIMMessageAudioAttachment {
            updateAudioUI(isAudio: true)
            audioMessageId = message.messageClientId ?? message.messageServerId

            // SDK 音频时长单位为毫秒，转秒展示
            let second = max(1, Int((Double(att.duration) / 1000.0).rounded()))
            audioDurationLabel.text = "\(second)\""

            // 发送方保持绿色气泡，接收方白色气泡
            if isSend {
                audioDurationLabel.textColor = .white
                normalAudioTintColor = .white
            } else {
                audioDurationLabel.textColor = .label
                normalAudioTintColor = .systemBlue
            }
            audioIconView.tintColor = normalAudioTintColor
        } else {
            updateAudioUI(isAudio: false)
            switch message.messageType {
            case .MESSAGE_TYPE_VIDEO:    typeLabel.text = "[视频消息]"
            case .MESSAGE_TYPE_FILE:     typeLabel.text = "[文件消息]"
            case .MESSAGE_TYPE_LOCATION: typeLabel.text = "[位置消息]"
            default:                     typeLabel.text = "[\(message.messageType.rawValue) 类型消息]"
            }
        }
    }

    private func updateAudioUI(isAudio: Bool) {
        audioStack.isHidden = !isAudio
        typeLabel.isHidden = isAudio
    }

    func setAudioPlaying(_ playing: Bool) {
        guard !audioStack.isHidden else { return }
        guard playing != isAudioPlaying else { return }
        isAudioPlaying = playing

        if playing {
            let frames: [UIImage] = ["speaker.wave.1.fill", "speaker.wave.2.fill", "speaker.wave.3.fill"]
                .compactMap { UIImage(systemName: $0)?.withRenderingMode(.alwaysTemplate) }
            audioIconView.animationImages = frames
            audioIconView.animationDuration = 0.8
            audioIconView.tintColor = .systemRed
            audioDurationLabel.textColor = .systemRed
            audioIconView.startAnimating()
        } else {
            audioIconView.stopAnimating()
            audioIconView.animationImages = nil
            audioIconView.image = UIImage(systemName: "speaker.wave.2.fill")?.withRenderingMode(.alwaysTemplate)
            audioIconView.tintColor = normalAudioTintColor
            // 正常态时长颜色跟随图标颜色，发送侧白色，接收侧默认文字色
            audioDurationLabel.textColor = (normalAudioTintColor == .white) ? .white : .label
        }
    }

    @objc private func audioTapped() {
        guard !audioStack.isHidden else { return }
        onAudioTapped?()
    }
}

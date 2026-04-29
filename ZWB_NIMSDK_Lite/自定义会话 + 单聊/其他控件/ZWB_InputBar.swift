//
//  ZWB_InputBar.swift
//  ZWB_NIMSDK_Lite
//
//  聊天输入栏 — 纯自定义 UI，SnapKit 布局
//  支持：
//  1) 多行文本发送（最大 4 行）
//  2) 表情面板切换与插入
//  3) 相册/拍照入口
//  4) 长按语音发送
//

import UIKit
import SnapKit

class ZWB_InputBar: UIView {

    enum VoiceRecordEvent {
        case began
        case ended
        case cancelled
    }

    // MARK: - 回调

    var onSend: ((String) -> Void)?
    var onMediaTapped: (() -> Void)?
    var onVoiceRecordEvent: ((VoiceRecordEvent) -> Void)?

    // MARK: - 常量

    private let minHeight: CGFloat = 56
    private let maxTextLines: CGFloat = 4
    private let hPadding: CGFloat = 12
    private let vPadding: CGFloat = 10
    private let btnSize: CGFloat = 36

    // MARK: - 状态

    private var isVoiceMode = false
    private var isEmojiKeyboard = false

    // MARK: - UI

    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)
        v.layer.borderColor = UIColor.separator.cgColor
        v.layer.borderWidth = 0.5
        return v
    }()

    private let voiceModeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.tintColor = .label
        btn.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        btn.backgroundColor = UIColor.systemGray5
        btn.layer.cornerRadius = 8
        return btn
    }()

    private let emojiButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.tintColor = .label
        btn.setImage(UIImage(systemName: "face.smiling"), for: .normal)
        btn.backgroundColor = UIColor.systemGray5
        btn.layer.cornerRadius = 8
        return btn
    }()

    private let mediaButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.tintColor = .label
        btn.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        btn.backgroundColor = UIColor.systemGray5
        btn.layer.cornerRadius = 8
        return btn
    }()

    private let textView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.backgroundColor = .white
        tv.layer.cornerRadius = 8
        tv.layer.borderColor = UIColor.separator.cgColor
        tv.layer.borderWidth = 0.5
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        tv.isScrollEnabled = false
        return tv
    }()

    private let holdToTalkButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("按住 说话", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        btn.backgroundColor = .white
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth = 0.5
        btn.layer.borderColor = UIColor.separator.cgColor
        btn.setTitleColor(.label, for: .normal)
        btn.isHidden = true
        return btn
    }()

    private let placeholderLabel: UILabel = {
        let lb = UILabel()
        lb.text = "发送消息..."
        lb.font = .systemFont(ofSize: 16)
        lb.textColor = .placeholderText
        lb.isUserInteractionEnabled = false
        return lb
    }()

    private let sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("发送", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.isEnabled = false
        btn.alpha = 0.5
        return btn
    }()

    private lazy var emojiPanel: ZWB_EmojiPanel = {
        let panel = ZWB_EmojiPanel(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 260))
        panel.onEmojiTapped = { [weak self] emoji in
            guard let self = self else { return }
            self.insertTextToInput(emoji)
        }
        panel.onDeleteTapped = { [weak self] in
            guard let self = self else { return }
            self.textView.deleteBackward()
            self.textViewDidChange(self.textView)
        }
        return panel
    }()

    // MARK: - 高度约束

    private var heightConstraint: Constraint?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Public

    func endInputEditing() {
        textView.resignFirstResponder()
        isEmojiKeyboard = false
    }

    // MARK: - 布局

    private func setupUI() {
        backgroundColor = .clear

        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        [voiceModeButton, emojiButton, mediaButton, textView, holdToTalkButton, sendButton].forEach {
            containerView.addSubview($0)
        }
        textView.addSubview(placeholderLabel)

        voiceModeButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(hPadding)
            $0.bottom.equalToSuperview().offset(-vPadding)
            $0.width.height.equalTo(btnSize)
        }

        emojiButton.snp.makeConstraints {
            $0.leading.equalTo(voiceModeButton.snp.trailing).offset(6)
            $0.bottom.equalTo(voiceModeButton)
            $0.width.height.equalTo(btnSize)
        }

        mediaButton.snp.makeConstraints {
            $0.leading.equalTo(emojiButton.snp.trailing).offset(6)
            $0.bottom.equalTo(voiceModeButton)
            $0.width.height.equalTo(btnSize)
        }

        sendButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-hPadding)
            $0.bottom.equalToSuperview().offset(-vPadding)
            $0.width.equalTo(52)
            $0.height.equalTo(btnSize)
        }

        textView.snp.makeConstraints {
            $0.leading.equalTo(mediaButton.snp.trailing).offset(8)
            $0.trailing.equalTo(sendButton.snp.leading).offset(-8)
            $0.top.equalToSuperview().offset(vPadding)
            $0.bottom.equalToSuperview().offset(-vPadding)
        }

        holdToTalkButton.snp.makeConstraints {
            $0.leading.trailing.top.bottom.equalTo(textView)
        }

        placeholderLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(10)
            $0.centerY.equalToSuperview()
        }

        textView.delegate = self
        voiceModeButton.addTarget(self, action: #selector(voiceModeTapped), for: .touchUpInside)
        emojiButton.addTarget(self, action: #selector(emojiTapped), for: .touchUpInside)
        mediaButton.addTarget(self, action: #selector(mediaTapped), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleHoldToTalk(_:)))
        longPress.minimumPressDuration = 0.05
        holdToTalkButton.addGestureRecognizer(longPress)

        snp.makeConstraints {
            heightConstraint = $0.height.equalTo(minHeight).constraint
        }
    }

    // MARK: - 文本发送

    @objc private func sendTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend?(text)
        textView.text = ""
        textViewDidChange(textView)
    }

    // MARK: - 按钮点击

    @objc private func voiceModeTapped() {
        isVoiceMode.toggle()
        updateInputMode(animated: true)
    }

    @objc private func emojiTapped() {
        if isVoiceMode {
            isVoiceMode = false
            updateInputMode(animated: false)
        }

        if !textView.isFirstResponder {
            isEmojiKeyboard = true
            textView.inputView = emojiPanel
            textView.becomeFirstResponder()
            return
        }

        isEmojiKeyboard.toggle()
        textView.inputView = isEmojiKeyboard ? emojiPanel : nil
        textView.reloadInputViews()
    }

    @objc private func mediaTapped() {
        onMediaTapped?()
    }

    // MARK: - 语音长按

    @objc private func handleHoldToTalk(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: holdToTalkButton)
        let isInside = holdToTalkButton.bounds.contains(point)

        switch gesture.state {
        case .began:
            holdToTalkButton.setTitle("松开 发送（上滑取消）", for: .normal)
            holdToTalkButton.backgroundColor = UIColor.systemGray4
            onVoiceRecordEvent?(.began)

        case .changed:
            if isInside {
                holdToTalkButton.setTitle("松开 发送（上滑取消）", for: .normal)
                holdToTalkButton.backgroundColor = UIColor.systemGray4
            } else {
                holdToTalkButton.setTitle("松开 取消", for: .normal)
                holdToTalkButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.15)
            }

        case .ended:
            onVoiceRecordEvent?(isInside ? .ended : .cancelled)
            resetHoldToTalkUI()

        case .cancelled, .failed:
            onVoiceRecordEvent?(.cancelled)
            resetHoldToTalkUI()

        default:
            break
        }
    }

    private func resetHoldToTalkUI() {
        holdToTalkButton.setTitle("按住 说话", for: .normal)
        holdToTalkButton.backgroundColor = .white
    }

    // MARK: - 状态更新

    private func updateInputMode(animated: Bool) {
        textView.isHidden = isVoiceMode
        holdToTalkButton.isHidden = !isVoiceMode
        sendButton.isHidden = isVoiceMode
        placeholderLabel.isHidden = isVoiceMode || !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let imageName = isVoiceMode ? "keyboard" : "mic.fill"
        voiceModeButton.setImage(UIImage(systemName: imageName), for: .normal)

        if isVoiceMode {
            textView.resignFirstResponder()
            isEmojiKeyboard = false
            resetHoldToTalkUI()
        } else {
            textView.becomeFirstResponder()
        }

        updateHeight()

        let updates: () -> Void = { [weak self] in
            self?.superview?.layoutIfNeeded()
        }
        if animated {
            UIView.animate(withDuration: 0.15, animations: updates)
        } else {
            updates()
        }
    }

    private func insertTextToInput(_ text: String) {
        guard let selectedRange = textView.selectedTextRange else {
            textView.text.append(text)
            textViewDidChange(textView)
            return
        }
        textView.replace(selectedRange, withText: text)
        textViewDidChange(textView)
    }

    // MARK: - 动态高度计算

    private func updateHeight() {
        guard !isVoiceMode else {
            heightConstraint?.update(offset: minHeight)
            return
        }

        let maxWidth = textView.bounds.width > 0
            ? textView.bounds.width
            : UIScreen.main.bounds.width - hPadding * 2 - btnSize * 3 - 12 - 52 - 8 - hPadding

        let lineHeight = textView.font?.lineHeight ?? 20
        let maxH = lineHeight * maxTextLines + textView.textContainerInset.top + textView.textContainerInset.bottom

        let fittingSize = textView.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let textH = min(fittingSize.height, maxH)

        textView.isScrollEnabled = fittingSize.height > maxH

        let newBarH = textH + vPadding * 2
        let targetH = max(minHeight, newBarH)
        heightConstraint?.update(offset: targetH)
    }
}

// MARK: - UITextViewDelegate

extension ZWB_InputBar: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        let isEmpty = textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        placeholderLabel.isHidden = !isEmpty
        sendButton.isEnabled = !isEmpty
        sendButton.alpha = isEmpty ? 0.5 : 1.0
        updateHeight()

        UIView.animate(withDuration: 0.15) {
            self.superview?.layoutIfNeeded()
        }
    }
}

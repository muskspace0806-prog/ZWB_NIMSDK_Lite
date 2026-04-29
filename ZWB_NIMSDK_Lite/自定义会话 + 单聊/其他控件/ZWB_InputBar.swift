//
//  ZWB_InputBar.swift
//  ZWB_NIMSDK_Lite
//
//  聊天输入栏 — 纯自定义 UI，SnapKit 布局
//  支持多行自动扩高（最大 4 行），发送回调 onSend
//

import UIKit
import SnapKit

class ZWB_InputBar: UIView {

    // MARK: - 回调

    var onSend: ((String) -> Void)?

    // MARK: - 常量

    private let minHeight:    CGFloat = 56
    private let maxTextLines: CGFloat = 4
    private let hPadding:     CGFloat = 12
    private let vPadding:     CGFloat = 10
    private let btnSize:      CGFloat = 36

    // MARK: - UI

    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)
        v.layer.borderColor = UIColor.separator.cgColor
        v.layer.borderWidth = 0.5
        return v
    }()

    private let textView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.backgroundColor = .white
        tv.layer.cornerRadius = 8
        tv.layer.borderColor = UIColor.separator.cgColor
        tv.layer.borderWidth = 0.5
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        tv.isScrollEnabled = false   // 先关闭，内容超过 maxLines 再开启
        return tv
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

    // MARK: - 高度约束（外部 SnapKit 约束通过此属性更新）

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

    // MARK: - 布局

    private func setupUI() {
        backgroundColor = .clear

        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        containerView.addSubview(textView)
        containerView.addSubview(sendButton)
        textView.addSubview(placeholderLabel)

        sendButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-hPadding)
            $0.bottom.equalToSuperview().offset(-vPadding)
            $0.width.equalTo(52)
            $0.height.equalTo(btnSize)
        }

        textView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(hPadding)
            $0.trailing.equalTo(sendButton.snp.leading).offset(-8)
            $0.top.equalToSuperview().offset(vPadding)
            $0.bottom.equalToSuperview().offset(-vPadding)
        }

        placeholderLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(10)
            $0.centerY.equalToSuperview()
        }

        textView.delegate = self
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        // 初始高度约束，后续由 updateHeight() 动态更新
        snp.makeConstraints {
            heightConstraint = $0.height.equalTo(minHeight).constraint
        }
    }

    // MARK: - 发送

    @objc private func sendTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend?(text)
        textView.text = ""
        textViewDidChange(textView)
    }

    // MARK: - 动态高度计算

    private func updateHeight() {
        let maxWidth = textView.bounds.width > 0
            ? textView.bounds.width
            : UIScreen.main.bounds.width - hPadding * 2 - 52 - 8 - hPadding

        let lineHeight = textView.font?.lineHeight ?? 20
        let maxH = lineHeight * maxTextLines + textView.textContainerInset.top + textView.textContainerInset.bottom

        let fittingSize = textView.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let textH = min(fittingSize.height, maxH)

        textView.isScrollEnabled = fittingSize.height > maxH

        let newBarH = textH + vPadding * 2
        let targetH = max(minHeight, newBarH)

        // 更新自身高度约束
        heightConstraint?.update(offset: targetH)

        UIView.animate(withDuration: 0.15) {
            self.superview?.layoutIfNeeded()
        }
    }
}

// MARK: - UITextViewDelegate

extension ZWB_InputBar: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        let isEmpty = textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        placeholderLabel.isHidden = !isEmpty ? true : false
        sendButton.isEnabled = !isEmpty
        sendButton.alpha = isEmpty ? 0.5 : 1.0
        updateHeight()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // 拦截硬件键盘回车键发送（软键盘不拦截，允许换行）
        return true
    }
}

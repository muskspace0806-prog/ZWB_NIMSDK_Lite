//
//  ZWB_EmojiPanel.swift
//  ZWB_NIMSDK_Lite
//
//  表情面板
//  展示系统 emoji，点击后通过回调插入到输入框
//

import UIKit
import SnapKit

class ZWB_EmojiPanel: UIView {

    // MARK: - 回调

    /// 点击表情回调，返回 emoji 字符串
    var onEmojiTapped: ((String) -> Void)?
    /// 点击删除按钮回调
    var onDeleteTapped: (() -> Void)?

    // MARK: - 数据

    /// 常用 emoji 列表
    private let emojis: [String] = [
        "😀","😃","😄","😁","😆","😅","🤣","😂","🙂","🙃",
        "😉","😊","😇","🥰","😍","🤩","😘","😗","😚","😙",
        "😋","😛","😜","🤪","😝","🤑","🤗","🤭","🤫","🤔",
        "🤐","🤨","😐","😑","😶","😏","😒","🙄","😬","🤥",
        "😌","😔","😪","🤤","😴","😷","🤒","🤕","🤢","🤧",
        "🥵","🥶","🥴","😵","🤯","🤠","🥳","😎","🤓","🧐",
        "😕","😟","🙁","☹️","😮","😯","😲","😳","🥺","😦",
        "😧","😨","😰","😥","😢","😭","😱","😖","😣","😞",
        "😓","😩","😫","🥱","😤","😡","😠","🤬","😈","👿",
        "💀","☠️","💩","🤡","👹","👺","👻","👽","👾","🤖",
        "👋","🤚","🖐","✋","🖖","👌","🤌","🤏","✌️","🤞",
        "🤟","🤘","🤙","👈","👉","👆","🖕","👇","☝️","👍",
        "👎","✊","👊","🤛","🤜","👏","🙌","👐","🤲","🤝",
        "🙏","✍️","💅","🤳","💪","🦾","🦿","🦵","🦶","👂"
    ]

    // MARK: - UI

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 4
        layout.minimumLineSpacing      = 4
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.delegate        = self
        cv.dataSource      = self
        cv.register(ZWB_EmojiCell.self, forCellWithReuseIdentifier: "EmojiCell")
        return cv
    }()

    private let deleteButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "delete.left"), for: .normal)
        btn.tintColor       = .label
        btn.backgroundColor = UIColor.systemGray5
        btn.layer.cornerRadius = 6
        return btn
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        addSubview(collectionView)
        addSubview(deleteButton)

        deleteButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-12)
            $0.bottom.equalToSuperview().offset(-12)
            $0.width.equalTo(52)
            $0.height.equalTo(36)
        }

        collectionView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.leading.equalToSuperview().offset(8)
            $0.trailing.equalToSuperview().offset(-8)
            $0.bottom.equalTo(deleteButton.snp.top).offset(-8)
        }

        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
    }

    @objc private func deleteTapped() {
        onDeleteTapped?()
    }
}

// MARK: - UICollectionViewDataSource & Delegate

extension ZWB_EmojiPanel: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return emojis.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCell", for: indexPath) as! ZWB_EmojiCell
        cell.configure(emoji: emojis[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 4 * 9) / 8  // 每行 8 个
        return CGSize(width: width, height: width)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onEmojiTapped?(emojis[indexPath.item])
    }
}

// MARK: - Emoji Cell

private class ZWB_EmojiCell: UICollectionViewCell {

    private let label: UILabel = {
        let lb = UILabel()
        lb.font          = .systemFont(ofSize: 26)
        lb.textAlignment = .center
        return lb
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(label)
        label.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(emoji: String) {
        label.text = emoji
    }
}

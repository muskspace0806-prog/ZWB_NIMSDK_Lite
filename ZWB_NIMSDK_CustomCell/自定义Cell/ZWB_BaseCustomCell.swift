//
//  ZWB_BaseCustomCell.swift
//  ZWB_NIMSDK
//
//  自定义消息 Cell 基类
//
//  解决的问题：
//  每个自定义 Cell 都要维护左右两套控件，setModel 里写 isSend ? right : left 选控件。
//  这套模板代码与业务无关，抽到基类统一处理。
//
//  子类只需做两件事：
//  1. 实现 makeContentView() → 创建并返回一个内容视图（纯代码或 xib 均可）
//  2. 实现 bindData(to:attachment:) → 拿到当前方向的内容视图，直接赋值，不用管左右
//
//  基类负责：
//  - 左右各实例化一份内容视图，分别嵌入 bubbleImageLeft / bubbleImageRight
//  - setModel 里根据 isSend 选出正确的内容视图，传给 bindData
//  - contentSize 保底（避免气泡高度为 0）
//  - showLeftOrRight 由父类 bubbleImage 整体控制，基类不干预子控件
//

import UIKit
import SnapKit
import NEChatUIKit
import NECoreIM2Kit

class ZWB_BaseCustomCell: NEBaseChatMessageCell {

    // MARK: - 左右内容视图

    private var contentViewLeft:  UIView?
    private var contentViewRight: UIView?

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupBothSides()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - 子类必须实现

    /// 创建一份内容视图（纯代码或 xib 均可）
    /// 基类会调用两次，分别作为左右气泡的内容
    func makeContentView() -> UIView {
        fatalError("子类必须实现 makeContentView()")
    }

    /// 纯赋值：拿到当前方向的内容视图，直接操作控件，不用管 isSend
    /// - Parameters:
    ///   - contentView: 当前方向（发送/接收）的内容视图
    ///   - attachment: 已解析好的 attachment，直接取字段赋值
    func bindData(to contentView: UIView, attachment: ZWB_BaseCustomAttachment) {
        // 子类 override 实现
    }

    /// 子类可 override，返回气泡内容尺寸（默认 width=230，height 由 attachment.cellHeight() 决定）
    func contentSize(for attachment: ZWB_BaseCustomAttachment) -> CGSize {
        return CGSize(width: 230, height: attachment.cellHeight())
    }

    // MARK: - 基类内部逻辑

    private func setupBothSides() {
        let left  = makeContentView()
        let right = makeContentView()

        embed(left,  into: bubbleImageLeft)
        embed(right, into: bubbleImageRight)

        contentViewLeft  = left
        contentViewRight = right
    }

    private func embed(_ view: UIView, into container: UIView) {
        container.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - setModel（框架调用，子类不需要 override）

    override func setModel(_ model: MessageContentModel, _ isSend: Bool) {
        // contentSize 保底，对齐框架的 height 计算公式
        if let attachment = model.message?.attachment as? ZWB_BaseCustomAttachment,
           model.contentSize.width == 0 {
            let size = contentSize(for: attachment)
            model.contentSize = size
            // 对齐框架公式：contentHeight + 上下边距 + 昵称高度 + pin标记高度
            model.height = size.height
                         + chat_content_margin * 2   // 气泡上下内边距 8+8
                         + model.fullNameHeight       // 群聊昵称（p2p=0）
                         + chat_pin_height            // pin 标记 16
            // 有时间戳时额外加时间戳高度
            if let time = model.timeContent, !time.isEmpty {
                model.height += chat_timeCellH
            }
        }

        super.setModel(model, isSend)

        guard let attachment = model.message?.attachment as? ZWB_BaseCustomAttachment,
              let activeView = isSend ? contentViewRight : contentViewLeft else { return }

        bindData(to: activeView, attachment: attachment)
    }

    // MARK: - showLeftOrRight（bubbleImage 整体控制，不干预子控件）

    override func showLeftOrRight(showRight: Bool) {
        super.showLeftOrRight(showRight: showRight)
    }
}

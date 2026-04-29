//
//  ZWB_TimeCell.swift
//  ZWB_NIMSDK_Lite
//
//  时间戳 Cell
//  在消息列表中居中显示时间，无头像无气泡
//  由 ZWB_ChatViewController.buildChatItems() 按需插入
//

import UIKit
import SnapKit

class ZWB_TimeCell: UITableViewCell {

    /// TableView 复用标识符
    static let reuseId = "ZWB_TimeCell"

    // MARK: - UI

    /// 时间文字标签，带半透明圆角背景
    private let timeLabel: UILabel = {
        let lb = UILabel()
        lb.font            = .systemFont(ofSize: 11)
        lb.textColor       = UIColor(white: 0.3, alpha: 1)
        lb.textAlignment   = .center
        lb.backgroundColor = UIColor(white: 0, alpha: 0.08)
        lb.layer.cornerRadius = 4   // 小圆角，不要太大
        lb.clipsToBounds   = true
        return lb
    }()

    // MARK: - 初始化

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle  = .none

        contentView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(6)
            $0.bottom.equalToSuperview().offset(-6)
        }
        // 让 label 宽度由文字内容撑开，不拉伸
//        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
//        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 数据绑定

    /// 绑定时间戳，格式化后显示
    /// - Parameter timestamp: 消息创建时间（秒级 NSTimeInterval）
    func configure(timestamp: TimeInterval) {
        timeLabel.text = "\(formatTime(timestamp))"  // 左右空格作为内边距
    }

    // MARK: - 时间格式化

    /// 将秒级时间戳格式化为可读字符串
    /// - 今天：HH:mm
    /// - 昨天：昨天 HH:mm
    /// - 今年内：MM-dd HH:mm
    /// - 更早：yyyy-MM-dd HH:mm
    private func formatTime(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)  // createTime 是秒级，直接用
        let cal  = Calendar.current
        let fmt  = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")

        if cal.isDateInToday(date) {
            fmt.dateFormat = "HH:mm"
        } else if cal.isDateInYesterday(date) {
            fmt.dateFormat = "'昨天' HH:mm"
        } else if cal.isDate(date, equalTo: Date(), toGranularity: .year) {
            fmt.dateFormat = "MM-dd HH:mm"
        } else {
            fmt.dateFormat = "yyyy-MM-dd HH:mm"
        }
        return fmt.string(from: date)
    }
}

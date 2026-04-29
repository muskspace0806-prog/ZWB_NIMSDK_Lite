//
//  ZWB_ConversationListViewController.swift
//  ZWB_NIMSDK_Lite
//
//  本地会话模式（enableV2CloudConversation = NO）
//  必须使用 v2LocalConversationService，不能用 v2ConversationService
//

import UIKit
import NIMSDK
import SnapKit

// MARK: - 会话数据模型

struct ZWB_ConversationItem {
    let conversationId: String
    let name: String
    let avatarUrl: String?
    let lastMessage: String
    let lastTime: String
    let unreadCount: Int
}

// MARK: - ViewController

class ZWB_ConversationListViewController: UIViewController {

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.delegate           = self
        tv.dataSource         = self
        tv.rowHeight          = UITableView.automaticDimension
        tv.estimatedRowHeight = 68
        tv.separatorInset     = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 0)
        tv.register(ZWB_ConversationCell.self, forCellReuseIdentifier: ZWB_ConversationCell.reuseId)
        return tv
    }()

    private lazy var logoutButton: UIBarButtonItem = {
        UIBarButtonItem(title: "退出", style: .plain, target: self, action: #selector(logoutAction))
    }()

    private var items: [ZWB_ConversationItem] = []

    // MARK: 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息"
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = logoutButton

        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }

        // 注册本地会话监听（onSyncFinished 后拉取数据）
        NIMSDK.shared().v2LocalConversationService.add(self)
    }

    deinit {
        NIMSDK.shared().v2LocalConversationService.remove(self)
    }

    // MARK: 加载会话列表

    func loadConversations() {
        NIMSDK.shared().v2LocalConversationService.getConversationList(0, limit: 100) { [weak self] result in
            guard let self = self else { return }
            self.items = (result.conversationList ?? []).map { self.makeItem(from: $0) }
            DispatchQueue.main.async { self.tableView.reloadData() }
        } failure: { error in
            print("[ZWB_Conv] 加载失败: \(error.desc ?? "")")
        }
    }

    // MARK: 构建 Item

    private func makeItem(from conv: V2NIMLocalConversation) -> ZWB_ConversationItem {
        ZWB_ConversationItem(
            conversationId: conv.conversationId,
            name:           conv.name ?? conv.conversationId,
            avatarUrl:      conv.avatar,
            lastMessage:    lastMessageText(conv.lastMessage),
            lastTime:       formatTime(conv.lastMessage?.messageRefer.createTime ?? 0),
            unreadCount:    conv.unreadCount
        )
    }

    private func lastMessageText(_ msg: V2NIMLastMessage?) -> String {
        guard let msg = msg else { return "" }
        switch msg.messageType {
        case .MESSAGE_TYPE_TEXT:   return msg.text ?? ""
        case .MESSAGE_TYPE_IMAGE:  return "[图片]"
        case .MESSAGE_TYPE_AUDIO:  return "[语音]"
        case .MESSAGE_TYPE_VIDEO:  return "[视频]"
        case .MESSAGE_TYPE_FILE:   return "[文件]"
        case .MESSAGE_TYPE_CUSTOM: return "[自定义消息]"
        default:                   return "[消息]"
        }
    }

    private func formatTime(_ timestamp: TimeInterval) -> String {
        guard timestamp > 0 else { return "" }
        let date = Date(timeIntervalSince1970: timestamp)  // createTime 是秒级，直接用
        let cal  = Calendar.current
        let fmt  = DateFormatter()
        if cal.isDateInToday(date) {
            fmt.dateFormat = "HH:mm"
        } else if cal.isDateInYesterday(date) {
            return "昨天"
        } else {
            fmt.dateFormat = "MM/dd"
        }
        return fmt.string(from: date)
    }

    @objc private func logoutAction() {
        ZWB_IMManager.shared.logout { [weak self] _ in
            DispatchQueue.main.async {
                UserDefaults.standard.removeObject(forKey: "zwb_account")
                UserDefaults.standard.removeObject(forKey: "zwb_token")
                guard let window = UIApplication.shared.windows.first else { return }
                let nav = UINavigationController(rootViewController: ZWB_LoginViewController())
                window.rootViewController = nav
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
            }
        }
    }
}

// MARK: - V2NIMLocalConversationListener
// onSyncFinished 之后才能安全操作会话数据

extension ZWB_ConversationListViewController: V2NIMLocalConversationListener {

    // 同步开始
    func onSyncStarted() {
        print("[ZWB_Conv] 会话同步开始")
    }

    // 同步完成 — 此时可以拉取会话列表
    func onSyncFinished() {
        print("[ZWB_Conv] 会话同步完成，开始拉取列表")
        DispatchQueue.main.async { self.loadConversations() }
    }

    // 同步失败 — 仍可操作已有数据
    func onSyncFailed(_ error: V2NIMError) {
        print("[ZWB_Conv] 会话同步失败: \(error.desc ?? "")")
        DispatchQueue.main.async { self.loadConversations() }
    }

    // 新会话创建
    func onConversationCreated(_ conversation: V2NIMLocalConversation) {
        DispatchQueue.main.async { self.loadConversations() }
    }

    // 会话变更（新消息、已读等）
    func onConversationChanged(_ conversationList: [V2NIMLocalConversation]) {
        DispatchQueue.main.async { self.loadConversations() }
    }

    // 会话删除
    func onConversationDeleted(_ conversationIds: [String]) {
        DispatchQueue.main.async { self.loadConversations() }
    }

    func onTotalUnreadCountChanged(_ unreadCount: Int) {}
}

// MARK: - UITableViewDataSource & Delegate

extension ZWB_ConversationListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ZWB_ConversationCell.reuseId, for: indexPath) as! ZWB_ConversationCell
        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        navigationController?.pushViewController(
            ZWB_ChatViewController(conversationId: item.conversationId, title: item.name),
            animated: true
        )
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let convId = items[indexPath.row].conversationId
        NIMSDK.shared().v2LocalConversationService.deleteConversation(convId, clearMessage: false) { [weak self] in
            guard let self = self else { return }
            self.items.remove(at: indexPath.row)
            DispatchQueue.main.async {
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
            }
        } failure: { error in
            print("[ZWB_Conv] 删除失败: \(error.desc ?? "")")
        }
    }
}


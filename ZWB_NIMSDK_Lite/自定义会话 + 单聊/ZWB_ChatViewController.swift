//
//  ZWB_ChatViewController.swift
//  ZWB_NIMSDK_Lite
//
//  单聊页面 — 纯自定义 UI
//  数据：V2NIMMessageService（云信 API）收发消息、拉取历史
//  UI：完全自己写，不依赖任何 UIKit pod
//

import UIKit
import NIMSDK
import SnapKit

class ZWB_ChatViewController: UIViewController {

    // MARK: - 属性

    private let conversationId: String
    private var messages: [V2NIMMessage] = []
    private var isLoadingMore = false

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.delegate        = self
        tv.dataSource      = self
        tv.separatorStyle  = .none
        tv.backgroundColor = UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1)
        tv.keyboardDismissMode = .interactive
        tv.register(ZWB_TextMessageCell.self,   forCellReuseIdentifier: ZWB_TextMessageCell.reuseId)
        tv.register(ZWB_ImageMessageCell.self,  forCellReuseIdentifier: ZWB_ImageMessageCell.reuseId)
        tv.register(ZWB_CustomMessageCell.self, forCellReuseIdentifier: ZWB_CustomMessageCell.reuseId)
        tv.register(ZWB_DefaultMessageCell.self,forCellReuseIdentifier: ZWB_DefaultMessageCell.reuseId)
        return tv
    }()

    private lazy var inputBar: ZWB_InputBar = {
        let bar = ZWB_InputBar()
        bar.onSend = { [weak self] text in self?.sendText(text) }
        return bar
    }()

    private var inputBarBottom: Constraint?

    // MARK: - Init

    init(conversationId: String, title: String = "") {
        self.conversationId = conversationId
        super.init(nibName: nil, bundle: nil)
        self.title = title.isEmpty ? conversationId : title
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1)
        setupUI()
        setupKeyboardObservers()
        addMessageListener()

        // 检查主数据是否已同步，已同步直接拉，否则等 onDataSync
        let alreadySynced = NIMSDK.shared().v2LoginService.getDataSync()?
            .first(where: { $0.type.rawValue == 1 })?
            .state.rawValue == 3
        if alreadySynced {
            loadHistory()
            markAsRead()
        } else {
            // 数据未同步完成，稍等后重试（聊天页一般在登录后才进入，通常已同步）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.loadHistory()
                self?.markAsRead()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        markAsRead()
    }

    deinit {
        NIMSDK.shared().v2MessageService.remove(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - UI 搭建

    private func setupUI() {
        view.addSubview(tableView)
        view.addSubview(inputBar)

        inputBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            inputBarBottom = $0.bottom.equalTo(view.safeAreaLayoutGuide).constraint
            // 高度由 ZWB_InputBar 内部根据文字行数自动撑开，最小 56pt
        }
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(inputBar.snp.top)
        }
    }

    // MARK: - 键盘处理

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let info = note.userInfo,
              let endFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }

        let keyboardHeight = max(0, UIScreen.main.bounds.height - endFrame.origin.y)
        let safeBottom = view.safeAreaInsets.bottom
        let offset = keyboardHeight > 0 ? -(keyboardHeight - safeBottom) : 0

        UIView.animate(withDuration: duration) {
            self.inputBarBottom?.update(offset: offset)
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.scrollToBottom(animated: false)
        }
    }

    // MARK: - 加载历史消息

    private func loadHistory() {
        let option = V2NIMMessageListOption()
        option.conversationId = conversationId
        option.limit          = 100
        option.direction      = .QUERY_DIRECTION_DESC  // 从最新往旧，拿到后 reversed()
        option.onlyQueryLocal = false                  // 必须 false，否则新账号本地无数据

        NIMSDK.shared().v2MessageService.getMessageList(option) { [weak self] result in
            guard let self = self else { return }
            self.messages = result.reversed()
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.scrollToBottom(animated: false)
            }
        } failure: { error in
            print("[ZWB_Chat] 加载历史失败: \(error.desc ?? "")")
        }
    }

    // MARK: - 监听新消息

    private func addMessageListener() {
        NIMSDK.shared().v2MessageService.add(self)
    }

    // MARK: - 标记已读

    private func markAsRead() {
        NIMSDK.shared().v2LocalConversationService.markConversationRead(conversationId) { _ in
        } failure: { _ in }
    }

    // MARK: - 发送文本消息

    private func sendText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let params  = V2NIMSendMessageParams()
        let message = V2NIMMessageCreator.createTextMessage(trimmed)

        NIMSDK.shared().v2MessageService.send(
            message,
            conversationId: conversationId,
            params: params
        ) { [weak self] result in
            guard let msg = result.message else { return }
            DispatchQueue.main.async { self?.appendMessage(msg) }
        } failure: { error in
            print("[ZWB_Chat] 发送失败: \(error)")
        } progress: { _ in }
    }

    // MARK: - 追加消息到列表

    private func appendMessage(_ msg: V2NIMMessage) {
        messages.append(msg)
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.insertRows(at: [indexPath], with: .bottom)
        scrollToBottom(animated: true)
    }

    // MARK: - 滚动到底部

    private func scrollToBottom(animated: Bool) {
        guard messages.count > 0 else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension ZWB_ChatViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = messages[indexPath.row]
        let isSend = msg.senderId == ZWB_IMManager.shared.currentAccount

        switch msg.messageType {
        case .MESSAGE_TYPE_TEXT:
            let cell = tableView.dequeueReusableCell(withIdentifier: ZWB_TextMessageCell.reuseId, for: indexPath) as! ZWB_TextMessageCell
            cell.configure(message: msg, isSend: isSend)
            return cell
        case .MESSAGE_TYPE_IMAGE:
            let cell = tableView.dequeueReusableCell(withIdentifier: ZWB_ImageMessageCell.reuseId, for: indexPath) as! ZWB_ImageMessageCell
            cell.configure(message: msg, isSend: isSend)
            return cell
        case .MESSAGE_TYPE_CUSTOM:
            let cell = tableView.dequeueReusableCell(withIdentifier: ZWB_CustomMessageCell.reuseId, for: indexPath) as! ZWB_CustomMessageCell
            cell.configure(message: msg, isSend: isSend)
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: ZWB_DefaultMessageCell.reuseId, for: indexPath) as! ZWB_DefaultMessageCell
            cell.configure(message: msg, isSend: isSend)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// MARK: - V2NIMMessageListener

extension ZWB_ChatViewController: V2NIMMessageListener {

    @objc func onReceive(_ messages: [V2NIMMessage]) {
        let filtered = messages.filter { $0.conversationId == self.conversationId }
        guard !filtered.isEmpty else { return }
        DispatchQueue.main.async {
            filtered.forEach { self.appendMessage($0) }
            self.markAsRead()
        }
    }

    @objc func onSend(_ message: V2NIMMessage) {
        // 发送状态更新，可在此刷新对应 cell
    }

    @objc func onMessageRevokeNotifications(_ revokeNotifications: [V2NIMMessageRevokeNotification]) {
        DispatchQueue.main.async { self.loadHistory() }
    }

    @objc func onMessageDeletedNotifications(_ messageDeletedNotifications: [V2NIMMessageDeletedNotification]) {
        DispatchQueue.main.async { self.loadHistory() }
    }
}

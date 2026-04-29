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
import TZImagePickerController

// MARK: - 列表数据项枚举

/// 消息列表的数据单元，区分普通消息和时间戳占位
enum ZWB_ChatItem {
    /// 普通消息
    case message(V2NIMMessage)
    /// 时间戳占位（毫秒级时间戳），相邻消息超过阈值时插入
    case timestamp(TimeInterval)
}

// MARK: - ZWB_ChatViewController

class ZWB_ChatViewController: UIViewController {

    // MARK: - 属性

    /// 当前会话 ID
    private let conversationId: String

    /// 列表数据源，包含消息和时间戳占位
    private var items: [ZWB_ChatItem] = []

    /// 相邻消息超过此时间差（秒）则插入时间戳，默认 5 分钟
    private let timestampThreshold: TimeInterval = 5 * 60

    /// 语音录制器
    private let voiceRecorder = ZWB_VoiceRecorder()

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.separatorStyle = .none
        tv.backgroundColor = UIColor(red: 0.94, green: 0.94, blue: 0.96, alpha: 1)
        tv.keyboardDismissMode = .interactive
        // 注册所有消息 Cell 类型
        tv.register(ZWB_TimeCell.self, forCellReuseIdentifier: ZWB_TimeCell.reuseId)
        tv.register(ZWB_TextMessageCell.self, forCellReuseIdentifier: ZWB_TextMessageCell.reuseId)
        tv.register(ZWB_ImageMessageCell.self, forCellReuseIdentifier: ZWB_ImageMessageCell.reuseId)
        tv.register(ZWB_ImageTextCell.self, forCellReuseIdentifier: ZWB_ImageTextCell.reuseId)
        tv.register(ZWB_CustomCell.self, forCellReuseIdentifier: ZWB_CustomCell.reuseId)
        tv.register(ZWB_DefaultMessageCell.self, forCellReuseIdentifier: ZWB_DefaultMessageCell.reuseId)
        return tv
    }()

    private lazy var inputBar: ZWB_InputBar = {
        let bar = ZWB_InputBar()
        bar.onSend = { [weak self] text in self?.sendText(text) }
        bar.onMediaTapped = { [weak self] in self?.presentMediaSheet() }
        bar.onVoiceRecordEvent = { [weak self] event in self?.handleVoiceRecord(event) }
        return bar
    }()

    /// inputBar 底部约束，键盘弹出时动态更新
    private var inputBarBottom: Constraint?

    // MARK: - Init

    /// - Parameters:
    ///   - conversationId: 云信会话 ID
    ///   - title: 导航栏标题，默认显示 conversationId
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
        setupVoiceRecorder()
        addMessageListener()

        // 检查主数据是否已同步（V2NIM_DATA_SYNC_TYPE_MAIN=1, V2NIM_DATA_SYNC_STATE_COMPLETED=3）
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
        if voiceRecorder.isRecording {
            voiceRecorder.cancelRecording()
        }
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
            // 高度由 ZWB_InputBar 内部根据输入模式自动撑开，最小 56pt
        }
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(inputBar.snp.top)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTableTap))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }

    @objc private func handleTableTap() {
        inputBar.endInputEditing()
    }

    // MARK: - 键盘处理

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
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

    // MARK: - 语音录制

    private func setupVoiceRecorder() {
        voiceRecorder.onFinished = { [weak self] result in
            self?.sendAudio(filePath: result.filePath, duration: result.duration)
        }
        voiceRecorder.onFailed = { [weak self] msg in
            self?.showHint(msg)
        }
    }

    private func handleVoiceRecord(_ event: ZWB_InputBar.VoiceRecordEvent) {
        switch event {
        case .began:
            voiceRecorder.startRecording()
        case .ended:
            voiceRecorder.stopRecording()
        case .cancelled:
            voiceRecorder.cancelRecording()
        }
    }

    // MARK: - 时间戳插入逻辑

    /// 将消息数组转换为含时间戳占位的 ZWB_ChatItem 数组
    /// 相邻两条消息时间差超过 timestampThreshold 时，在前一条消息后插入时间戳
    /// - Parameter messages: 按时间正序排列的消息数组
    /// - Returns: 插入时间戳后的数据源数组
    private func buildChatItems(from messages: [V2NIMMessage]) -> [ZWB_ChatItem] {
        var result: [ZWB_ChatItem] = []
        var lastTimestamp: TimeInterval = 0

        for msg in messages {
            // createTime 是秒级 NSTimeInterval，直接与阈值比较
            let t = msg.createTime
            if t - lastTimestamp > timestampThreshold {
                result.append(.timestamp(msg.createTime))
                lastTimestamp = t
            }
            result.append(.message(msg))
        }
        return result
    }

    // MARK: - 加载历史消息

    private func loadHistory() {
        let option = V2NIMMessageListOption()
        option.conversationId = conversationId
        option.limit = 100
        option.direction = .QUERY_DIRECTION_DESC  // 从最新往旧，拿到后 reversed()
        option.onlyQueryLocal = false             // 必须 false，否则新账号本地无数据

        NIMSDK.shared().v2MessageService.getMessageList(option) { [weak self] result in
            guard let self = self else { return }
            // SDK 返回从新到旧，reversed() 后变为时间正序
            self.items = self.buildChatItems(from: result.reversed())
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

        let params = V2NIMSendMessageParams()
        let message = V2NIMMessageCreator.createTextMessage(trimmed)

        NIMSDK.shared().v2MessageService.send(
            message,
            conversationId: conversationId,
            params: params
        ) { [weak self] result in
            guard let msg = result.message else { return }
            DispatchQueue.main.async { self?.appendMessage(msg) }
        } failure: { error in
            print("[ZWB_Chat] 发送文本失败: \(error.desc ?? "")")
        } progress: { _ in }
    }

    // MARK: - 发送图片消息

    private func sendImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.88) else {
            showHint("图片处理失败")
            return
        }

        let fileName = "img_\(Int(Date().timeIntervalSince1970)).jpg"
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent(fileName)

        do {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
            showHint("图片保存失败")
            return
        }

        let width = Int32(max(1, Int(image.size.width)))
        let height = Int32(max(1, Int(image.size.height)))
        let scene = V2NIMStorageSceneConfig.default_IM().sceneName
        let message = V2NIMMessageCreator.createImageMessage(path,
                                                             name: fileName,
                                                             sceneName: scene,
                                                             width: width,
                                                             height: height)
        let params = V2NIMSendMessageParams()

        NIMSDK.shared().v2MessageService.send(
            message,
            conversationId: conversationId,
            params: params
        ) { [weak self] result in
            guard let msg = result.message else { return }
            DispatchQueue.main.async { self?.appendMessage(msg) }
        } failure: { [weak self] error in
            self?.showHint("发送图片失败: \(error.desc ?? "")")
        } progress: { _ in }
    }

    // MARK: - 发送语音消息

    private func sendAudio(filePath: String, duration: Int) {
        let fileName = (filePath as NSString).lastPathComponent
        let scene = V2NIMStorageSceneConfig.default_IM().sceneName
        let message = V2NIMMessageCreator.createAudioMessage(filePath,
                                                             name: fileName,
                                                             sceneName: scene,
                                                             duration: Int32(duration))
        let params = V2NIMSendMessageParams()

        NIMSDK.shared().v2MessageService.send(
            message,
            conversationId: conversationId,
            params: params
        ) { [weak self] result in
            guard let msg = result.message else { return }
            DispatchQueue.main.async { self?.appendMessage(msg) }
        } failure: { [weak self] error in
            self?.showHint("发送语音失败: \(error.desc ?? "")")
        } progress: { _ in }
    }

    // MARK: - 图片/拍照入口

    private func presentMediaSheet() {
        inputBar.endInputEditing()

        let alert = UIAlertController(title: "发送图片", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "从相册选择", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        })

        alert.addAction(UIAlertAction(title: "拍照", style: .default) { [weak self] _ in
            self?.presentImagePicker(source: .camera)
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = inputBar
            popover.sourceRect = inputBar.bounds
            popover.permittedArrowDirections = .down
        }

        present(alert, animated: true)
    }

    private func presentPhotoPicker() {
        let picker = TZImagePickerController(maxImagesCount: 1, delegate: nil)
        picker?.allowPickingVideo = false
        picker?.allowPickingGif = false
        picker?.allowCrop = false
        picker?.showSelectBtn = false
        picker?.allowPreview = false
        picker?.autoDismiss = true
        picker?.allowTakePicture = false
        picker?.didFinishPickingPhotosHandle = { [weak self] photos, _, _ in
            guard let self = self else { return }
            guard let image = photos?.first else {
                self.showHint("未获取到图片")
                return
            }
            self.sendImage(image)
        }
        if let picker = picker {
            present(picker, animated: true)
        }
    }

    private func presentImagePicker(source: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(source) else {
            showHint("当前设备不支持相机")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = self
        picker.allowsEditing = false
        present(picker, animated: true)
    }

    // MARK: - 追加新消息到列表末尾

    /// 收到新消息或发送成功后调用，判断是否需要先插入时间戳
    private func appendMessage(_ msg: V2NIMMessage) {
        var newItems: [ZWB_ChatItem] = []

        // 取当前最后一条消息的时间，判断是否需要插入时间戳
        let lastMsgTime: TimeInterval = {
            for item in items.reversed() {
                if case .message(let m) = item {
                    return m.createTime
                }
            }
            return 0
        }()

        let newMsgTime = msg.createTime
        if newMsgTime - lastMsgTime > timestampThreshold {
            newItems.append(.timestamp(msg.createTime))
        }
        newItems.append(.message(msg))

        // 计算插入位置
        let startIndex = items.count
        items.append(contentsOf: newItems)

        let indexPaths = (startIndex ..< items.count).map { IndexPath(row: $0, section: 0) }
        tableView.insertRows(at: indexPaths, with: .bottom)
        scrollToBottom(animated: true)
    }

    // MARK: - 滚动到底部

    private func scrollToBottom(animated: Bool) {
        guard !items.isEmpty else { return }
        let indexPath = IndexPath(row: items.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }

    // MARK: - 提示

    private func showHint(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak alert] in
            alert?.dismiss(animated: true)
        }
    }
}

// MARK: - UITableViewDataSource & Delegate

extension ZWB_ChatViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch items[indexPath.row] {

        // 时间戳占位行
        case .timestamp(let time):
            let cell = tableView.dequeueReusableCell(withIdentifier: ZWB_TimeCell.reuseId, for: indexPath) as! ZWB_TimeCell
            cell.configure(timestamp: time)
            return cell

        // 普通消息行
        case .message(let msg):
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

            // 自定义消息：根据 cellType 分发到对应 Cell
            case .MESSAGE_TYPE_CUSTOM:
                let att = msg.attachment as? ZWB_CustomAttachment
                switch att?.cellType {
                case .imageText:
                    let cell = tableView.dequeueReusableCell(withIdentifier: ZWB_ImageTextCell.reuseId, for: indexPath) as! ZWB_ImageTextCell
                    cell.applyLayout(isSend: isSend, senderId: msg.senderId ?? "")
                    cell.configure(attachment: att!, isSend: isSend)
                    return cell
                default:
                    let cell = tableView.dequeueReusableCell(withIdentifier: ZWB_DefaultMessageCell.reuseId, for: indexPath) as! ZWB_DefaultMessageCell
                    cell.configure(message: msg, isSend: isSend)
                    return cell
                }

            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: ZWB_DefaultMessageCell.reuseId, for: indexPath) as! ZWB_DefaultMessageCell
                cell.configure(message: msg, isSend: isSend)
                return cell
            }
        }
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        // 时间戳行高度固定较小，消息行估算 80
        if case .timestamp = items[indexPath.row] { return 36 }
        return 80
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// MARK: - UIImagePickerControllerDelegate

extension ZWB_ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            guard let image = image else {
                self?.showHint("未获取到图片")
                return
            }
            self?.sendImage(image)
        }
    }
}

// MARK: - V2NIMMessageListener

extension ZWB_ChatViewController: V2NIMMessageListener {

    /// 收到新消息
    @objc func onReceive(_ messages: [V2NIMMessage]) {
        let filtered = messages.filter { $0.conversationId == self.conversationId }
        guard !filtered.isEmpty else { return }
        DispatchQueue.main.async {
            filtered.forEach { self.appendMessage($0) }
            self.markAsRead()
        }
    }

    /// 消息发送状态变化（可在此刷新对应 cell 的发送状态图标）
    @objc func onSend(_ message: V2NIMMessage) {}

    /// 消息被撤回，重新加载历史
    @objc func onMessageRevokeNotifications(_ revokeNotifications: [V2NIMMessageRevokeNotification]) {
        DispatchQueue.main.async { self.loadHistory() }
    }

    /// 消息被删除，重新加载历史
    @objc func onMessageDeletedNotifications(_ messageDeletedNotifications: [V2NIMMessageDeletedNotification]) {
        DispatchQueue.main.async { self.loadHistory() }
    }
}

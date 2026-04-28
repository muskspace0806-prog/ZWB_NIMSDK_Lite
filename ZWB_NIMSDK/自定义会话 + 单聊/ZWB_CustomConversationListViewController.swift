//
//  ZWB_CustomConversationListViewController.swift
//  ZWB_NIMSDK
//
//  完全自定义 UI，数据源用 NIMSDK v1 NIMConversationManager
//

import UIKit
import NIMSDK
import NECoreIM2Kit
import SnapKit

class ZWB_CustomConversationListViewController: UIViewController {

    // MARK: - Data

    private var sessions: [NIMRecentSession] = []

    // MARK: - UI

    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.register(ZWB_ConversationCell.self, forCellReuseIdentifier: ZWB_ConversationCell.reuseId)
        tv.dataSource = self
        tv.delegate   = self
        tv.rowHeight  = 68
        tv.separatorInset = UIEdgeInsets(top: 0, left: 68, bottom: 0, right: 0)
        return tv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupLayout()
        NIMSDK.shared().conversationManager.add(self)
        IMKitClient.instance.addLoginListener(self)
        reloadData()
    }

    deinit {
        NIMSDK.shared().conversationManager.remove(self)
        IMKitClient.instance.removeLoginListener(self)
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
    }

    // MARK: - 刷新数据

    func reloadData() {
        let list = NIMSDK.shared().conversationManager.allRecentSessions() ?? []
        sessions = list.sorted { $0.updateTime > $1.updateTime }
        tableView.reloadData()
    }

    // MARK: - 跳转单聊（业务层自定义跳转逻辑，可在此加任何业务判断）

    func openChat(session: NIMRecentSession) {
        guard let nimSession = session.session else { return }
        guard let convId = V2NIMConversationIdUtil.p2pConversationId(nimSession.sessionId) else { return  }
        let chatVC = ZWB_ChatViewController(conversationId: convId)
        navigationController?.pushViewController(chatVC, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension ZWB_CustomConversationListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sessions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ZWB_ConversationCell.reuseId, for: indexPath) as! ZWB_ConversationCell
        cell.configure(with: sessions[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openChat(session: sessions[indexPath.row])
    }
}

// MARK: - NIMConversationManagerDelegate

extension ZWB_CustomConversationListViewController: NIMConversationManagerDelegate {

    func didAdd(_ recentSession: NIMRecentSession, totalUnreadCount: Int) { reloadData() }
    func didUpdate(_ recentSession: NIMRecentSession, totalUnreadCount: Int) { reloadData() }
    func didRemove(_ recentSession: NIMRecentSession, totalUnreadCount: Int) { reloadData() }
    func allMessagesRead() { reloadData() }
    func allMessagesDeleted() { reloadData() }
}

// MARK: - NEIMKitClientListener（被踢下线）

extension ZWB_CustomConversationListViewController: NEIMKitClientListener {

    func onKickedOffline(_ detail: V2NIMKickedOfflineDetail) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let alert = UIAlertController(title: "您已被踢下线",
                                          message: "账号在其他设备登录，请重新登录",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
                UserDefaults.standard.removeObject(forKey: "zwb_account")
                UserDefaults.standard.removeObject(forKey: "zwb_token")
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else { return }
                let nav = UINavigationController(rootViewController: ZWB_LoginViewController())
                window.rootViewController = nav
                UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
            })
            self.present(alert, animated: true)
        }
    }
}

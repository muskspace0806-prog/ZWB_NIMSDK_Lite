//
//  ZWB_LoginViewController.swift
//  ZWB_NIMSDK
//

import UIKit
import NECoreIM2Kit

class ZWB_LoginViewController: UIViewController {

    // MARK: - UI（AppKey / CerName / Account / Token）

    private let appKeyField    = ZWB_LoginViewController.makeField(placeholder: "请输入 AppKey", secure: false)
    private let cerNameField   = ZWB_LoginViewController.makeField(placeholder: "请输入 APNs 证书名（可选）", secure: false)
    private let accountField   = ZWB_LoginViewController.makeField(placeholder: "请输入账号", secure: false)
    private let tokenField     = ZWB_LoginViewController.makeField(placeholder: "请输入 Token", secure: true)

    private let loginButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("登录", for: .normal)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "云信 IM Demo"
        view.backgroundColor = .white
        setupLayout()
        loginButton.addTarget(self, action: #selector(loginAction), for: .touchUpInside)

        // 恢复上次填写的 AppKey（方便调试）
        appKeyField.text  = UserDefaults.standard.string(forKey: "zwb_appKey")
        accountField.text = UserDefaults.standard.string(forKey: "zwb_account")
    }

    // MARK: - Layout

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [appKeyField, cerNameField, accountField, tokenField])
        stack.axis      = .vertical
        stack.spacing   = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(loginButton)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            stack.widthAnchor.constraint(equalToConstant: 300),

            appKeyField.heightAnchor.constraint(equalToConstant: 44),
            cerNameField.heightAnchor.constraint(equalToConstant: 44),
            accountField.heightAnchor.constraint(equalToConstant: 44),
            tokenField.heightAnchor.constraint(equalToConstant: 44),

            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 24),
            loginButton.widthAnchor.constraint(equalToConstant: 300),
            loginButton.heightAnchor.constraint(equalToConstant: 44),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 16),
        ])
    }

    // MARK: - Actions

    @objc private func loginAction() {
        let appKey  = appKeyField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let cerName = cerNameField.text?.trimmingCharacters(in: .whitespaces)
        let account = accountField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let token   = tokenField.text?.trimmingCharacters(in: .whitespaces) ?? ""

        guard !appKey.isEmpty else { showAlert("AppKey 不能为空"); return }
        guard !account.isEmpty, !token.isEmpty else { showAlert("账号和 Token 不能为空"); return }

        // 每次登录前重新初始化（AppKey 可能变化）
        let config = ZWB_IMConfig(appKey: appKey, apnsCerName: cerName?.isEmpty == true ? nil : cerName)
        ZWB_IMManager.shared.setupIM(config: config)

        loginButton.isEnabled = false
        activityIndicator.startAnimating()

        let param = ZWB_IMLoginParam(account: account, token: token)
        ZWB_IMManager.shared.login(param: param) { [weak self] error in
            DispatchQueue.main.async {
                self?.loginButton.isEnabled = true
                self?.activityIndicator.stopAnimating()
                if let error = error {
                    self?.showAlert("登录失败: \(error.localizedDescription)")
                } else {
                    // 持久化，下次启动用于判断是否已登录
                    UserDefaults.standard.set(appKey,  forKey: "zwb_appKey")
                    UserDefaults.standard.set(cerName, forKey: "zwb_cerName")
                    UserDefaults.standard.set(account, forKey: "zwb_account")
                    UserDefaults.standard.set(token,   forKey: "zwb_token")
                    self?.enterConversationList()
                }
            }
        }
    }

    func enterConversationList() {
        let vc = ZWB_ConversationListViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    private func showAlert(_ msg: String) {
        let alert = UIAlertController(title: "提示", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Helper

    private static func makeField(placeholder: String, secure: Bool) -> UITextField {
        let tf = UITextField()
        tf.placeholder          = placeholder
        tf.borderStyle          = .roundedRect
        tf.isSecureTextEntry    = secure
        tf.autocapitalizationType = .none
        tf.autocorrectionType   = .no
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }
}

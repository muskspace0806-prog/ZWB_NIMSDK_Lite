//
//  ZWB_LoginViewController.swift
//  ZWB_NIMSDK_Lite
//

import UIKit
import SnapKit

class ZWB_LoginViewController: UIViewController {

    // MARK: - UI

    private let appKeyField  = ZWB_LoginViewController.makeField(placeholder: "请输入 AppKey",          secure: false)
    private let cerNameField = ZWB_LoginViewController.makeField(placeholder: "请输入 APNs 证书名（可选）", secure: false)
    private let accountField = ZWB_LoginViewController.makeField(placeholder: "请输入账号",              secure: false)
    private let tokenField   = ZWB_LoginViewController.makeField(placeholder: "请输入 Token",           secure: true)

    private let loginButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("登录", for: .normal)
        btn.backgroundColor = .systemBlue
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 8
        return btn
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        return ai
    }()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "云信 IM Demo"
        view.backgroundColor = .systemBackground
        setupLayout()
        loginButton.addTarget(self, action: #selector(loginAction), for: .touchUpInside)

        appKeyField.text  = UserDefaults.standard.string(forKey: "zwb_appKey")
        accountField.text = UserDefaults.standard.string(forKey: "zwb_account")
    }

    // MARK: - 布局（SnapKit）

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [appKeyField, cerNameField, accountField, tokenField])
        stack.axis    = .vertical
        stack.spacing = 12

        view.addSubview(stack)
        view.addSubview(loginButton)
        view.addSubview(activityIndicator)

        stack.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-60)
            $0.width.equalTo(300)
        }

        [appKeyField, cerNameField, accountField, tokenField].forEach {
            $0.snp.makeConstraints { $0.height.equalTo(44) }
        }

        loginButton.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(stack.snp.bottom).offset(24)
            $0.width.equalTo(300)
            $0.height.equalTo(44)
        }

        activityIndicator.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(loginButton.snp.bottom).offset(16)
        }
    }

    // MARK: - 登录

    @objc private func loginAction() {
        let appKey  = appKeyField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let cerName = cerNameField.text?.trimmingCharacters(in: .whitespaces)
        let account = accountField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let token   = tokenField.text?.trimmingCharacters(in: .whitespaces) ?? ""

        guard !appKey.isEmpty else { showAlert("AppKey 不能为空"); return }
        guard !account.isEmpty, !token.isEmpty else { showAlert("账号和 Token 不能为空"); return }

        loginButton.isEnabled = false
        activityIndicator.startAnimating()
        view.endEditing(true)  // 先收起键盘，避免 setupIM 阻塞时键盘动画卡顿

        // setupIM 是同步初始化，放到子线程避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let config = ZWB_IMConfig(appKey: appKey, apnsCerName: cerName?.isEmpty == true ? nil : cerName)
            ZWB_IMManager.shared.setupIM(config: config)

            let param = ZWB_IMLoginParam(account: account, token: token)
            ZWB_IMManager.shared.login(param: param) { [weak self] error in
                DispatchQueue.main.async {
                    self?.loginButton.isEnabled = true
                    self?.activityIndicator.stopAnimating()
                    if let error = error {
                        self?.showAlert("登录失败: \(error.desc ?? "未知错误")")
                    } else {
                        UserDefaults.standard.set(appKey,  forKey: "zwb_appKey")
                        UserDefaults.standard.set(cerName, forKey: "zwb_cerName")
                        UserDefaults.standard.set(account, forKey: "zwb_account")
                        UserDefaults.standard.set(token,   forKey: "zwb_token")
                        self?.enterConversationList()
                    }
                }
            }
        }
    }

    func enterConversationList() {
        // 直接替换 rootViewController，避免 present 导致生命周期与 SDK 回调错位
        guard let window = UIApplication.shared.windows.first else { return }
        let vc  = ZWB_ConversationListViewController()
        let nav = UINavigationController(rootViewController: vc)
        window.rootViewController = nav
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
    }

    private func showAlert(_ msg: String) {
        let alert = UIAlertController(title: "提示", message: msg, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    // MARK: - 工厂方法

    private static func makeField(placeholder: String, secure: Bool) -> UITextField {
        let tf = UITextField()
        tf.placeholder            = placeholder
        tf.borderStyle            = .roundedRect
        tf.isSecureTextEntry      = secure
        tf.autocapitalizationType = .none
        tf.autocorrectionType     = .no
        return tf
    }
}

//
//  ZWB_MainTabBarController.swift
//  ZWB_NIMSDK
//
//  主 TabBar，包含消息和通讯录
//

import UIKit

class ZWB_MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
    }

    private func setupTabs() {
        // 消息 Tab（会话列表）
        let conversationVC = ZWB_ConversationListViewController()
        let conversationNav = UINavigationController(rootViewController: conversationVC)
        conversationNav.tabBarItem = UITabBarItem(title: "消息",
                                                  image: UIImage(systemName: "message"),
                                                  selectedImage: UIImage(systemName: "message.fill"))

        // 通讯录 Tab
        let contactVC = ZWB_ContactViewController()
        let contactNav = UINavigationController(rootViewController: contactVC)
        contactNav.tabBarItem = UITabBarItem(title: "通讯录",
                                             image: UIImage(systemName: "person.2"),
                                             selectedImage: UIImage(systemName: "person.2.fill"))

        viewControllers = [conversationNav, contactNav]
        selectedIndex = 0
    }
}

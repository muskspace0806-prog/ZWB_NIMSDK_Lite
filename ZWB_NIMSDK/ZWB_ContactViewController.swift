//
//  ZWB_ContactViewController.swift
//  ZWB_NIMSDK
//
//  嵌入 ContactViewController 作为子 VC
//

import UIKit
import NEContactUIKit

class ZWB_ContactViewController: UIViewController {

    private let contactCtrl = ContactViewController()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "通讯录"
        view.backgroundColor = .white
        addChild(contactCtrl)
        contactCtrl.view.frame = view.bounds
        contactCtrl.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(contactCtrl.view)
        contactCtrl.didMove(toParent: self)
    }
}

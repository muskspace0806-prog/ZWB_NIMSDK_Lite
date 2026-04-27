# ZWB_NIMSDK Demo

网易云信 IM UIKit 集成示例，使用 NEContactUIKit 和 NEChatKit 两个组件。

## 架构设计

### 1. 隔离 Pod 变化
- 通过 `ZWB_IMManager` 统一管理 SDK 初始化和登录，封装 NEChatKit 和 NEContactUIKit 的调用
- 业务层不直接依赖 pod 的具体实现，通过管理类和 Router 方式调用

### 2. 继承方式使用 UI 组件
- `ZWB_ContactViewController` 继承自 `ContactViewController`（NEContactUIKit 提供）
- `ZWB_ChatViewController` 继承自 `ChatViewController`（NEChatKit 提供）
- `ZWB_ConversationListViewController` 继承自 `ConversationController`（NEChatKit 提供）

### 3. Router 方式打开页面
- 使用 `ChatKitClient.shared.openP2pChat()` 打开单聊
- 使用 `ContactKitClient` 提供的方法打开联系人相关页面
- 避免直接 init ViewController，降低耦合

## 文件说明

```
ZWB_NIMSDK/
├── ZWB_IMManager.swift                    # IM SDK 统一管理类
├── ZWB_LoginViewController.swift          # 登录页面
├── ZWB_MainTabBarController.swift         # 主 TabBar
├── ZWB_ContactViewController.swift        # 通讯录页面（继承）
├── ZWB_ChatViewController.swift           # 单聊页面（继承）
├── ZWB_ConversationListViewController.swift # 会话列表（继承）
├── AppDelegate.swift                      # 初始化 SDK
└── SceneDelegate.swift                    # 设置根视图
```

## 使用步骤

### 1. 安装依赖

```bash
cd ZWB_NIMSDK
pod install
```

### 2. 配置 AppKey

在 `AppDelegate.swift` 中替换为你的 AppKey：

```swift
let config = ZWB_IMConfig(appKey: "YOUR_APP_KEY")
```

### 3. 运行项目

打开 `ZWB_NIMSDK.xcworkspace`，运行项目。

### 4. 登录测试

输入账号和 Token 登录，进入主页面。

## 核心功能

### 初始化 SDK

```swift
let config = ZWB_IMConfig(appKey: "YOUR_APP_KEY")
ZWB_IMManager.shared.setupIM(config: config)
```

### 登录

```swift
let param = ZWB_IMLoginParam(account: "account", token: "token")
ZWB_IMManager.shared.login(param: param) { error in
    if error == nil {
        // 登录成功
    }
}
```

### 打开单聊

```swift
// 通过 Router 方式，不直接依赖 ViewController
ChatKitClient.shared.openP2pChat(account: "targetAccount", nav: navigationController)
```

### 自定义 UI

继承 pod 提供的基类，重写方法或添加自定义 UI：

```swift
class ZWB_ContactViewController: ContactViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // 自定义 UI
    }
}
```

## 优势

1. **Pod 更改不影响使用**：通过管理类和 Router 封装，业务层不直接依赖 pod 实现
2. **不修改 Pod**：全部通过继承和 pod 提供的 API 使用
3. **易于维护**：统一的命名规范（ZWB_ 前缀）和清晰的架构
4. **可扩展**：可以轻松添加自定义功能和 UI

## 注意事项

- 需要在网易云信控制台创建应用获取 AppKey
- 需要服务端生成 Token 用于登录
- 首次运行需要执行 `pod install`

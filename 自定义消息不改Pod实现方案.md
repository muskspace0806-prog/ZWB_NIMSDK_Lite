# 自定义消息不改 Pod 实现方案

> 目标：在 NEChatUIKit 框架下，实现自定义消息类型的 Cell 展示，**不修改任何 LocalPods 源文件**，所有代码写在业务模块（如 `ZWB_NIMSDK`）内。

---

## 背景与问题

### 框架消息识别机制

`NEChatUIKit` 通过 `NECustomUtils.typeOfCustomMessage(attachment)` 识别自定义消息类型，该方法读取 `attachment.raw` JSON 字符串中的顶层 `"type"` 字段，与 `NEChatUIKitClient.instance.getRegisterCustomCell()` 注册的 key 匹配，从而决定使用哪个 Cell 渲染。

```
message.attachment.raw["type"] → NECustomUtils.typeOfCustomMessage → 匹配注册的 Cell
```

### 服务端消息格式问题

服务端下发的自定义消息 raw JSON 通常没有顶层 `"type"` 字段，格式如下：

```json
{
  "first": 10,
  "second": 101,
  "data": {
    "title": "标题",
    "desc": "描述",
    "picUrl": "https://..."
  }
}
```

需要根据 `first + second` 计算出业务 `type`，并写入 `raw["type"]`，框架才能识别。

### 历史消息的特殊问题

- **新消息**：NIMSDK 收到消息时会调用注册的 `V2NIMMessageCustomAttachmentParser`，`parse` 方法被自动触发，可以在此写入 `type`。
- **历史消息（数据库恢复）**：NIMSDK 从本地数据库加载时**不会**再调用 Parser，`raw` 里没有 `type`，导致 Cell 匹配失败，消息显示为未知类型。

### 原有方案的问题

在 `ChatMessageHelper.swift`（LocalPods 源文件）中注入代码来补调 `parse`：

```swift
// ZWB 注入 —— 需要修改 Pod 文件
if let attachment = message.attachment as? V2NIMMessageCustomAttachment {
    attachment.parse(attachment.raw)
}
```

**缺点**：每次 `pod update` 后注入代码会丢失，维护成本高。

---

## 解决方案

利用 `ChatViewModel` 中两个 `open func modelFromMessage` 方法，在子类中 override，在调用 `super` 之前补调 `parse`，效果与 Pod 注入完全一致，且不修改任何 Pod 文件。

### 调用链

```
ChatViewController.tableView(_:cellForRowAt:)
    └── viewModel.messages[indexPath.row]          ← model 已在此处准备好
    
消息加载时：
ChatViewModel.loadData / getHistoryMessage
    └── modelFromMessage(message:)                 ← open，可 override ✅
    └── modelFromMessage(message:completion:)      ← open，可 override ✅
        └── ChatMessageHelper.modelFromMessage()   ← static，不可 override ❌
            └── NECustomUtils.typeOfCustomMessage() ← 读 raw["type"]
```

---

## 实现步骤

### 第一步：定义 Cell 类型枚举

根据服务端 `first + second` 字段映射到业务 Cell 类型，`rawValue` 作为注册 key。

```swift
// ZWB_CustomAttachment.swift

enum ZWB_CellType: Int {
    case imageText = 1001  // first=10, second=101
    case user      = 1042  // first=42, second=1/2

    static func from(first: Int, second: Int) -> ZWB_CellType? {
        switch (first, second) {
        case (10, 101): return .imageText
        case (42, 1):   return .user
        case (42, 2):   return .user
        default:        return nil
        }
    }
}
```

### 第二步：实现自定义 Attachment，parse 时写入 type

```swift
// ZWB_CustomAttachment.swift

class ZWB_BaseCustomAttachment: V2NIMMessageCustomAttachment {

    func parseBaseFields(_ json: inout [String: Any]) {
        let first  = json["first"]  as? Int ?? -1
        let second = json["second"] as? Int ?? -1

        if let ct = ZWB_CellType.from(first: first, second: second) {
            // 关键：写入顶层 "type"，让 NECustomUtils.typeOfCustomMessage 能取到
            json["type"] = ct.rawValue
            if let newData = try? JSONSerialization.data(withJSONObject: json),
               let newRaw = String(data: newData, encoding: .utf8) {
                self.raw = newRaw
            }
        }
    }
}

class ZWB_ImageTextAttachment: ZWB_BaseCustomAttachment {
    var title:  String?
    var desc:   String?
    var picUrl: String?

    override func parse(_ attach: String) {
        super.parse(attach)
        guard let data = attach.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let innerData = json["data"] as? [String: Any] else { return }

        title  = innerData["title"]  as? String
        desc   = innerData["desc"]   as? String
        picUrl = innerData["picUrl"] as? String

        parseBaseFields(&json)  // 写入 type 字段
    }
}
```

### 第三步：注册 AttachmentParser（处理新消息）

```swift
// ZWB_CustomAttachmentParser.swift

class ZWB_CustomAttachmentParser: NSObject, V2NIMMessageCustomAttachmentParser {

    static func register() {
        NIMSDK.shared().v2MessageService.register(ZWB_CustomAttachmentParser())
    }

    func parse(_ subType: Int32, attach: String) -> Any? {
        guard let data = attach.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let first  = json["first"]  as? Int ?? -1
        let second = json["second"] as? Int ?? -1

        switch ZWB_CellType.from(first: first, second: second) {
        case .imageText:
            let attachment = ZWB_ImageTextAttachment()
            attachment.parse(attach)  // parse 内部写入 raw["type"]
            return attachment
        case .user:
            let attachment = ZWB_UserAttachment()
            attachment.parse(attach)
            return attachment
        case .none:
            return nil
        }
    }
}
```

### 第四步：创建自定义 ViewModel，override modelFromMessage（处理历史消息）

这是核心步骤，解决历史消息 `parse` 不被调用的问题。

```swift
// ZWB_P2PChatViewModel.swift

import NEChatUIKit
import NECoreIM2Kit
import NIMSDK

class ZWB_P2PChatViewModel: P2PChatViewModel {

    /// 同步版本 override（用于部分历史消息加载场景）
    override func modelFromMessage(message: V2NIMMessage) -> MessageModel {
        // 补调 parse，确保 raw["type"] 被写入
        if let attachment = message.attachment as? V2NIMMessageCustomAttachment {
            attachment.parse(attachment.raw)
        }
        return super.modelFromMessage(message: message)
    }

    /// 异步版本 override（用于主要消息加载场景）
    override func modelFromMessage(message: V2NIMMessage,
                                   _ completion: @escaping (MessageModel) -> Void) {
        if let attachment = message.attachment as? V2NIMMessageCustomAttachment {
            attachment.parse(attachment.raw)
        }
        super.modelFromMessage(message: message, completion)
    }
}
```

### 第五步：创建自定义 ViewController，注入自定义 ViewModel

```swift
// ZWB_ChatViewController.swift

import NEChatUIKit
import NIMSDK

class ZWB_ChatViewController: P2PChatViewController {

    override public init(conversationId: String) {
        super.init(conversationId: conversationId)
        // 替换为自定义 ViewModel
        viewModel = ZWB_P2PChatViewModel(conversationId: conversationId, anchor: nil)
    }

    public init(conversationId: String, anchor: V2NIMMessage?) {
        super.init(conversationId: conversationId, anchor: anchor)
        viewModel = ZWB_P2PChatViewModel(conversationId: conversationId, anchor: anchor)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
```

### 第六步：注册自定义 Cell 和 Parser（在 SDK 初始化时调用）

```swift
// ZWB_IMManager.swift 的 setupIM 方法中

// 1. 注册自定义消息 Cell
NEChatUIKitClient.instance.regsiterCustomCell([
    "\(ZWB_CellType.imageText.rawValue)": ZWB_ImageTextMessageCell.self,
    "\(ZWB_CellType.user.rawValue)":      ZWB_UserMessageCell.self,
])

// 2. 注册 AttachmentParser（处理新消息的 parse）
ZWB_CustomAttachmentParser.register()
```

### 第七步：实现自定义 Cell

继承 `NEBaseChatMessageCell`，重写 `setModel` 绑定数据。

```swift
// ZWB_ImageTextMessageCell.swift

import NEChatUIKit

class ZWB_ImageTextMessageCell: NEBaseChatMessageCell {

    // 左侧（接收方）和右侧（发送方）各一套视图
    private let titleLabelLeft  = UILabel()
    private let titleLabelRight = UILabel()
    // ... 其他视图

    override func setModel(_ model: MessageContentModel, _ isSend: Bool) {
        super.setModel(model, isSend)

        guard let attachment = model.message?.attachment as? ZWB_ImageTextAttachment else {
            return
        }

        let titleLabel = isSend ? titleLabelRight : titleLabelLeft
        titleLabel.text = attachment.title
        // ... 绑定其他数据
    }

    override func showLeftOrRight(showRight: Bool) {
        super.showLeftOrRight(showRight: showRight)
        // 控制左右视图显隐
        titleLabelLeft.isHidden  = showRight
        titleLabelRight.isHidden = !showRight
    }
}
```

---

## 文件清单

在业务模块（`ZWB_NIMSDK`）中需要创建/修改的文件：

```
ZWB_NIMSDK/
├── ZWB_CustomAttachment.swift        # Attachment 模型，parse 时写入 raw["type"]
├── ZWB_CustomAttachmentParser.swift  # Parser，处理新消息的解析
├── ZWB_P2PChatViewModel.swift        # ViewModel 子类，override modelFromMessage
├── ZWB_ChatViewController.swift      # ViewController 子类，注入自定义 ViewModel
├── ZWB_ImageTextMessageCell.swift    # 图文消息 Cell
└── ZWB_IMManager.swift               # 初始化时注册 Cell 和 Parser
```

**LocalPods 中不需要修改任何文件。**

---

## 数据流说明

```
新消息（网络/推送）
    NIMSDK 收到消息
        └── ZWB_CustomAttachmentParser.parse()     ← 自动触发
                └── attachment.parse(raw)           ← 写入 raw["type"]
    ChatViewModel.modelFromMessage()
        └── ZWB_P2PChatViewModel.modelFromMessage() ← override（二次保障）
                └── attachment.parse(raw)           ← 幂等，重复调用无副作用
        └── NECustomUtils.typeOfCustomMessage()     ← 读到 type ✅
        └── 匹配注册的 Cell ✅

历史消息（数据库恢复）
    NIMSDK 从数据库加载，不调用 Parser
    ChatViewModel.modelFromMessage()
        └── ZWB_P2PChatViewModel.modelFromMessage() ← override 补调 parse
                └── attachment.parse(raw)           ← 写入 raw["type"] ✅
        └── NECustomUtils.typeOfCustomMessage()     ← 读到 type ✅
        └── 匹配注册的 Cell ✅
```

---

## 新增自定义消息类型的步骤

每次新增一种自定义消息类型，只需：

1. 在 `ZWB_CellType` 枚举中添加新 case 和 `from(first:second:)` 映射
2. 新建对应的 `ZWB_XxxAttachment` 类，继承 `ZWB_BaseCustomAttachment`，实现 `parse`
3. 在 `ZWB_CustomAttachmentParser.parse` 的 switch 中添加新 case
4. 新建对应的 `ZWB_XxxMessageCell`，继承 `NEBaseChatMessageCell`
5. 在 `ZWB_IMManager.setupIM` 的 `regsiterCustomCell` 中添加注册

**不需要修改 LocalPods 中的任何文件。**

---

## 与原方案对比

| 对比项 | 原方案（Pod 注入） | 本方案（子类 override） |
|--------|------------------|----------------------|
| 是否修改 LocalPods | ✅ 需要 | ❌ 不需要 |
| pod update 后是否失效 | ❌ 注入代码丢失 | ✅ 不受影响 |
| 新消息支持 | ✅ | ✅ |
| 历史消息支持 | ✅ | ✅ |
| 代码隔离性 | 差 | 好 |
| 维护成本 | 高 | 低 |

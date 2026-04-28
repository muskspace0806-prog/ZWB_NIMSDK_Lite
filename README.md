# NEChatUIKit 自定义消息 Cell 接入指南

> 适用场景：在 NEChatUIKit 框架下接入自定义消息类型，**不修改任何 LocalPods 源文件**，所有代码写在业务模块内。

---

## 目录

1. [背景与原理](#1-背景与原理)
2. [文件清单](#2-文件清单)
3. [接入步骤](#3-接入步骤)
   - [Step 1 — 定义消息类型枚举](#step-1--定义消息类型枚举)
   - [Step 2 — 实现 Attachment 模型](#step-2--实现-attachment-模型)
   - [Step 3 — 实现 AttachmentParser](#step-3--实现-attachmentparser)
   - [Step 4 — 实现自定义 ViewModel](#step-4--实现自定义-viewmodel)
   - [Step 5 — 实现自定义 ViewController](#step-5--实现自定义-viewcontroller)
   - [Step 6 — 实现自定义 Cell](#step-6--实现自定义-cell)
   - [Step 7 — 注册 Cell 和 Parser](#step-7--注册-cell-和-parser)
4. [新增消息类型 Checklist](#4-新增消息类型-checklist)
5. [常见问题](#5-常见问题)

---

## 1. 背景与原理

### 框架识别消息的机制

`NEChatUIKit` 通过以下链路决定用哪个 Cell 渲染消息：

```
message.attachment.raw["type"]
    → NECustomUtils.typeOfCustomMessage()
    → 匹配 NEChatUIKitClient.instance.getRegisterCustomCell() 注册的 key
    → 渲染对应 Cell
```

### 服务端消息格式

服务端下发的自定义消息 raw JSON **没有顶层 `"type"` 字段**，格式通常为：

```json
{
  "first":  10,
  "second": 101,
  "data": {
    "title":  "标题",
    "desc":   "描述",
    "picUrl": "https://..."
  }
}
```

需要根据 `first + second` 计算出业务 `type`，写入 `raw["type"]`，框架才能识别。

### 历史消息的特殊问题

| 场景 | Parser 是否被调用 | 结果 |
|------|-----------------|------|
| 新消息（网络/推送） | ✅ NIMSDK 自动调用 | `raw["type"]` 正常写入 |
| 历史消息（数据库恢复） | ❌ NIMSDK 不调用 | `raw["type"]` 缺失，Cell 匹配失败 |

**解决方案**：子类化 `P2PChatViewModel`，override `modelFromMessage`，在调用 `super` 前补调 `parse`，覆盖历史消息场景。

---

## 2. 文件清单

```
业务模块/
├── ZWB_CustomAttachment.swift        # ① 消息类型枚举 + Attachment 模型
├── ZWB_CustomAttachmentParser.swift  # ② Parser，处理新消息解析
├── ZWB_P2PChatViewModel.swift        # ③ ViewModel 子类，补调历史消息 parse
├── ZWB_ChatViewController.swift      # ④ ViewController 子类，注入自定义 ViewModel
├── ZWB_ImageTextMessageCell.swift    # ⑤ 图文消息 Cell
├── ZWB_UserMessageCell.swift         # ⑤ 用户信息消息 Cell
└── ZWB_IMManager.swift               # ⑥ 初始化时注册 Cell 和 Parser
```

**LocalPods 中不需要修改任何文件。**

---

## 3. 接入步骤

### Step 1 — 定义消息类型枚举

在 `ZWB_CustomAttachment.swift` 中维护所有消息类型的映射关系。

`rawValue` 作为注册 Cell 的 key，需要全局唯一，建议用 `first * 100 + second` 或自定义规则。

```swift
// ZWB_CustomAttachment.swift

enum ZWB_CellType: Int {
    case imageText = 1001  // first=10, second=101
    case user      = 1042  // first=42, second=1 或 2

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

> **新增类型时**：在枚举里加 case，在 `from(first:second:)` 里加映射。

---

### Step 2 — 实现 Attachment 模型

每种消息类型对应一个 Attachment 类，继承 `ZWB_BaseCustomAttachment`。

**基类**负责解析 `first/second` 并把 `ZWB_CellType.rawValue` 写入 `raw["type"]`：

```swift
// ZWB_CustomAttachment.swift

class ZWB_BaseCustomAttachment: V2NIMMessageCustomAttachment {

    var first:    Int = -1
    var second:   Int = -1
    var cellType: ZWB_CellType?

    required override init() { super.init() }

    override func parse(_ attach: String) {
        self.raw = attach  // 保存原始 raw，子类解析后再覆盖
    }

    /// 解析 first/second，写入顶层 "type" 字段
    /// 必须在子类解析完业务字段后调用
    func parseBaseFields(_ json: inout [String: Any]) {
        first  = json["first"]  as? Int ?? -1
        second = json["second"] as? Int ?? -1
        cellType = ZWB_CellType.from(first: first, second: second)

        if let ct = cellType {
            json["type"] = ct.rawValue
            if let data = try? JSONSerialization.data(withJSONObject: json),
               let raw  = String(data: data, encoding: .utf8) {
                self.raw = raw
            }
        }
    }
}
```

**子类**解析业务字段，最后调用 `parseBaseFields`：

```swift
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

        parseBaseFields(&json)  // ⚠️ 必须最后调用，写入 raw["type"]
    }

    // 可选：会话列表最后一条消息的文案
    override func conversationText() -> String {
        return "[\(title ?? "图文消息")]"
    }

    // 可选：Cell 高度计算（在 setModel 里用于设置 contentSize）
    override func cellHeight() -> CGFloat {
        return 160
    }
}
```

> **注意**：`parseBaseFields` 必须在解析完所有业务字段之后调用，因为它会重新序列化整个 json 覆盖 `self.raw`。

---

### Step 3 — 实现 AttachmentParser

Parser 处理**新消息**（网络/推送），NIMSDK 收到消息时自动调用。

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

> **新增类型时**：在 switch 里加对应 case，返回新的 Attachment 实例。

---

### Step 4 — 实现自定义 ViewModel

这是解决**历史消息**（数据库恢复）`raw["type"]` 缺失的核心步骤。

NIMSDK 从数据库加载历史消息时不会调用 Parser，需要在 `modelFromMessage` 里手动补调 `parse`。

```swift
// ZWB_P2PChatViewModel.swift

import NEChatUIKit
import NIMSDK

class ZWB_P2PChatViewModel: P2PChatViewModel {

    // 同步版本
    override func modelFromMessage(message: V2NIMMessage) -> MessageModel {
        if let attachment = message.attachment as? V2NIMMessageCustomAttachment {
            attachment.parse(attachment.raw)  // 补调 parse，写入 raw["type"]
        }
        return super.modelFromMessage(message: message)
    }

    // 异步版本
    override func modelFromMessage(message: V2NIMMessage,
                                   _ completion: @escaping (MessageModel) -> Void) {
        if let attachment = message.attachment as? V2NIMMessageCustomAttachment {
            attachment.parse(attachment.raw)
        }
        super.modelFromMessage(message: message, completion)
    }
}
```

> `parse` 是幂等的，对新消息重复调用无副作用。

---

### Step 5 — 实现自定义 ViewController

继承 `P2PChatViewController`，在 `init` 中替换 `viewModel`。

```swift
// ZWB_ChatViewController.swift

import NEChatUIKit
import NIMSDK

class ZWB_ChatViewController: P2PChatViewController {

    override public init(conversationId: String) {
        super.init(conversationId: conversationId)
        viewModel = ZWB_P2PChatViewModel(conversationId: conversationId, anchor: nil)
        // ⚠️ super.init 已绑定旧 ViewModel 的 listener，替换后必须重新绑定
        viewModel.addListener()
    }

    override public init(conversationId: String, anchor: V2NIMMessage?) {
        super.init(conversationId: conversationId)
        viewModel = ZWB_P2PChatViewModel(conversationId: conversationId, anchor: anchor)
        viewModel.addListener()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}
```

> **关键**：替换 `viewModel` 后必须调用 `viewModel.addListener()`，否则新 ViewModel 收不到任何消息事件，页面会空白。

---

### Step 6 — 实现自定义 Cell

继承 `NEBaseChatMessageCell`，将内容视图添加到父类的 `bubbleImageLeft` / `bubbleImageRight`。

左右各一套视图，父类根据发送方向控制显隐。

```swift
// ZWB_XxxMessageCell.swift

import NEChatUIKit

class ZWB_XxxMessageCell: NEBaseChatMessageCell {

    // 左侧（接收方）
    private let titleLabelLeft = UILabel()
    // 右侧（发送方）
    private let titleLabelRight = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        // 将视图添加到父类气泡容器
        bubbleImageLeft.addSubview(titleLabelLeft)
        bubbleImageRight.addSubview(titleLabelRight)

        // 用 SnapKit 或 AutoLayout 布局
        titleLabelLeft.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        titleLabelRight.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
    }

    // ① 绑定数据（框架调用）
    override func setModel(_ model: MessageContentModel, _ isSend: Bool) {
        // 保底：设置 contentSize，避免气泡高度为 0
        if let attachment = model.message?.attachment as? ZWB_XxxAttachment,
           model.contentSize.width == 0 {
            let h = attachment.cellHeight()
            model.contentSize = CGSize(width: 230, height: h)
            model.height = h + 16
        }

        super.setModel(model, isSend)

        guard let attachment = model.message?.attachment as? ZWB_XxxAttachment else { return }

        let label = isSend ? titleLabelRight : titleLabelLeft
        label.text = attachment.title
    }

    // ② 控制左右显隐（框架调用）
    override func showLeftOrRight(showRight: Bool) {
        super.showLeftOrRight(showRight: showRight)
        titleLabelLeft.isHidden  = showRight
        titleLabelRight.isHidden = !showRight
    }
}
```

**关键点**：

| 方法 | 说明 |
|------|------|
| `setModel(_:_:)` | 绑定数据，必须先调 `super`，必须在此设置 `model.contentSize` |
| `showLeftOrRight(showRight:)` | 控制左右视图显隐，必须先调 `super` |
| `bubbleImageLeft` / `bubbleImageRight` | 父类提供的气泡容器，内容视图加在这里 |

---

### Step 7 — 注册 Cell 和 Parser

在 SDK 初始化时（`AppDelegate` 或 `ZWB_IMManager.setupIM`）完成注册，**必须在任何消息解析之前调用**。

```swift
// ZWB_IMManager.swift — setupIM() 方法内

// 1. 注册自定义消息 Cell
//    key 必须与 ZWB_CellType.rawValue 一致
NEChatUIKitClient.instance.regsiterCustomCell([
    "\(ZWB_CellType.imageText.rawValue)": ZWB_ImageTextMessageCell.self,
    "\(ZWB_CellType.user.rawValue)":      ZWB_UserMessageCell.self,
])

// 2. 注册 AttachmentParser（处理新消息）
ZWB_CustomAttachmentParser.register()
```

---

## 4. 新增消息类型 Checklist

每次新增一种自定义消息类型，按顺序完成以下 5 步：

- [ ] **`ZWB_CustomAttachment.swift`**：在 `ZWB_CellType` 枚举中添加新 case，在 `from(first:second:)` 中添加映射
- [ ] **`ZWB_CustomAttachment.swift`**：新建 `ZWB_XxxAttachment` 类，继承 `ZWB_BaseCustomAttachment`，实现 `parse`，最后调用 `parseBaseFields`
- [ ] **`ZWB_CustomAttachmentParser.swift`**：在 `parse` 方法的 switch 中添加新 case
- [ ] **新建 `ZWB_XxxMessageCell.swift`**：继承 `NEBaseChatMessageCell`，实现 `setModel` 和 `showLeftOrRight`
- [ ] **`ZWB_IMManager.swift`**：在 `regsiterCustomCell` 字典中添加注册

**不需要修改 LocalPods 中的任何文件。**

---

## 5. 常见问题

### Q：自定义消息显示为"未知消息"

原因：`raw["type"]` 没有被写入，`NECustomUtils.typeOfCustomMessage` 返回 `nil`。

排查步骤：
1. 确认 `ZWB_CellType.from(first:second:)` 能匹配到该消息的 `first/second`
2. 确认 `parseBaseFields` 在 `parse` 方法末尾被调用
3. 确认 `regsiterCustomCell` 的 key 与 `ZWB_CellType.rawValue` 一致

### Q：新消息正常，历史消息显示为"未知消息"

原因：`ZWB_P2PChatViewModel` 没有被正确注入，或 `modelFromMessage` 没有被 override。

排查步骤：
1. 确认 `ZWB_ChatViewController` 的 `init` 中替换了 `viewModel`
2. 确认替换后调用了 `viewModel.addListener()`

### Q：页面打开后内容空白

原因：替换 `viewModel` 后没有调用 `viewModel.addListener()`，新 ViewModel 收不到消息事件。

修复：

```swift
viewModel = ZWB_P2PChatViewModel(conversationId: conversationId, anchor: nil)
viewModel.addListener()  // ← 必须调用
```

### Q：Cell 高度不对，气泡显示异常

原因：`model.contentSize` 没有被设置，框架使用默认高度。

修复：在 `setModel` 里设置 `contentSize`：

```swift
override func setModel(_ model: MessageContentModel, _ isSend: Bool) {
    if let attachment = model.message?.attachment as? ZWB_XxxAttachment,
       model.contentSize.width == 0 {
        let h = attachment.cellHeight()
        model.contentSize = CGSize(width: 230, height: h)
        model.height = h + 16
    }
    super.setModel(model, isSend)
    // ...
}
```

### Q：`pod install` 后自定义逻辑丢失

本方案所有代码均在业务模块内，不依赖 LocalPods 注入，`pod install` / `pod update` 不会影响任何自定义逻辑。

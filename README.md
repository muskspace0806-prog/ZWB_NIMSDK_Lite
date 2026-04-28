# NEChatUIKit 自定义消息 Cell 接入指南

不修改任何 Pod 源文件，所有代码写在业务模块内。

---

## 目录

1. [原理](#1-原理)
2. [文件结构](#2-文件结构)
3. [接入步骤](#3-接入步骤)
4. [新增消息类型 Checklist](#4-新增消息类型-checklist)
5. [常见问题](#5-常见问题)

---

## 1. 原理

框架识别消息类型的链路：

```
message.attachment.raw["type"]
    → NECustomUtils.typeOfCustomMessage()
    → 匹配 regsiterCustomCell() 注册的 key
    → 渲染对应 Cell
```

服务端下发的消息 raw JSON **没有顶层 `"type"` 字段**：

```json
{
  "first": 10,
  "second": 101,
  "data": { "title": "标题", "picUrl": "https://..." }
}
```

所以需要在 `parse` 里根据 `first + second` 计算出 `type`，写入 `raw["type"]`，框架才能识别。

**历史消息的特殊问题**：NIMSDK 从数据库恢复历史消息时不会调用 Parser，`raw["type"]` 缺失。解决方案是子类化 `P2PChatViewModel`，override `modelFromMessage`，在调用 `super` 前补调 `parse`。

---

## 2. 文件结构

```
ZWB_NIMSDK/
├── 自定义Cell/
│   ├── ZWB_CustomAttachment.swift       # 消息类型枚举 + Attachment 模型
│   ├── ZWB_CustomAttachmentParser.swift # Parser，处理新消息解析
│   ├── ZWB_BaseCustomCell.swift         # Cell 基类，封装左右气泡逻辑
│   ├── ZWB_ImageTextMessageCell.swift   # 图文消息 Cell（纯代码示例）
│   └── ZWB_CustomXibCell.swift          # xib 消息 Cell（xib 示例）
│
├── 自定义会话 + 单聊/
│   ├── ZWB_P2PChatViewModel.swift       # ViewModel 子类，补调历史消息 parse
│   └── ZWB_ChatViewController.swift     # ViewController 子类，注入自定义 ViewModel
│
└── 初始化和登录/
    └── ZWB_IMManager.swift              # 初始化时注册 Cell 和 Parser
```

---

## 3. 接入步骤

### Step 1 — 定义消息类型

在 `ZWB_CustomAttachment.swift` 里维护所有类型的映射。

```swift
enum ZWB_CellType: Int {
    case imageText = 10101  // first=10, second=101
    case customXib = 9902   // first=99, second=2

    static func from(first: Int, second: Int) -> ZWB_CellType? {
        switch (first, second) {
        case (10, 101): return .imageText
        case (99, 2):   return .customXib
        default:        return nil
        }
    }
}
```

---

### Step 2 — 实现 Attachment 模型

继承 `ZWB_BaseCustomAttachment`，解析业务字段，**最后调用 `parseBaseFields`**。

```swift
class ZWB_ImageTextAttachment: ZWB_BaseCustomAttachment {

    var title:  String?
    var picUrl: String?

    override func parse(_ attach: String) {
        super.parse(attach)
        guard let data = attach.data(using: .utf8),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let innerData = json["data"] as? [String: Any] else { return }

        title  = innerData["title"]  as? String
        picUrl = innerData["picUrl"] as? String

        parseBaseFields(&json)  // ⚠️ 必须最后调用，写入 raw["type"]
    }

    override func cellHeight() -> CGFloat { return 160 }
}
```

> `parseBaseFields` 会把 `ZWB_CellType.rawValue` 写入 `raw["type"]`，框架靠这个字段匹配 Cell。必须在解析完所有业务字段之后调用，因为它会重新序列化整个 JSON。

---

### Step 3 — 实现 Cell

继承 `ZWB_BaseCustomCell`，只需实现两个方法，**完全不用关心发送方/接收方**。

#### 纯代码 Cell

```swift
class ZWB_ImageTextMessageCell: ZWB_BaseCustomCell {

    // 创建内容视图（基类会调用两次，分别作为左右气泡的内容）
    override func makeContentView() -> UIView {
        let container = UIView()
        let label = UILabel()
        label.tag = 1
        container.addSubview(label)
        // SnapKit 布局...
        return container
    }

    // 纯赋值，不用管 isSend / 左右
    override func bindData(to contentView: UIView, attachment: ZWB_BaseCustomAttachment) {
        guard let a = attachment as? ZWB_ImageTextAttachment else { return }
        let label = contentView.viewWithTag(1) as? UILabel
        label?.text = a.title
    }
}
```

#### xib Cell

xib Cell 的特殊点：用 `UINib` 实例化自身，取 `contentView` 作为内容视图载体。

```swift
class ZWB_CustomXibCell: ZWB_BaseCustomCell {

    // xib outlet（xib 实例化时由 coder 注入）
    @IBOutlet weak var iconView:     UIImageView!
    @IBOutlet weak var contentLabel: UILabel!

    override func makeContentView() -> UIView {
        let nib = UINib(nibName: "ZWB_CustomXibCell", bundle: nil)
        guard let cell = nib.instantiate(withOwner: nil, options: nil).first
                         as? ZWB_CustomXibCell else { return UIView() }

        // 用 tag 存控件引用，bindData 里通过 tag 取回
        cell.iconView?.tag     = 10
        cell.contentLabel?.tag = 11

        return cell.contentView
    }

    override func bindData(to contentView: UIView, attachment: ZWB_BaseCustomAttachment) {
        guard let a = attachment as? ZWB_CustomXibAttachment else { return }
        let iconView     = contentView.viewWithTag(10) as? UIImageView
        let contentLabel = contentView.viewWithTag(11) as? UILabel
        contentLabel?.text = a.title
        iconView?.kf.setImage(with: URL(string: a.picUrl ?? ""))
    }
}
```

> **为什么 xib Cell 用 tag？**
> `makeContentView()` 返回的是 `UIView`，基类不知道里面有什么控件。xib Cell 依赖 ObjC runtime 加载，不能用 Swift 泛型，所以用 tag 作为控件的"身份证"。tag 值在同一个 Cell 内不冲突即可。

---

### Step 4 — 实现 Parser

处理**新消息**（网络/推送），NIMSDK 收到消息时自动调用。

```swift
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
            let a = ZWB_ImageTextAttachment(); a.parse(attach); return a
        case .customXib:
            let a = ZWB_CustomXibAttachment(); a.parse(attach); return a
        case .none:
            return nil
        }
    }
}
```

---

### Step 5 — 处理历史消息

NIMSDK 从数据库恢复历史消息时**不调用 Parser**，需要在 ViewModel 里补调。

```swift
class ZWB_P2PChatViewModel: P2PChatViewModel {

    override func modelFromMessage(message: V2NIMMessage) -> MessageModel {
        if let a = message.attachment as? V2NIMMessageCustomAttachment {
            a.parse(a.raw)  // 补调，写入 raw["type"]
        }
        return super.modelFromMessage(message: message)
    }

    override func modelFromMessage(message: V2NIMMessage,
                                   _ completion: @escaping (MessageModel) -> Void) {
        if let a = message.attachment as? V2NIMMessageCustomAttachment {
            a.parse(a.raw)
        }
        super.modelFromMessage(message: message, completion)
    }
}
```

注入到 ViewController：

```swift
class ZWB_ChatViewController: P2PChatViewController {

    override public init(conversationId: String) {
        super.init(conversationId: conversationId)
        viewModel = ZWB_P2PChatViewModel(conversationId: conversationId, anchor: nil)
        viewModel.addListener()  // ⚠️ 替换 viewModel 后必须重新绑定 listener
    }
}
```

---

### Step 6 — 注册（在 SDK 初始化时调用）

```swift
// ZWB_IMManager.setupIM() 里

// 注册 Cell
NEChatUIKitClient.instance.regsiterCustomCell([
    "\(ZWB_CellType.imageText.rawValue)": ZWB_ImageTextMessageCell.self,
    "\(ZWB_CellType.customXib.rawValue)": ZWB_CustomXibCell.self,
])

// 注册 Parser
ZWB_CustomAttachmentParser.register()
```

---

## 4. 新增消息类型 Checklist

每次新增一种消息类型，按顺序完成 5 步：

- [ ] `ZWB_CellType` 加新 case，`from()` 加映射
- [ ] 新建 `ZWB_XxxAttachment`，继承 `ZWB_BaseCustomAttachment`，实现 `parse`，最后调 `parseBaseFields`
- [ ] `ZWB_CustomAttachmentParser.parse()` 的 switch 加新 case
- [ ] 新建 `ZWB_XxxCell`，继承 `ZWB_BaseCustomCell`，实现 `makeContentView` + `bindData`
- [ ] `ZWB_IMManager` 的 `regsiterCustomCell` 加注册

**不需要修改任何 Pod 文件。**

---

## 5. 常见问题

**Q：消息显示为"未知消息"**

`raw["type"]` 没有写入。检查：
1. `ZWB_CellType.from()` 能否匹配该消息的 `first/second`
2. `parseBaseFields` 是否在 `parse` 末尾调用
3. `regsiterCustomCell` 的 key 是否与 `ZWB_CellType.rawValue` 一致

---

**Q：新消息正常，历史消息显示为"未知消息"**

`ZWB_P2PChatViewModel` 没有正确注入。检查：
1. `ZWB_ChatViewController.init` 里是否替换了 `viewModel`
2. 替换后是否调用了 `viewModel.addListener()`

---

**Q：页面打开后内容空白**

替换 `viewModel` 后没有调用 `viewModel.addListener()`，新 ViewModel 收不到消息事件。

```swift
viewModel = ZWB_P2PChatViewModel(...)
viewModel.addListener()  // 必须加
```

---

**Q：自定义 Cell 下方有多余空白**

`model.height` 没有对齐框架公式。`ZWB_BaseCustomCell` 已处理，公式为：

```
model.height = contentSize.height
             + chat_content_margin * 2   // 上下内边距 16
             + model.fullNameHeight       // 群聊昵称（p2p = 0）
             + chat_pin_height            // pin 标记 16
             + (有时间戳 ? chat_timeCellH : 0)
```

---

**Q：点击事件如何处理**

| 场景 | 方案 |
|------|------|
| 整个 Cell 点击 | `ZWB_ChatViewController` override `tableView(_:didSelectRowAt:)` |
| 气泡内容区域点击 | 复用框架 `didTapMessageView`，ViewController override 处理 |
| Cell 内部多个按钮 | Cell 内加 closure，ViewController 在 `cellForRowAt` 里赋值 |

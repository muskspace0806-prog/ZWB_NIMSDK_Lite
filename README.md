# ZWB_NIMSDK_Lite

基于网易云信 `NIMSDK_LITE` 的 iOS 聊天 Demo（纯自定义聊天 UI）。

## 1. 项目定位

- 平台：iOS（Swift + UIKit）
- SDK：`NIMSDK_LITE 10.9.71`
- 架构：
  - IM 能力走云信 SDK（登录、会话、消息、附件下载）
  - 聊天页面、输入栏、消息 Cell 全部自定义

## 2. 当前功能

- 登录 / 自动登录 / 退出登录
- 多端互踢（主动踢其他端 + 被踢自动回登录）
- 本地会话列表（非云端会话模式）
- 单聊消息：文本、图片（相册/拍照）、语音、自定义消息
- 语音消息：按住录音发送、点击播放、下载后播放、播放动画
- 消息交互：图片点击全屏预览、头像点击事件预留

## 3. 关键目录

- `ZWB_NIMSDK_Lite/初始化和登录`
  - `ZWB_IMManager.swift`：SDK 初始化、登录登出、互踢
  - `ZWB_LoginViewController.swift`：登录页
  - `ZWB_ConversationListViewController.swift`：会话列表
- `ZWB_NIMSDK_Lite/自定义会话 + 单聊`
  - `ZWB_ChatViewController.swift`：聊天核心（收发/渲染/播放/预览）
  - `其他控件/ZWB_InputBar.swift`：输入栏（文本/语音/表情/图片入口）
  - `其他控件/ZWB_VoiceRecorder.swift`：录音管理
  - `其他控件/ZWB_EmojiPanel.swift`：自定义表情面板
  - `Cells/`：消息 Cell（文本/图片/语音/兜底等）

## 4. 核心实现逻辑（简版流程）

### 4.1 App 启动与登录态

1. `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
2. 读取本地 `appKey/account/token`
3. 若存在：
   - `ZWB_IMManager.setupIM(config:)`
   - `ZWB_IMManager.login(param:completion:)`
   - 直接进入 `ZWB_ConversationListViewController`
4. 若不存在：进入 `ZWB_LoginViewController`

### 4.2 SDK 初始化与多端互踢

- 初始化：`ZWB_IMManager.setupIM(config:)`
  - `NIMSDK.shared().register(withOptionV2:v2Option:)`
  - `v2Option.enableV2CloudConversation = false`
  - 添加登录监听 `v2LoginService.add(self)`
- 登录：`ZWB_IMManager.login(...)`
  - 成功后调用 `kickOtherLoginClientsIfNeeded()`
  - 遍历 `getLoginClients()`，踢掉除当前 `clientId` 外的在线端
- 被踢：`onKickedOffline(_:)`
  - 发通知 `.zwbIMKickedOffline`
  - `AppDelegate.handleKickedOffline(_:)` 收到后切回登录页

### 4.3 会话列表

- 页面：`ZWB_ConversationListViewController`
- 监听：`v2LocalConversationService.add(self)`
- 同步完成回调：`onSyncFinished()`
- 拉取列表：`loadConversations()` -> `getConversationList(...)`
- 进入聊天：`didSelectRowAt` push `ZWB_ChatViewController`

### 4.4 聊天页消息加载与渲染

- 页面：`ZWB_ChatViewController`
- 历史消息：`loadHistory()` -> `v2MessageService.getMessageList(...)`
- 新消息监听：`addMessageListener()` + `onReceive(_:)`
- 数据结构：`[ZWB_ChatItem]`（消息 + 时间戳占位）
- 时间戳逻辑：`buildChatItems(from:)`、`appendMessage(_:)`
- 渲染分发：`tableView(_:cellForRowAt:)`
  - 文本：`ZWB_TextMessageCell`
  - 图片：`ZWB_ImageMessageCell`
  - 语音：`ZWB_DefaultMessageCell`（语音样式）
  - 自定义：`ZWB_ImageTextCell` 或兜底

### 4.5 输入栏与发送

- 输入栏：`ZWB_InputBar`
  - `onSend` -> 文本发送
  - `onMediaTapped` -> 相册/拍照
  - `onVoiceRecordEvent` -> 开始/结束/取消录音
- 文本发送：`sendText(_:)`
  - `V2NIMMessageCreator.createTextMessage(...)`
  - `v2MessageService.send(...)`
- 图片发送：`sendImage(_:)`
  - 本地写入 jpg
  - `createImageMessage(path,name,scene,width,height)`
  - `send(...)`
- 语音发送：`sendAudio(filePath:duration:)`
  - 用 `AVURLAsset` 算真实时长
  - 注意：SDK 要求 `duration` 单位是毫秒
  - `createAudioMessage(..., duration: durationMs)`
  - `send(...)`

### 4.6 语音播放

- 点击回调：语音 Cell `onAudioTapped`
- 入口：`playAudioMessage(_:)`
  - 有本地 path：直接播
  - 无本地：`v2StorageService.downloadFile(...)` 下载后播
- 播放：`startAudioPlay(filePath:messageId:)`
  - `AVAudioSession` -> `.playAndRecord + .defaultToSpeaker`
  - `AVAudioPlayer` 播放
- 停止：`stopAudioPlayIfNeeded()`
- 动画联动：`refreshAudioPlayAnimations()`
  - 语音 Cell `setAudioPlaying(_:)`

### 4.7 图片预览与头像点击预留

- 图片点击：`ZWB_ImageMessageCell.onImageTapped`
- 预览入口：`previewImageMessage(_:preferredImage:)`
- 全屏展示：`presentImagePreview(_:)`
- 关闭：`dismissImagePreview()`
- 头像点击：`ZWB_BaseChatCell.onAvatarTapped`
  - 聊天页统一绑定 `bindCommonCellEvents(...)`
  - 当前预留到 `handleAvatarTap(senderId:)`（仅打印）

## 5. 表情说明（重要）

当前使用的是**自定义表情面板**，不是云信 UIKit 现成输入栏。

为避免“对端收到是文本而不是表情”问题：
- 建议统一发送 Unicode emoji；或
- 统一一套 code -> 表情渲染映射（发送端和接收端一致）

## 6. 依赖

`Podfile` 核心依赖：

- `NIMSDK_LITE`
- `Kingfisher`
- `SnapKit`
- `IQKeyboardManager`
- `TZImagePickerController/Basic`

## 7. 运行方式

1. `pod install`
2. 打开 `ZWB_NIMSDK_Lite.xcworkspace`
3. 登录页输入：`AppKey / accid / token`
4. 进入会话列表与聊天页测试

## 8. 架构注意点

- 已处理真机架构：仅模拟器排除 `arm64`
- 检查项：
  - `EXCLUDED_ARCHS[sdk=iphonesimulator*] = arm64`

## 9. 后续可继续扩展

- 头像点击接入用户资料页
- 语音播放进度条 / 未读红点
- 图片预览升级为缩放 + 左右滑动
- 消息发送状态（发送中/失败重发）
- 表情协议跨端统一（自定义大表情走附件消息）

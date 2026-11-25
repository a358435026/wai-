# 随声同传 · iPhone 独立客户端

SwiftUI + AVAudioEngine + 火山引擎官方 AST S2S。无需豆包 App、越狱或注入。

## 首版功能

- 中文→英语、英语→中文、中英自动互译；实时原文与译文字幕。
- 16 kHz / mono / PCM16 录音，按官方建议以 80 ms 音频分片发送。
- 服务端确认 SessionStarted 后才启用录音；收到 PCM16 译音即排队播放。
- AVAudioEngine voice processing、麦克风静音、译音静音、结束时接收并播完尾句。
- 发送积压、播放积压、服务错误、连接超时和设备中断处理。
- API Key 由用户输入，保存在本机 Keychain；不存入源码、日志、UserDefaults。
- 字幕在当前会话内存中；不保存录音。进入后台结束连接，前台同传保持屏幕唤醒。

## 开通服务

在火山引擎开通「豆包同声传译」服务，确认额度、余额和权限。
在 App 的设置中填写该服务可用的 API Key。请求目的地固定为官方端点：

`wss://openspeech.bytedance.com/api/v4/ast/v2/translate`

鉴权：`X-Api-Key`；资源：`volc.service_type.10053`。
服务按官方规则计费，和豆包 App 的免费额度无关。静音期间会话仍在运行。
未指定 speaker_id，使用服务默认的实时跟随说话人音色；实际音色、语种与权限需实测。

## 本地或 GitHub 构建

需要 Mac + Xcode（支持 iOS 15 部署目标）与 XcodeGen。当前最低系统为 iOS 15.0。
0.1.1 已替换 iOS 16/17 专属的无保护界面 API，并为旧系统使用 AVAudioSession 麦克风权限实现。

```sh
swift test
brew install xcodegen # 未安装时
xcodegen generate
open Tongchuan.xcodeproj
```

GitHub Actions `.github/workflows/ios.yml` 在 macOS 上执行核心测试、真机目标编译和模拟器启动测试。
产物 `Tongchuan-iOS15-unsigned.ipa` **未签名，需要安装工具处理签名**。可由用户使用自己的签名方式安装；
也可在 Xcode 选择自己的 Apple Team 和真机进行签名运行。TestFlight 需要开发者账号和发布配置。
未将证书、Apple ID 或 API Key 放入 Actions。

安装步骤见 [INSTALL.md](INSTALL.md)，实际构建结果见 [VALIDATION.md](VALIDATION.md)。
CI 会同时检查 Info.plist 和 Mach-O 内的最低系统版本，确保不超过目标 iOS 15.4.1。

## 真机验收清单（构建成功不能替代）

1. 输入有效 Key，开通麦克风：说中文，显示英文并听到英文译音；反向同样测试。
2. 外放持续 5 分钟：确认译音不会被反复拾取、声音不中断、延迟没有持续积压。
3. 蓝牙/有线耳机、切换输出、拔出耳机、来电中断、进入后台。
4. 连续开始/停止、连接中取消、失效 Key、余额不足、断网与恢复。
5. 停止后不再采集，最后一句字幕和译音收尾，Key 不出现在日志和普通偏好设置中。

## 实现与限制

`Sources/Core/ASTProtocol.swift` 是依据官方 `.proto` 字段号实现的精简 protobuf wire codec，
不使用 DeepSeek 样例里的 SAMI/voicegenie 私有协议。兼容未知 varint、长度和 fixed32/64 字段。
`Protocol/` 保留官方消息定义作为对照；`Tests/CoreTests/Fixtures/` 来自官方 Python 绑定生成的合成数据。

本应用未复用豆包二进制、UI 资源、私有 token 或登录态。原包仅用于理解交互。
首版不提供后台持续录音、其他 App/电话的内部音频捕获，也未声称已经通过真实 API 和真机测试。
回声处理与真实语音延迟必须在用户设备、音频路由和实际网络上验收。

## 官方资料

- https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation?lang=zh
- https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation-1?lang=zh
- https://developer.apple.com/documentation/avfaudio/avaudioionode/setvoiceprocessingenabled(_:)

这是独立个人自用客户端，与豆包 App 无隶属关系。

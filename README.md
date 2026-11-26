# 随声同传 · iPhone 独立客户端

SwiftUI + AVAudioEngine + 火山引擎官方 AST S2S。无需豆包 App、越狱或注入。

## 0.3.0 多语种与仅字幕

- 按官方AST2.0目录加入48种语言、9种输入方言与中英混合识别；源语言和目标语言独立选择，可搜索、交换，并记住上次选择。
- 当前接口至少一端为中文或英语；方言/中英混合识别只译为中文或英语。界面只展示当前源语言允许的目标。
- 16种目标语言使用本版已实现的默认译音路径；其他目标自动请求S2T仅字幕，明确提示不提供本版译音。不能把字幕支持数当成译音支持数。
- 新增真正的服务端“仅字幕”：StartSession模式为s2t且不发送target_audio。底部扬声器静音仍仅控制本机播放。
- 不改动0.2.1已通过用户真机验证的AudioQueue采集和播放器实现。
- 多语种真实接口验证与本次构建结果见VALIDATION.md；不能把UI可选目录认定为所有语种已逐一真机验收。

## 0.2.1 采集与动态反馈修复

用户在 iOS15.4.1 已授权后仍无有效 PCM 包。新版将录音独立为 AudioQueue PCM16/16k/mono，移除 AVAudioEngine 输入 tap + voice processing + 手动转换链；播放器继续使用独立 AVAudioEngine。

- 新增不需要 Key、不联网、不计费的本机麦克风测试；诊断显示授权状态、输入路由、原生回调、字节数和网络包数。
- 真正区分授权失败、录音启动 OSStatus 错误、已授权但没有回调。
- 语音球改为 30fps 流动/形变；分别使用输入 PCM 和播放器 mixer tap 的实际音量。
- 当前路径没有原语音处理图的回声消除。外放播报及短暂尾音期间上传静音，耳机可同时收听与说话；不声称已达到原应用外放全双工效果。
- 云端模拟器旧设备数据迁移超过3分钟，新建临时模拟器并增加启动等待上限。用户已确认新版真机收音与说话动画恢复，正式中文→英文会话的双语字幕与英文播报均正常。

b5同时将“更多”改为常规按钮与原生操作面板，10项核心测试和3项模拟器UI用例通过。收音代码与用户已确认正常的b4相同。长期外放、耳机和弱网中断仍需持续验证。

## 0.2.0 更新

- 全屏渐变、原创动态语音球、滚动双语字幕、面对面/会议场景。中英自动互译仅作为测试选项，默认使用已通过真实服务测试的中译英。
- 麦克风静音、译音开关、当前句播报打断、连接诊断。
- 针对 45000081 增加麦克风首包检查、提前预热及断流检测；真机推流问题仍需设备复测。
- 专属 WebSocket 按本地连接代次处理响应；API Key 管理链接修正。
- 2026-11-26 官方测试音频短测：150 个音频包、双语字幕、297560 字节 PCM 译音，正常 FinishSession。
- 仍兼容 iOS15；不提供摄像、屏幕共享或其他 App 内部通话采集。

## 功能

- 中文→英语、英语→中文、中英自动互译；实时原文与译文字幕。
- 16 kHz / mono / PCM16 录音，按官方建议以 80 ms 音频分片发送。
- 先准备麦克风并确认首包，服务端确认 SessionStarted 后才上传音频；收到 PCM16 译音即排队播放。
- AudioQueue 录音、独立 AVAudioEngine 译音播放、麦克风静音、译音静音、结束时接收并播完尾句。
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
首版不提供后台持续录音、其他 App/电话的内部音频捕获，官方样例API双向短测与用户iPhone上的中文→英文收音、双语字幕及译音播放短测均已通过。
回声处理与真实语音延迟必须在用户设备、音频路由和实际网络上验收。

## 官方资料

- https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation?lang=zh
- https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation-1?lang=zh
- https://developer.apple.com/documentation/avfaudio/avaudioionode/setvoiceprocessingenabled(_:)

这是独立个人自用客户端，与豆包 App 无隶属关系。


## 其他供应商接入评估（2026-11-26）

当前安装包仍使用火山引擎官方AST，没有将DeepSeek Key当成火山Key使用，也未加入伪装可用的供应商选项。

- 阿里云百炼Qwen3.8-LiveTranslate-Flash-Realtime：北京地域音频输入40元/百万Token、输出音频160元/百万Token、文字输出100元/百万Token；音频每秒输入7Token、输出12.5Token。输入/输出各一小时的音频费用合计8.208元，文字另计。该值是按官网换算的估算，不代表已在用户网络验证质量、可用性或延迟。
- DeepSeek官方新增ASR/TTS工具接口：ASR目前非流式，一次最长120秒，更适合按句翻译；默认TTS支持10种语言，未列西班牙语/法语/德语/葡萄牙语。可以组合ASR→文字翻译→TTS，但不是替换当前WebSocket地址或Key即可。
- DeepSeek限时ASR为0.39元/小时，TTS为1.5元/万字符，文字模型Token费另算。按字符和按音频时长无法不作假设地直接互换；活动价格会变。
- 稳定性需要相同音频、手机、网络和地域做实际对比。此前用户无音频问题已定位为客户端采集路径，不能视作服务供应商稳定性对比。

来源：
https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation-1?lang=zh
https://help.aliyun.com/zh/model-studio/qwen3-8-livetranslate-flash-realtime
https://www.alibabacloud.com/help/en/model-studio/qwen3-5-livetranslate-flash-realtime
https://api-docs.deepseek.com/zh-cn/quick_start/pricing/
https://api-docs.deepseek.com/guides/asr/
https://api-docs.deepseek.com/guides/tts/

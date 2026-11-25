# 在 iPhone 上安装与验证

交付的 `Tongchuan-unsigned.ipa` 是 iPhone 真机目标产物（arm64 / iPhoneOS），最低 iOS 17。
它没有签名或 embedded.mobileprovision，不能直接在手机点开安装。

## 已安装 TrollStore / 越狱设备

用户选择此安装路线。请先确认准确的 iOS 版本：当前构建要求 iOS 17，不能直接装到 iOS 16 或更低版本。
安装工具支持的系统范围与 App 的最低系统要求是两件事；降低 Info.plist 数字也不能让较新系统 API 自动兼容旧系统。

在系统和 App 兼容的前提下，将 IPA 传到手机，用已经安装的 TrollStore 打开并安装。
TrollStore 会处理安装签名，不需要把 Apple 账号或开发证书交给本项目。
如使用其他越狱安装器，请提供工具名称和系统版本，再核对安装要求。

本 App 的功能仍使用普通麦克风、联网和音频播放接口，不需要 root helper、注入豆包、私有 token 或解除 App 沙盒。
安装后再在 App 内填写自己的火山引擎 API Key。

TrollStore 官方支持说明：https://github.com/opa334/TrollStore

## 使用这台电脑已有的 Sideloadly

1. 使用 USB 连接 iPhone，解锁并按手机提示信任此电脑。
2. 打开 Sideloadly，选择这台手机，把 `Tongchuan-unsigned.ipa` 拖入应用。
3. 在 Sideloadly 中由你本人完成 Apple 账号、签名和验证步骤。账号、密码和验证码不要写入仓库或发到聊天中。
4. 完成后按 iPhone 系统提示信任你自己的签名；如系统要求开发者模式，按系统说明完成。
5. 打开「随声同传」，进入设置，输入你自己的火山引擎 API Key。请先开通同声传译服务并确认计费额度。

安装方式和签名有效期取决于你使用的账号与签名方案；也可以用自己的开发证书签名或在 Xcode 真机运行。
不要将「编译成功」与「签名安装成功」混淆。

## 第一次真机测试

- 先选「中文 → English」，点开始，允许麦克风。等状态变为正在聆听后说一句简短中文。
- 验证原文、英文译文都出现，并自动播放英文语音；再切换「English → 中文」验证反向。
- 使用扬声器连续测试，确认播放器的声音没有被反复翻译；再用耳机测试。
- 说完点停止，检查最后一句译音能播完。进入后台会结束会话，首版不在后台持续录音。
- API Key 在 App 内填入，仅保存在本机钥匙串。不要把真实 Key 作为故障截图内容分享。

错误时请提供错误码、操作步骤、iOS 版本、耳机/外放类型；不需要提供 Key。

## 官方参考

- Sideloadly：https://sideloadly.io/
- 火山引擎同传：https://docs.volcengine.com/docs/doubao-voice/simultaneous-interpretation?lang=zh

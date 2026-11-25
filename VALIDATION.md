# 验证记录 · 2026-11-26

## 已通过的云端验证

- 仓库：https://github.com/a358435026/wai-
- 构建源码提交：`900ec03f5545f68593432628d757552a2602d709`
- 成功记录：https://github.com/a358435026/wai-/actions/runs/45692880847
- 官方 Intel macOS runner，8 项 Swift 核心测试通过，0 失败。
- 其中 StartSession、音频包、FinishSession 与官方 Python protobuf 生成样本逐字节一致；响应解码、未知字段、异常帧、音频分帧和字幕分段测试通过。
- iPhone 真机目标 Release archive 通过；iPhone 模拟器首页和设置页 UI 测试 1 项通过，0 失败。
- 已从 xcresult 提取并目视检查首页、设置页截图，中文正常。
- 已验证下载包的 SHA256 与 GitHub artifact digest 一致，并验证外层 ZIP、IPA 内层 ZIP 的 CRC。
- IPA 内的 Info.plist 声明 `iPhoneOS`，Mach-O 的 CPU 为 ARM64，LC_BUILD_VERSION 的 platform 为 2（iOS 真机），不是模拟器包。

## 交付包

- 名称：随声同传 0.1.0
- 最低系统：iOS 17.0
- Bundle ID：`app.tongchuan.personal`
- 未签名 IPA：119299 字节
- IPA SHA256：`65c0e0ccbbcf06d7e47b2c4ed6c1429a46c734b10ca4b8b976b637a762c788b0`
- 无 embedded.mobileprovision，无开发证书；安装签名需由用户的安装方式处理。
- 用户已选择 TrollStore / 越狱设备，准确 iOS 版本及具体工具仍待确认。不能据此宣称 iOS 16 或更低版本兼容。

源码包仅包含应用源文件、合成测试样本、官方协议定义、构建配置和文档，不包含原豆包 IPA、用户录音、API Key 或签名证书。

## 尚未完成，需真机和有效 Key

- 未发起真实收费语音请求，未验证用户账户的火山引擎服务权限。
- 未在真实 iPhone 上验证译音、外放回声、蓝牙切换或连续使用延迟。
- 尚未完成用户设备上的安装和钥匙串权限验证。
- 模拟器 UI 测试不覆盖真实麦克风采集和扬声器播放。

## 后续顺序

1. 确认 iPhone 型号、准确 iOS 版本、TrollStore 是否已安装或具体越狱工具。
2. 按设备版本决定直接安装当前包，或先适配较低 iOS API 并重新构建。
3. 用户在 App 内填写有效 API Key，按 README 的真机清单验收。

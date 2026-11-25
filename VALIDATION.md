# 验证记录 · 2026-11-26

## 已完成

- 从火山引擎官方页面下载 AST .proto 与 Python 客户端附件，并保留来源和哈希。
- 使用官方生成的 Python protobuf 绑定产生 StartSession、音频包、FinishSession、字幕响应和错误响应的固定样本。
- Swift 测试已写好，用以上独立来源的样本验证 wire 编解码；另覆盖音频分帧完整性和字幕分段。
- GitHub workflow 已配置：macOS、Swift 核心测试、iPhone 真机目标 archive、模拟器 UI 启动和设置页测试。
- 检查源码包只包含应用源文件、合成测试样本、协议定义、构建配置和文档。不包含原 IPA、用户录音、凭据或证书。

## 尚未完成，不应宣称通过

- 当前电脑是 Windows，未安装 Swift/Xcode；Swift 测试和 iOS 编译尚未执行。
- 用户已指定使用 `a358435026/wai-`，源码通过已连接的 GitHub connector 上传；不依赖网页登录。
- GitHub Actions 尚未触发，无成功构建记录或可安装的已签名 IPA。
- 没有用户配置的火山引擎 API Key，因此未发起真实收费语音请求。
- 没有连接 iPhone，未验证外放回声、蓝牙路由、真实翻译延迟和安装签名。

## 后续顺序

1. 确定项目仓库并上传源码，运行 Actions，修复编译/测试问题直到通过。
2. 下载未签名 IPA，由用户签名安装或在 Xcode 选择 Apple Team 真机运行。
3. 用户在 App 内填写服务可用的 API Key，按 README 的真机清单验收。

正式交付状态以编译日志和真机测试为准，而非文件已生成。

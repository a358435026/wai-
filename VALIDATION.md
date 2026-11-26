# 0.2.0 验证记录 · 2026-11-26

## 真实官方 API 短测

用户提供的个人 Key 只经临时子进程环境变量传入，不含在源码、仓库、安装包或输出中。
保留原有 VPN，通过既有系统代理连接官方 WSS；使用官方 Python demo 自带测试音频，不使用用户麦克风录音。
发送 150 包、约12秒 PCM，接收成功码20000000、SessionStarted、原文与翻译字幕、34段译音（297560字节、9.29875秒PCM）及 SessionFinished。
握手补查：网关成功响应的 SessionID 长度为0，不能将“与请求UUID不同”认定为旧版过滤成功事件的原因；旧代码允许空SessionID。前述根因推断已纠正。新版仍按专属socket和本地generation校验归属，并将麦克风预热和首包验证提前到联网之前。45000081的设备侧具体原因仍待真机采集/发送计数验证。

以上证明账号/权限/服务/PCM协议可用，不等于新版 iPhone 麦克风已通过真机测试。设备侧仍需用户安装后验证。

反向测试使用上述官方样例产生的英文译音（非用户录音），设置en→zh：117包，接收双语字幕、28段中文译音（247468字节、7.733375秒PCM）及正常SessionFinished。

## 自动互译服务检查

同一 API Key、同一官方样例，将源/目标设为zhen后，短测出现55000001服务内部错误，另一次短测只返回Usage/Finished而没有字幕或译音。加长到19.44秒后仍返回55000001。没有将该配置作为默认值；界面保留明确标为测试中的可选项。默认zh→en已实测返回字幕和译音。

## 新版构建

0.2.0 build3，最低iOS15.0。
- 应用源码提交：b6ee9b31faa3587a9e9b7f1150a3b4221fdf40f3
- 构建：https://github.com/a358435026/wai-/actions/runs/45794359909
- Swift核心测试8项通过，iPhone真机目标Release archive和版本检查通过。
- IPA：142365字节，ARM64/iPhoneOS，Info.plist和Mach-O最低系统均15.0，未签名，无embedded.mobileprovision。
- IPA SHA256：53f8784db87b7917cbdeff8e24f1e18ffff91cda8b7f3f608babe24d99d98d13
- Artifact ZIP SHA256：9e37ee07bb10807632a393e77944b49923e3199507e70021598bea907b60c1ea，与GitHub digest一致；内外ZIP CRC通过。
- 二进制扫描不含用户提供的API Key。
- 云端模拟器启动步骤失败（3分钟时限），两条最终源码构建均停在启动模拟器之前，UI用例被跳过。应用尚未在该模拟器运行，不能宣称新版UI测试通过；没有可用的新界面截图。iOS15.4.1真机采集与外放需安装后验证。

---

## 历史 0.1.1 验证记录

# 验证记录 · 2026-11-26

## 已通过的云端验证

- 仓库：https://github.com/a358435026/wai-
- 已验证的应用源码提交：`6b6385d6d5ba2442fb2a99e4c24752d982d7b2d9`
- 成功记录：https://github.com/a358435026/wai-/actions/runs/45695329427
- 官方 Intel macOS runner，8 项 Swift 核心测试通过，0 失败。
- 其中 StartSession、音频包、FinishSession 与官方 Python protobuf 生成样本逐字节一致；响应解码、未知字段、异常帧、音频分帧和字幕分段测试通过。
- iPhone 真机目标 Release archive 通过；iPhone 模拟器首页和设置页 UI 测试 1 项通过，0 失败。
- 已从 xcresult 提取并目视检查首页、设置页截图，中文正常。
- 已验证下载包的 SHA256 与 GitHub artifact digest 一致，并验证外层 ZIP、IPA 内层 ZIP 的 CRC。
- IPA 内的 Info.plist 声明 `iPhoneOS`，Mach-O 的 CPU 为 ARM64，LC_BUILD_VERSION 的 platform 为 2（iOS 真机），不是模拟器包。
- 新增门禁已验证 Info.plist 的 MinimumOSVersion 为 15.0，Mach-O 的 minos 为 15.0.0，均不超过目标系统 15.4.1；旧版 iOS17 IPA 被该门禁正确拒绝。

## 本次兼容修复

用户提供设备为 iPhone 13 Pro / iOS 15.4.1，上一版最低系统为 iOS17，存在明确的系统版本不兼容。
0.1.1 使用 iOS15 部署目标重新编译，同时替换 NavigationStack、topBarTrailing、symbolEffect 等较新 API，
并为麦克风权限使用有系统版本保护的 AVAudioApplication / AVAudioSession 分支。
应用使用统一的浅色外观，避免设备深色模式下固定浅色卡片与动态文字颜色发生冲突。
没有取得设备 .ips 崩溃日志，因此不能认定旧版闪退的唯一原因，也不能宣称已在真实 iOS15.4.1 设备复测。

## 交付包

- 名称：随声同传 0.1.1（build 2）
- 最低系统：iOS 15.0
- Bundle ID：`app.tongchuan.personal`
- 未签名 IPA：121322 字节
- IPA SHA256：`018eec1ebfd9440ab49499b8b9a8628cb13325a45cf1ce4114effe8865583ee5`
- 无 embedded.mobileprovision，无开发证书；安装签名需由用户的安装方式处理。
- 用户已选择 TrollStore / 越狱设备，iOS15.4.1 符合本次构建的最低系统版本要求。

源码包仅包含应用源文件、合成测试样本、官方协议定义、构建配置和文档，不包含原豆包 IPA、用户录音、API Key 或签名证书。

## 尚未完成，需真机和有效 Key

- 未发起真实收费语音请求，未验证用户账户的火山引擎服务权限。
- 未在真实 iPhone 上验证译音、外放回声、蓝牙切换或连续使用延迟。
- 尚未完成用户设备上的安装和钥匙串权限验证。
- 模拟器 UI 测试不覆盖真实麦克风采集和扬声器播放。
- 当前云端模拟器不是 iOS15.4.1；旧系统 API 可用性由部署目标编译检查，运行行为仍需用户真机确认。

## 后续顺序

1. 在 TrollStore 中导入 0.1.1 iOS15 修复版并覆盖安装，先验证能否启动到首页和设置。
2. 若仍然闪退，获取此 App 的 .ips 崩溃记录，继续区分 dyld、签名、权限或其他运行期原因。
3. 用户在 App 内填写有效 API Key，按 README 的真机清单验收。

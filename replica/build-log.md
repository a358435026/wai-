# Build log

2026-11-26: S01–S04 rebuilt around full-screen conversation. Official API probes produced source, translation and PCM in both explicit directions. A later handshake check found an empty response UUID, so the earlier UUID-filter root-cause inference was retracted. Device capture/sending now has preflight and watchdog diagnostics; actual microphone retest remains pending. API key was supplied at process runtime only. CI and real-phone validation results will be recorded in VALIDATION.md.

0.2.0 final source b6ee9b3: 8 core tests and ARM64 iPhone archive passed. Two CI attempts failed to boot the cloud simulator before app UI tests could run. No new screenshot or device-runtime pass is claimed. Release IPA was downloaded and minimum iOS15.0/ZIP integrity/no embedded supplied key verified.

0.2.1: user device still has permission but no first PCM packet. Replaced input graph with AudioQueue capture, added offline microphone probe and raw callback/byte diagnostics, actual playback-level metering, and continuously redrawn fluid visual. Removed full-duplex speaker/AEC claim; speaker playback suppresses uploaded input, headphones allow duplex. Cloud verification pending.

User device result for0.2.1: callback count and microphone bytes increase continuously; speaking changes animation. Native capture and input feedback are now device-confirmed. Live AST caption/playback verification on that phone remains pending.

User then confirmed a real zh-en AST session on iPhone: Chinese source, English translation and English playback all work. This validates the native input-to-service-to-playback path, separate from visual fixtures. Long-session speaker echo and interruption testing are still outside this short device test.

0.2.1 build5: replaced the SwiftUI Menu label that failed AX scroll-to-visible with a normal 44pt button and native confirmation action panel. All10 core tests and3 UI tests passed in run45803138491. Final IPA integrity/version/minimum-iOS checks passed. Input/network/playback implementation is unchanged from the device-confirmed build4.

0.3.0:48-language source/target catalog with9 source dialects and auto mixed Chinese-English recognition. Invalid foreign-to-foreign and same-language pairs filtered;16 default speech targets; other targets automatically use actual S2T. Added searchable native navigation lists, swapping, persisted non-secret language preferences and explicit subtitle-only output setting. Provider comparison uses current primary docs; no untested provider adapter presented as working.

0.3.1: three existing UI flows passed, while the new searchable language selection did not reliably return to its parent. Replaced child environment dismissal with explicit parent-owned navigation state and strengthened the regression assertion. Build7 verification in progress. A transient incomplete Git tree upload was immediately restored from the complete preceding tree before rebuilding.

0.3.1 final:16 core and4 UI tests passed in run45823094801. Native screenshot confirms Spanish selection and enabled service subtitle-only mode. Downloaded final IPA, verified archive digests, build7, ARM64/iPhoneOS and minimum iOS15.0, and no supplied key. Representative official multilingual probes are recorded separately from simulator fixtures; all48 languages are not claimed device-tested.

2026-11-27 0.4.0: added official Bailian adapter, provider selection, isolated keychain credentials, host validation,60 target catalog/29 spoken outputs, item-based final-caption replacement and24k playback. User-authorized desktop English S2S probe passed; native archive and5 UI/24 core regressions pending. Existing audio capture untouched.

0.4.0 build8:24 core/4 existing UI passed; the new provider flow remained in Settings with keyboard covering the form save row. Reviewed the xcresult recording rather than assuming a Keychain failure. Build9 moves save to the navigation toolbar, supports keyboard submit and verifies the sheet has actually closed before continuing. Keychain OSStatus is now visible on failure; no claim of credential isolation pass yet.

Build9 still did not prove saving/dismissal; several slow-cloud taps also failed to expand menus. Build10 waits for enabled/hittable save, targets its center, stops UI tests after the first failure and surfaces save errors in an alert. No Keychain root cause is asserted without an observed error. Added failed/incomplete response rejection with a core regression.

Build10:25 core and4 existing UI passed. Alert evidence identified actual save failure as Keychain OSStatus -34018 (missing entitlement); earlier keyboard-only inference was insufficient. Build11 signs the simulator test app ad-hoc with an explicit app identifier and default keychain group. iPhone archive remains unsigned for TrollStore; storage is still genuine Keychain, never a plaintext/mock substitution.

0.4.0 build11 final:25 core/5 native UI passed in run45948441660 with genuine signed simulator Keychain. Provider setup/save/isolation/reload and automatic-source/Hindi selection passed. Final iPhone archive remains unsigned, min iOS15.0, build11 and ZIP/no embedded personal credentials or Host checked. English S2S/S2T and Hindi S2S API probes succeeded; phone24k playback remains explicitly unverified.

## 0.5.0 build12

将确认的原生风预览转为SwiftUI，新增语言国旗/自动识别globe、顶部语言条和交换、明确开始结束、真实音量球与滚动字幕、错误恢复、系统深浅色及辅助功能大字布局。保留服务/API/音频/凭据逻辑。新增两项UI场景，待CI。

## 0.5.0 build13

build12通过25核心与6/7原生UI，失败在旧仅字幕开关点按后仍为0。保留断言，改为等待可点按、定位行尾内32pt控件位置并等待状态生效，附点按前截图；重新验证而不跳过用例。另据截图修复辅助功能大字时语言条横排导致的单词拆行，改上下排；服务商辅助说明在该模式精简。

最终build13：25核心/7原生UI零失败；已目视检查国旗/双语字幕/深色大字/仅字幕状态截图；已验证ARM64真机IPA最低15.0并复制到Downloads。API与音频链路未变，本轮不作真机声音已验收的声明。

## 0.6.0 build14

用户提供的新Key在火山WS返回401 Invalid X-Api-Key，之前语音Key返回101；因此证据不支持双Key互相覆盖。引入HTTP鉴权分类及设置中不录音的建连测试。Keychain服务仍分隔。新增单连接、最多一次、兼容语种和语音模式的自动备用；默认开启，可关闭，百炼到火山须明确备用源语。不并行、不回放丢失音频，切换提醒重说最后一句。连接8秒未就绪或完整原文10秒无译文可触发；静音/外放抑制/播放中不切换，未说话不会启动健康计时。

新增30组中英葡西贸易词、自定义两列CSV/TSV/JSON导入。火山真实schema为request.corpus(100).glossary_list(10)，百炼为translation.corpus.phrases；两家空音频会话配置均通过，不声称所有术语已语义验证。API、音频、Keychain集成需原生回归及真机验收。

## 0.6.0 build15

编译前复查补上：词表页面返回语种选择时保留未保存草稿；填入英文示例时同步设置中英方向；明示UTF-8导入；Key输入拒绝附带汉字、控制字符与空格。build14的核心检查已通过，后续以build15完整回归为准。

## 0.6.0 build16

将缩短握手超时和迟滞切换严格绑定到存在兼容且已配置的备用服务：只有一把Key、备用Host缺失、方向不支持或已经换过一次时，保留正常20秒握手等待，不因备用策略中止唯一可用的慢会话。只关闭真正的网络/服务失败，不会无限来回切换。

## 0.6.0 build17

build16的33核心通过，9原生UI中7通过。失败录像明确显示：保存词表位于屏幕最底部/安全区附近，保存确认位于其下；诊断的本机麦克风入口被新增统计挤到可视区外。保存改固定导航栏并显示“已保存”，测试重新进入页面核对实际词文持久化；本机收音测试置于诊断页最前。另将热路径的译音模式计算与词表生成分离，避免每个译音包/音量刷新反复解析词表。

build17 的 33 项核心测试及 9 项原生界面测试全部通过。

## 0.6.0 build18

切换服务时沿用当前会话的输出模式。例如，火山只支持字幕的语种切到支持该语种播报的百炼时，当前会话仍仅输出字幕。结束会话后，下一次手动开始使用当时的设置。

33 项核心及 9 项原生界面测试通过。真机 IPA 校验结果见 VALIDATION.md。

## 0.6.1 build 20

依据实测 Fire HTTP 401 提供验证后保存 Key 的流程。连接中显示当前步骤和取消按钮，首选服务缺少 Key 时可启动兼容备用。通用贸易与电动车词库扩至 78 组，供中、英、葡、西使用。火山、百炼分别接受 78、100 条术语。用火山官方示例音频实测中译英字幕及译音返回。

## 0.6.1 build 21

build 20 的 34 项核心测试与 8 项界面测试通过，词表用例点按屏幕底部未进入词表页。移前词表入口及示例按钮，测试等待页面导航并在控件完整可见后点按。

build 21 的 34 项核心测试和 9 项原生界面测试全部通过，安装包校验通过。

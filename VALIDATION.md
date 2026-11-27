# 0.5.0 build13 最终验证 · 2026-11-27

- 源码提交01ededb8db894069142343af1aa3c99777fcd959；GitHub Actions https://github.com/a358435026/wai-/actions/runs/45997516127 全部成功。
- 25核心测试及7原生UI用例全部通过，0失败。覆盖字幕显示/隐藏、深色辅助功能大字、首页语言交换、凭据保存与两家隔离、目标语言搜索与真正仅字幕模式、语音状态显示、本机收音诊断入口。
- 已目视检查最终原生截图：国旗及双语字幕、普通字号首页、深色大字上下语言条、仅字幕开关开启及对应说明、百炼配置隔离。截图及UI输入均为合成测试数据，不能作为真机音频证明。
- build12曾25核心/6项UI通过，旧点按坐标未使仅字幕开关变为1；build13保留用例，校准控件点按位置并等待状态，开关及首页模式提示均验证通过。同时修复首轮截图中的大字英文拆行。
- iPhone IPA：0.5.0 build13、app.tongchuan.personal、ARM64/iPhoneOS，Info.plist最低15.0、Mach-O最低15.0.0，按iOS15.4.1门禁通过；248924字节。
- IPA SHA256：3d85d2b824bb4e18e97a4ad4d54e5e3ffb89b79876bf1bc6848b105e4117a98a。
- artifact ZIP SHA256：6d71ad9d2fab87f476e02b8c4d89a52183c4807a8fe5cbf6ea445820abc6fa8f，与GitHub一致。
- UI ZIP SHA256：27fc6a5687e92d7333a6934ae8238a0dc624f7a93f4ed6993d307835a47c7830，与GitHub一致。所有ZIP CRC、build13及未内置个人Host/Key检查通过。
- ASTClient、TranslationClient、InterpreterModel、AudioIO、PCMInputQueue、KeychainStore保持原有实现；本轮未调用真实付费API。用户此前已在0.2.1确认实际收音与翻译播报，0.4.0做过百炼代表性电脑API验证；新版手机收音、耳机与长时网络仍需覆盖安装后验收。
- 模拟器使用专属adhoc签名验证真实Keychain；设备IPA仍未签名，供TrollStore安装。旧0.4.0 IPA与源码归档保留。

---

# 0.4.0 build11 最终验证 · 2026-11-27

- 应用提交9fef6fdb5ec9bc9e8645a45fcea2bde55cc65b1d；成功构建：https://github.com/a358435026/wai-/actions/runs/45948441660。
- 25核心测试和5项原生模拟器UI用例全部通过，0失败。包含百炼Host填写、合成Key保存、切回火山无Bali凭据、再切回百炼仍已保存、自动源语言、印地语播报能力选择；既有字幕/设置/诊断/动态状态样例流程也通过。
- CI日志确认模拟器App已签名，使用真实系统Keychain；没有用明文或假存储来绕过-34018。Simulator entitlement仅应用于Simulator SDK；iPhone Release仍未签名供TrollStore安装。
- 已提取并目视检查原生百炼设置及印地语选择截图，截图中仅含明确的合成测试凭据与假Host。
- 最终IPA：0.4.0 build11，225801字节，ARM64/iPhoneOS，Info.plist最低15.0、Mach-O最低15.0.0，目标iOS15.4.1门禁通过。
- IPA SHA256：af11106d86602ed4b8bfe05f3521206aa103fd3f310c69c963524ccf28d4c8b5。
- artifact ZIP SHA256：5570734438a395909f53c3d4d6c66fc0c7b23aa622bbfe80dd1a1c08397182a1，与GitHub一致；ZIP CRC、版本build11、未内置用户Key或个人Host检查通过。
- UI ZIP SHA256：b3131459978cea0b77cc6b50f3ceb619bc0ad3d52856c9b89e9fb2e3a797d4ea，与GitHub一致。
- 代表性电脑真实API短测已通过英文S2S、英文S2T（0音频字节）及印地语S2S。新版iPhone采集/24kHz译音/长时与弱网仍需用户真机验证；模拟器状态样例不冒充真实麦克风或扬声器证明。

---

# 0.4.0 build11 模拟器钥匙串签名修复（验证中）

build10的25核心及4项既有UI全部通过。新增配置用例的错误弹窗明确显示Keychain OSStatus -34018；Apple将其定义为缺少所需entitlement。之前仅从未关闭的设置页推断键盘/点按问题不充分，现据实际错误收窄原因。旧CI关闭了模拟器签名，无法验证真实Keychain保存。

build11仅为Simulator SDK设置application-identifier和keychain-access-groups，UI步骤启用本地ad-hoc签名；真机Release仍未签名，交给用户TrollStore处理。凭据代码不改为明文偏好或假Keychain。缺签名错误也不再误提示只需解锁手机。

应用/配置提交9fef6fdb5ec9bc9e8645a45fcea2bde55cc65b1d；https://github.com/a358435026/wai-/actions/runs/45948441660。
参考：https://developer.apple.com/documentation/security/errsecmissingentitlement。

---

# 0.4.0 build10 配置回归（验证中）

build9顶部保存已显示，但UI测试仍未确认保存页关闭；当轮其他入口也有点按未展开的失败。不能单凭此断言Keychain已损坏或已通过。新测试等待按钮存在、启用且可点后在按钮中心点按，确认设置页关闭；遇到断言失败立即停止，避免继续操作被遮挡页面。保存错误改成弹窗，确保输入/钥匙串错误不会藏在表单下方。UI步骤窗口增至20分钟，包含模拟器编译及测试。

同时补充模型响应failed/incomplete状态处理，避免把失败响应当成正常生成。新增一项核心用例；期望25核心和5原生UI检查，结果待补。应用提交fc6d84c6dd490caa2ff9cca3c7ad664c0bf333db。25核心及iPhone编译通过；https://github.com/a358435026/wai-/actions/runs/45946889640。

- build10 IPA225782字节；ARM64/iPhoneOS；Info.plist/Mach-O最低iOS15.0；版本/CRC/无内置用户Key或个人Host检查通过。
- IPA SHA256：a6d2acbd5c8b68eee01cadda127814de88c3a276cdab1246eb2b3e2037a7f609。
- artifact SHA256：6b921cd9a8e511bd3adf52fcebccdc1eeafb21a941fc7694863453947eb6fbc0，与GitHub一致。

---

# 0.4.0 build9 保存入口修复（验证中）

首轮24项核心和4项既有UI用例通过；新增百炼配置用例在保存后点击被设置页遮挡的首页按钮失败。原始测试录屏确认键盘仍打开、底部保存入口不可见，未完成设置页关闭，不能将该用例记为Keychain隔离通过。

build9将“保存并返回”移至始终可见的顶部工具栏，SecureField键盘提交也执行保存；钥匙串错误显示OSStatus以便定位。新增测试先确认设置页消失，再操作首页。去除主设置页中不必要的采样率说明，采样率仍保留在连接诊断。

修复提交：ddbac9c61efec2671ddfcc5133fdb4076b397f3c；https://github.com/a358435026/wai-/actions/runs/45944199937。

---

# 0.4.0 百炼接入验证（进行中）

- 应用实现提交48ba172aba3018ee2739c364ce80023819044afc；构建：https://github.com/a358435026/wai-/actions/runs/45942215241。
- 24项核心测试和iPhone目标Release编译通过。核心新增百炼Host白名单、握手就绪门禁、JSON/base64、字幕最终替换、交错item、100条历史上限、60/29目录和采样率配置测试。
- IPA0.4.0 build8，223511字节，ARM64/iPhoneOS；Info.plist/Mach-O最低iOS15.0，目标15.4.1门禁通过。
- IPA SHA256：7fdc835c6c75f2955c968c4bee800f0d764f86f1f3080388987394f7e64ab038。
- 外层ZIP SHA256：0c16fdc03593471049bca9ca99e27d3c3beec67bf60fd61c7d45699e8200fce0，与GitHub一致。ZIP CRC、build8以及未嵌入两家用户Key或个人API Host均已检查。
- 原有4个UI流程及新增服务商切换/Host字段/合成Key隔离/自动源语言/印地语选择流程等待本轮结果。UI仅使用明确的合成无效Key，不发起计费请求。
- 本机真实百炼补测，使用原有代理、官方样例及用户授权Key，每次12秒音频+0.5秒尾静音：中译英仅字幕157包，原文/译文正常、0音频字节，session.finished；中译印地语157包，字幕和35音频分片、514560字节24kHz PCM（10.72秒），正常结束。之前英文S2S短测见下方。
- 不把电脑API短测或模拟器UI等同于新版iOS客户端的真机采集/24kHz扬声器播放验收。用户iPhone新版本仍待安装确认。

---

# 百炼官方实时同传短测 · 2026-11-27

使用用户明确授权提供的百炼Key，只在临时进程环境中传入，不写源码或结果。通过现有127.0.0.1:10809代理连接控制台实际业务空间API Host，未修改VPN。截图中的先前尝试将Key填入Host位置，在本机验证阶段退出，没有发起同传请求。

- 模型：qwen3.8-livetranslate-flash-realtime；12秒官方样例输入+0.5秒静音，157包。
- session.created/session.updated均确认后上传；中文原文、英文译文均返回。
- 33个response.audio.delta，460800字节PCM16/24kHz/mono，约9.6秒；session.finished正常完成。
- 已检查生成WAV的声道、位宽、采样率、非零音频能量；提供用户试听，不冒充人工听感评价。
- 这是代表性电脑API短测，验证该Key可调用本模型及字幕和译音路径，不是长期稳定性/跨平台质量比较。当前iOS0.3.1仍只接火山，引入百炼需要后续适配及真机验证。
- 测试器可读取本机bailian-host.txt预填非凭据的Host；该文件不写入公共仓库。Key仍只通过隐藏输入读取。

---

# 0.3.1 最终结果

- 最终构建/验证提交：a9952c5a8031e25547fde89d9b5b77811771d8ee；https://github.com/a358435026/wai-/actions/runs/45823094801。
- 16项核心测试和4项模拟器UI用例全部通过。语言搜索、选择后返回、交换、首页语种及真正仅字幕模式提示通过；设置、诊断入口、字幕显示和播报状态样例通过。
- 已提取并目视检查原生语言设置截图：中文→西班牙语，服务端仅字幕开关开启；不使用网页或绘图代替原生验证。
- 最终IPA为0.3.1 build7，180488字节，ARM64/iPhoneOS，Info.plist/Mach-O最低iOS15.0，支持目标系统15.4.1。
- IPA SHA256：0262c4caadae7500f1d42dc0811369cf44841e9d6d3c2b128a666814dadaa4b1。
- 外层ZIP SHA256：eb09330dfc88a830da60950c50864835472afef11e58e145fef9cf69b9ded847，与GitHub digest一致；内外ZIP CRC通过，无内置用户Key。
- UI产物ZIP SHA256：de250c074bdc932b4cce58d526ae0db429564c4aed2d76f5cf63517995b8db40，与GitHub digest一致。
- 0.3.1语言功能尚未逐一在用户iOS15.4.1真机验证；代表性多语种真实API短测及0.2.1用户真机结果保留在下方。模拟器样例不冒充真实收音/译音证明。

---

# 0.3.1 语言选择修复验证

- 应用实现提交6afa8a28a2b1361e6b93739d48861fcb1a871feb；build7；最低iOS15.0，支持目标15.4.1；180488字节。
- IPA SHA256：6668df4b7bdc48f17d7e23836826e6b1e19555510d9e8e3c4b3801caf4b4f4f7。
- 外层artifact SHA256：90920288a53abea33a307d373229c1f23a8ba71232dc1e54f30b50c2fb578409，与GitHub一致。ZIP CRC、ARM64/iPhoneOS、版本、build7检查通过，无内置用户Key。
- 16核心测试、真机目标编译通过。语言搜索、选择返回、两次交换和首页西班牙语显示断言通过。
- 当次4个UI用例中2个失败：设置菜单第一次触摸后未出现；字幕开关标签点按没有改变开关值，截图确认仍关闭。没有将它们标为通过。
- 后续测试改为等待菜单，必要时再次打开；点按原生开关本体并断言开关值开启，再验证首页模式提示。应用运行代码不变。回归：https://github.com/a358435026/wai-/actions/runs/45823094801。
- 云端模拟器不是用户iOS15.4.1；0.3.x新语种尚未逐一真机验收。0.2.1用户真机中文→英文闭环结果见下方。

---

# 0.3.0 多语种验证

按2026-11-26官方目录实现48语言、9输入方言和中英混合识别；默认译音目标16种，其他目标自动仅字幕。语言目录与默认播报能力来自官方接入说明，不把所有目标的默认音色可用性混为一谈。
本次不改动已验证的AudioQueue输入和AVAudioEngine播放器。新增真实s2t请求编码、合法组合过滤、搜索/交换、模式提示与非敏感偏好保存。
- 应用源码：4064640621d4924a6fcdbd5820e1e1ac13b84aa2
- 构建：https://github.com/a358435026/wai-/actions/runs/45811073102
- 16项核心测试通过，iPhone目标Release编译与系统版本门禁通过。
- IPA0.3.0 build6，180867字节，ARM64/iPhoneOS，Info.plist/Mach-O最低iOS15.0。
- IPA SHA256：a90151299364a26959f5807239e447b8c18ea84b5e71c7fb4850fec560abb52d。
- Artifact ZIP SHA256：b12e4c79daa2c377f4a85af225a6fed01cf921ae488f2d68630779a04896130f，与GitHub digest一致，内外ZIP校验通过，扫描未发现用户Key。
- 首轮UI时限8分钟包含模拟器编译，超时；延长至15分钟后3项UI通过，新增语言测试发现搜索选择后未可靠返回父页，交换按钮不可达。未将其记为通过。
- 0.3.1 build7改为父页持有NavigationLink路由状态，语言列表只回传选择，不再调用可能作用于搜索状态的dismiss。修复构建：6afa8a28a2b1361e6b93739d48861fcb1a871feb；https://github.com/a358435026/wai-/actions/runs/45820220747。核心测试16项和真机目标编译通过，UI结果待补。
- 期间一次提交因未传入基础tree导致不完整源码树，CI在缺少Package.swift处立即失败；已基于完整tree恢复并确认Package.swift存在，未交付该失败提交产物。

## 官方接口多语种短测

使用用户已授权的火山Key、既有代理和官方demo测试音频，每次150包、约12秒；不使用用户录音，不改变VPN。
- 中文→日语S2S：字幕、42音频分片、383890字节PCM（约12.0秒），正常SessionFinished。
- 中文→西班牙语S2S：字幕、30音频分片、299786字节PCM（约9.37秒），正常结束。
- 中文→印尼语S2S：字幕、39音频分片、352616字节PCM（约11.02秒），正常结束。
- 中文→印地语S2T：返回字幕，无音频事件，0音频字节，正常结束。
- 中文→西班牙语S2T：首次55000001内部错误，相同请求单独复测成功，字幕正常、0音频字节；未将失败隐藏或推断为固定配置错误。
- 西班牙语→中文S2S：用上述官方样例产生的西班牙语译音输入，首次等待响应超时，相同配置单独复测成功：118包输入、返回字幕和21段中文音频、189636字节PCM（约5.93秒），正常结束。

这些是代表性短测，不是48种语言的逐一真机验收，也不是跨平台稳定性对比。Qwen及DeepSeek仅查证官方接口/计费，没有新供应商账号密钥测试。本次用户明确选择先多语种实时同传，不增加DeepSeek按句模式。旧版本记录在下方保留。

---

# 0.2.1 验证记录

以下顶部为当前版本结果；分隔线后的0.2.0/0.1.1记录保留历史状态，不代表当前版本仍未验证。

用户截图确认0.2.0通过权限申请后，首包检查未拿到有效PCM。这能定位到本机音频采集/交付链，不能仅凭截图区分录音引擎、格式转换或异步交付中的哪一处。
新版替换整条输入链为AudioQueue，保留原生回调与字节计数；播放mixer的实际音量驱动输出动态反馈。新增本机收音测试，不需要Key或网络。
- 应用源码提交：05a7f82def3a348aeb62767a64391506d9e16efc
- 构建：https://github.com/a358435026/wai-/actions/runs/45801062086
- 10项核心测试通过，包含PCM16小端音量、静音、半包拼接与原协议互操作。
- 真机Release编译通过；ARM64/iPhoneOS；Info.plist最低系统15.0，Mach-O最低系统15.0.0；0.2.1 build4。
- IPA 155761字节；SHA256 8afa7a4c3bb5fd53bbbbc4e7182e6bad036833b13752f367a8c054a72ff1b5e4。
- Artifact ZIP SHA256 4cf823357266ed0d33f08ab799513142c45fd57ab569de2664dd787e2a7cffb8，与服务端digest一致。内外ZIP完整性通过。
- 安装包扫描未发现用户提供的API Key，无内置用户凭据。
- b4模拟器真实截图和测试录屏已导出，字幕显示/隐藏通过；另外两项UI测试因SwiftUI Menu辅助功能点按失败。没有把它误记为应用崩溃。
- b5将更多入口换为44pt普通按钮和系统操作面板；收音/网络/译音代码未变。
- b5应用源码提交：6d01faf799a48cb700b1d84a93da599e084df664
- b5构建：https://github.com/a358435026/wai-/actions/runs/45803138491
- b5核心测试10项及模拟器UI用例3项全部通过；设置、场景、诊断入口、字幕开关和播报状态样例已验证。
- 最终IPA：0.2.1 build5，157111字节，ARM64/iPhoneOS，Info.plist/Mach-O最低系统15.0。
- b5 IPA SHA256：5bad45410d5faf8e1d01d116f7acedd7aa4be3608621624c1f2fbe707614cdca。
- b5 Artifact ZIP SHA256：c1fad5617c2a9a0fae0525ea5a0302116aecba8961b10d530650b32e6fc8d502，与服务端digest一致。
- b5二进制版本/最低系统/内外ZIP校验通过，未发现用户提供的密钥。
- 动画预览来自b4原始xcresult录屏，只裁切时段并转码，展示DEBUG播报状态样例，不是实际麦克风/扬声器录制；b5动画实现相同。

本机麦克风测试使用与同传相同的AudioQueue路径，且不创建WebSocket、不需要API Key。用户已在iPhone本机测试中确认：录音回调次数与麦克风字节持续增长，说话时动画有变化。由此确认0.2.1输入采集与输入音量反馈已在用户真机恢复；用户随后以中文→English正式会话确认：中文、英文字幕和英文播报均正常，真机采集→AST推流→双语字幕→译音播放闭环已通过。长时间外放防回声、弱网、耳机与中断场景仍待持续验证。UI状态样例测试本身不作为真实播报证据。

---

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

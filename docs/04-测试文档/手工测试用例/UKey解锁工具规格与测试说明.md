# UKey 解锁工具规格与测试说明

## 1. 文档目的

本文档面向开发、联调和测试人员，说明 `ukey/` 独立系统应用的当前产品规格、业务规则、测试准备、手工用例、日志判定和发布阻断条件。

- 被测应用名称：`ukey解锁工具`
- bundleName：`com.ukey.pin`
- 页面入口：`pages/Index`
- CustomAuth appService：`ICustomAuthenticatorV1`
- CustomAuth 协议版本：`1`
- CustomAuth 类型：`128`
- 认证信任等级：`ATL3`
- 目标设备：HarmonyOS 2in1
- 设计依据：`docs/03-模块设计/UKey管理与认证器接入设计说明.md`

本文档描述当前代码的 As-Is 规则。若测试现象与本文档不一致，先记录设备版本、HAP 哈希、系统选中的认证器和完整日志，再由开发核对代码与模块设计；不得用另一个 demo 的行为直接替代本工具结论。

## 2. 名词和测试输入

| 名称 | 含义 | 当前规则 |
|---|---|---|
| 系统 PIN | 被测 OS 账户的系统登录 PIN，用于获取 PIN token 后添加或删除系统 CustomAuth 凭据 | 使用设备真实 PIN，不是应用内固定测试值 |
| UKey 密码 | UKey 自身密码，用于添加凭据和 CustomAuth 解锁认证 | 当前开发阶段固定为 `666666` |
| 首把 UKey | 首次成功添加系统凭据时建立可信绑定的 UKey | 绑定建立后不可在应用内更换 |
| 第二把 UKey | fingerprint 与首把绑定不同的其它 UKey | 不注册、不替换、不允许认证成功 |
| UKEY解锁凭据 | 系统中的 CustomAuth 凭据及应用本地保存的 credentialId/templateId 映射 | 按 OS 账户分别保存 |
| active | 目标 UKey 在位且凭据可用于验证 | 验证按钮可用 |
| inactive | 凭据仍保留，但目标 UKey 不在位 | 不允许验证，不自动删除凭据 |
| failed | 凭据添加或删除只完成了一部分 | 保留失败信息，允许后续重试 |
| Model B | 认证器发出 `onPrompt`，系统提交加密 passcode，认证器解密并校验后返回结果 | 本工具强制使用 |

系统 PIN 与 UKey 密码是两个独立输入和两条独立校验链路。即使某台实验设备的系统 PIN 也设置为 `666666`，测试记录仍必须分别填写两项。

## 3. 产品规格和业务规则

### 3.1 页面与运行方式

- 页面固定展示 `UKey 锁屏认证` 开关、`当前状态`、凭据操作区、`凭据认证验证`、`UKey设备` 和 `UKEY解锁凭据`。
- 页面没有手动刷新按钮，也不在前台周期轮询。
- 页面进入、开关变化、USB 插拔、添加/删除凭据和认证验证完成后触发状态同步。
- USB attach 后按约 `300ms / 1000ms / 2500ms` 复查设备，等待 DDK 枚举稳定。
- 点击窗口 X 只隐藏窗口，不退出后台运行时；点击状态栏图标恢复窗口。
- 从系统 dock/任务管理执行应用级关闭时允许真实退出。

### 3.2 UKey 识别规则

- 默认通过 DDK `queryDevices(BusType.USB)` 枚举设备，必要时用 `usbManager.getDevices()` 补充详情。
- 有 SN 时 fingerprint 为 `SN:<大写Serial>`，匹配只比较 SN。
- 无 SN 时生成弱 fingerprint：`VID:xxxx PID:xxxx|WEAK:<PRODUCTNAME>|<DESCRIPTION>`，只做完整字符串精确匹配。
- 多个相同 VID/PID 设备同时在场时，不得把其中一台的 SN 复用给另一台。
- USB 候选仅接纳设备级或接口级 Mass Storage，以及排除键鼠后的 HID；当前不启用 UKey VID/PID 或产品名特征表，以默认兼容不同厂商 HID UKey。由于 USB 描述符无法证明设备一定是 UKey，游戏手柄、扫码器等其它非键鼠 HID 当前也按候选处理。
- USB Hub、HID Boot 键盘/鼠标，以及名称明确为 keyboard、mouse、touchpad 的普通输入设备不计入 UKey 候选；Smart Card/CCID、厂商自定义类、打印机、摄像头、音频和通信等其它 USB 类型同样不计入候选。
- 复合设备必须遍历 `configs[].interfaces[]` 判断功能类别，不能只依赖设备级 class；接口级 Mass Storage 或非键鼠 HID 可进入候选。
- 无候选时添加失败；存在多把有效候选设备时添加失败；普通键盘鼠标与一把 UKey 同时连接时仍按单把 UKey 处理。设备筛选调整不改变现有无候选、多候选和已绑定目标缺席提示。

### 3.3 首把绑定规则

- 只有“当前唯一目标 UKey 在位 + 系统 PIN 正确 + UKey 密码正确 + 系统凭据添加成功”后才建立首把绑定。
- 仅检测到设备、密码错误或系统凭据添加失败时不得建立绑定。
- 首把绑定的 fingerprint、deviceId、deviceName、boundAt 和 stableIdentifier 建立后不可覆盖。
- 删除凭据、密码错误、锁定、拔插、重启和重新添加凭据都不能更换首把绑定。
- 应用内没有解绑或换绑入口。只有卸载或显式清除应用数据后，才可能重置本地绑定；执行前必须先处理系统侧残留凭据。

### 3.4 凭据添加规则

- 添加按钮要求系统 PIN 和 UKey 密码均非空，并且目标 UKey 在位。
- UKey 密码当前固定为 `666666`。
- 添加流程枚举本机全部 OS 账户，并为缺失账户分别添加 CustomAuth 凭据。
- 系统已有凭据时，credentialId 命中当前首把绑定记录的视为自己的凭据并恢复；其它 CustomAuth 凭据使用本次系统 PIN 清理后再继续。
- `getAuthInfo(CUSTOM_AUTH=128)` 返回 `12300002 Parameter invalid` 时按当前没有 CustomAuth 凭据处理。
- 重复点击添加不得为同一用户重复创建等价凭据。
- 部分用户添加失败时保留已成功用户记录，整体显示部分失败，后续添加只补缺失用户。
- 添加流程结束后，页面必须清空系统 PIN 和 UKey 密码输入框。

### 3.5 凭据删除规则

- 删除只要求系统 PIN，不要求 UKey 密码。
- 删除不要求目标 UKey 在位、凭据为 active 或开关已打开。
- 删除按已保存的所有 OS 账户凭据逐个执行。
- 全部删除成功后清空 activeCredential 和可信绑定中的 userCredentials，但保留首把 UKey 身份。
- 部分删除失败时保留失败记录，允许用户再次输入系统 PIN 重试。
- 删除流程结束后必须清空输入框。

### 3.6 插拔、重启和开关规则

- 拔出首把 UKey 不自动删除系统凭据，也不清除本地凭据；状态变为 inactive。
- 重新插入同一把 UKey 后状态恢复 active。
- 只插入第二把 UKey 时不能恢复 active，也不能认证成功。
- 启动对账第一次未找到首把 UKey 时，以 `500ms` 间隔最多查询 3 次；仅连续查询成功且均未匹配时才降为 inactive。
- DDK 查询异常时保留原生命周期，不把基础设施错误解释为 UKey 已拔出。
- 关闭 `UKey 锁屏认证` 开关后保留已有凭据，但后续认证必须失败。
- 重新打开开关只做状态对账，不在后台自动添加或删除凭据。

### 3.7 UKey 密码和锁定规则

- 密码错误次数按首把 UKey fingerprint 保存。
- 正确密码 `666666` 校验成功后，错误次数归零。
- 连续错误达到 5 次后进入 locked。
- locked 后添加凭据和 CustomAuth 解锁认证都失败，不再继续增加次数。
- 当前页面没有解除锁定入口；需要重置测试状态时，应按测试环境清理流程执行，并同时核对系统凭据和首把绑定状态。

### 3.8 CustomAuth 和密码学规则

- 本工具强制 `PASSCODE_PROMPT_ENABLED=true`，不允许直接绕过 prompt 完成认证。
- `beginAuthenticate` 先匹配开关、首把 UKey fingerprint 和当前 userId 的 credentialId/templateId。
- prompt payload 通过 AES-256-GCM 发送 RSA-4096 公钥；系统使用该公钥执行 RSA-OAEP-SHA256 加密 passcode。
- 认证器使用同一会话的私钥解密，空 passcode、错误密码、锁定、目标 UKey 缺席或提交密码后 UKey 被拔出都必须失败。
- 成功密码的明文字节必须为 `54,54,54,54,54,54`，即 ASCII `666666`。
- 六个 `0,0,0,0,0,0` 是六个 NUL 字节，不是字符串 `000000`；出现该结果按系统 passcode 传输链路故障处理。
- 每个模板的 SecurityAsset 新记录为 68B：`sharedKey(32B) + authenticatorSecret(32B) + seq(4B LE)`。
- 旧 72B 记录允许在首次读取时迁移为 68B；迁移失败不得认证成功。

### 3.9 多认证器应用共存规则

- 同机可以安装多个 CustomAuthenticator HAP，但一次认证只应由系统选中的 bundle/templateId 执行。
- 本工具验收只认 `customAuthenticatorBundleName=com.ukey.pin`。
- `com.demo.customauthenticator` 的直接认证成功、Model A 成功或密码 `222222` 结果不能证明本工具通过。
- 若密文使用认证器 A 的公钥生成，却交给认证器 B 的私钥解密，RSA-OAEP 通常直接校验失败，不会稳定解出六个 NUL 字节。

## 4. 测试环境和数据准备

### 4.1 必备条件

- 一台目标 2in1 设备，记录完整系统版本。
- `com.ukey.pin` 系统签名 HAP，记录文件大小、时间和 SHA-256。
- 一把作为首把绑定的 UKey A，记录 SN。
- 一把 fingerprint 不同的 UKey B，用于第二把拒绝测试。
- 可选 USB Hub、键盘、鼠标、触控板，用于候选过滤测试。
- 至少一个已设置系统 PIN 的 OS 账户；多账户测试需准备两个及以上本地账户。
- 测试人员知道系统 PIN；UKey 密码使用 `666666`。

### 4.2 三类测试基线

| 基线 | 用途 | 数据要求 |
|---|---|---|
| 干净安装 | 首把绑定、首次凭据添加、基础发布验收 | 无本地绑定、无本工具 CustomAuth 凭据、密码未锁定 |
| 保留数据升级 | `hdc install -r` 升级兼容性 | 保留绑定、active/inactive 凭据和密码状态 |
| 日常回归 | 页面、插拔、认证和日志快速复测 | 使用已知绑定和可恢复的 active 凭据 |

干净安装前应优先在旧版本页面使用正确系统 PIN 删除 UKEY解锁凭据，再卸载应用。直接卸载或清数据后必须重新查询系统 CustomAuth 凭据，确认没有无法归属的残留；不能只看到页面空白就认为环境已清理。

### 4.3 安装检查

```powershell
hdc list targets
hdc install -r ukey\hapsigner\signApp.hap
hdc shell bm dump -n com.ukey.pin
hdc shell aa start -a EntryAbility -b com.ukey.pin
Get-FileHash -Algorithm SHA256 ukey\hapsigner\signApp.hap
```

`bm dump` 至少核对：

- bundleName 为 `com.ukey.pin`。
- `appDistributionType` 为 `os_integration`。
- 应用具备系统应用权限等级。
- `ICustomAuthenticatorV1` appService 存在。

## 5. 快速冒烟测试

| 步骤 | 操作 | 预期结果 |
|---|---|---|
| 1 | 安装并启动 HAP | 页面标题为 `ukey解锁工具`，无白屏 |
| 2 | 插入 UKey A | `UKey设备` 显示设备名称和 Serial |
| 3 | 输入正确系统 PIN 和 UKey 密码 `666666`，点击添加凭据 | 显示添加成功，UKEY解锁凭据为 active |
| 4 | 在验证卡片输入 `666666` 并点击验证 | 系统选中 `com.ukey.pin`，触发 Model B，最终认证成功 |
| 5 | 拔出 UKey A | 凭据仍显示但变为 inactive，验证不可用或失败 |
| 6 | 重新插入 UKey A | 凭据恢复 active |
| 7 | 拔出 A，仅插入 UKey B | 不得恢复 active，不得认证成功 |
| 8 | 输入系统 PIN 删除凭据 | 删除成功；首把绑定保留，凭据卡片为空 |
| 9 | 点击窗口 X，再点击状态栏图标 | 先隐藏，后恢复；后台运行时未退出 |

任一步失败即停止宣称冒烟通过，保存日志后进入对应完整用例定位。

## 6. 完整手工测试矩阵

### 6.1 安装与页面

| ID | 场景 | 操作 | 预期 |
|---|---|---|---|
| UKEY-ENV-001 | 系统应用安装 | 安装 HAP，执行 `bm dump` | 包名、分发类型、权限和 appService 正确 |
| UKEY-UI-001 | 页面结构 | 启动应用 | 开关、当前状态、凭据操作、验证、设备和凭据卡片完整 |
| UKEY-UI-002 | 无设备空态 | 不插 UKey 进入页面 | UKey设备内容为空，不显示伪设备 |
| UKEY-UI-003 | 窗口隐藏恢复 | 点击 X，再点状态栏图标 | X 只隐藏；托盘点击恢复 |
| UKEY-UI-004 | 应用级关闭 | 从系统任务入口关闭应用 | 应用真实退出，不被隐藏逻辑拦截 |

### 6.2 设备识别与绑定

| ID | 场景 | 操作 | 预期 |
|---|---|---|---|
| UKEY-DEV-001 | 单把 UKey | 只插入 A | 显示 A 名称和 Serial，可进入添加流程 |
| UKEY-DEV-002 | 普通输入外设过滤 | 同时连接 A、键盘、鼠标、触控板、Hub | 仍按单把 UKey 处理，普通外设不展示为 UKey |
| UKEY-DEV-003 | 多个有效候选 | 同时插 A、B，或同时插入两个存储/UKey 候选后添加 | 沿用原提示要求只保留一把，不添加凭据 |
| UKEY-DEV-004 | 存储设备 | 分别插入设备级 class `0x08` 和接口级 class `0x08` 的存储设备 | 均可进入候选，设备级 class `0x00` 的复合存储设备不能漏识别 |
| UKEY-DEV-005 | 非键鼠 HID 默认放行 | 分别插入 `Longmai-GM3000`、其它厂商非键鼠 HID UKey 和普通游戏手柄 | 均进入候选，不要求命中 VID/PID 特征表或 USB Serial 非空 |
| UKEY-DEV-006 | 其它 USB 类型过滤 | 分别插入 Smart Card/CCID、厂商自定义类、打印机、摄像头、纯音频、纯通信设备 | 均不进入候选，不展示为 UKey，不影响唯一存储/HID 候选添加 |
| UKEY-DEV-007 | 非键鼠 HID 与键鼠区分 | 插入非键鼠 HID UKey，再分别连接 Boot 键盘和鼠标 | 非键鼠 HID UKey 保留；键盘和鼠标被过滤 |
| UKEY-BIND-001 | 首次成功绑定 | 干净环境下使用 A 正确添加 | 绑定和凭据只在全部前置成功后产生 |
| UKEY-BIND-002 | 密码失败不绑定 | 干净环境下使用错误 UKey 密码添加 | 添加失败，不产生首把绑定 |
| UKEY-BIND-003 | 第二把不可替换 | A 已绑定，拔 A 插 B，再添加 | 提示插入已绑定目标 UKey；绑定仍为 A |
| UKEY-BIND-004 | 删除后仍不可换绑 | 删除 A 的凭据，再插 B 添加 | B 仍不能替换 A |

### 6.3 输入、添加和删除

| ID | 场景 | 操作 | 预期 |
|---|---|---|---|
| UKEY-CRED-001 | 输入门禁 | 系统 PIN 或 UKey 密码留空 | 添加按钮不可用或提示对应输入 |
| UKEY-CRED-002 | 错误系统 PIN | UKey 密码正确、系统 PIN 错误 | PIN token/添加失败，不保存成功凭据 |
| UKEY-CRED-003 | 正确添加 | 两项输入正确 | 所有可用 OS 账户分别得到凭据 |
| UKEY-CRED-004 | 重复添加 | 已 active 时再次正确添加 | 不重复创建；已有记录恢复或保持 active |
| UKEY-CRED-005 | 多账户部分失败 | 构造一个账户添加失败 | 成功账户保留，页面显示部分失败，后续只补失败账户 |
| UKEY-CRED-006 | 无 UKey 删除 | 拔出 A，输入系统 PIN 删除 | 删除允许执行且成功，不要求 UKey 密码 |
| UKEY-CRED-007 | 关闭开关删除 | 关闭开关后删除 | 删除允许执行 |
| UKEY-CRED-008 | 删除保留绑定 | 删除全部凭据后重新插 B 添加 | 凭据清空但首把仍为 A，B 不可绑定 |

### 6.4 密码与锁定

| ID | 场景 | 操作 | 预期 |
|---|---|---|---|
| UKEY-PWD-001 | 正确密码 | 输入 `666666` | 校验成功，失败次数归零 |
| UKEY-PWD-002 | 错误密码计数 | 连续输入 4 次错误密码 | 每次失败并显示剩余次数，尚未 locked |
| UKEY-PWD-003 | 第 5 次锁定 | 第 5 次继续输入错误密码 | 返回 locked，剩余次数为 0 |
| UKEY-PWD-004 | 锁定后正确密码 | locked 后输入 `666666` | 仍失败，不允许绕过锁定 |
| UKEY-PWD-005 | fingerprint 隔离 | 在可控测试数据中切换不同 fingerprint | 错误次数不应串到另一 fingerprint；第二把仍不能替换首把 |

锁定测试会改变持久化状态，应安排在该轮环境末尾，或预先准备可恢复的专用测试环境。

### 6.5 插拔、开关和重启

| ID | 场景 | 操作 | 预期 |
|---|---|---|---|
| UKEY-LIFE-001 | 拔出首把 | active 时拔 A | 不删凭据，状态转 inactive，认证失败 |
| UKEY-LIFE-002 | 插回首把 | inactive 时插回 A | 状态恢复 active |
| UKEY-LIFE-003 | 第二把在位 | A 缺席，只插 B | 状态保持 inactive，认证失败 |
| UKEY-LIFE-004 | 关闭开关 | active 时关闭开关并认证 | 凭据保留，但认证失败 |
| UKEY-LIFE-005 | 打开开关 | 重新打开开关 | 只对账，不新增凭据；A 在位时恢复可用 |
| UKEY-LIFE-006 | 重启识别延迟 | A 在位时重启，观察启动对账 | 首次短暂无设备不立即错误降级；最多 3 次查询后收敛 |
| UKEY-LIFE-007 | DDK 查询异常 | 构造/观察设备查询错误 | 保留原生命周期，不误判为拔出 |

### 6.6 CustomAuth 验证和真实锁屏

| ID | 场景 | 操作 | 预期 |
|---|---|---|---|
| UKEY-AUTH-001 | 页面正确密码验证 | active 时输入 `666666` 点击验证 | `com.ukey.pin` Model B 全链路成功，最终 `onResult=0` |
| UKEY-AUTH-002 | 页面错误密码验证 | 输入非 `666666` | provider 返回 mismatch，认证失败 |
| UKEY-AUTH-003 | 空 passcode | 构造空提交或系统 no-PIN 分支 | 本工具返回失败，不允许直接成功 |
| UKEY-AUTH-004 | prompt 后拔出 | prompt 触发后、提交或 finish 前拔 A | 认证失败 |
| UKEY-AUTH-005 | 真实锁屏解锁 | 锁屏后由系统触发 CustomAuth | 同样必须选中 `com.ukey.pin`、走 prompt 并成功返回 token |
| UKEY-AUTH-006 | 多认证器共存 | 同时安装 demo 和本工具 | 记录系统实际选择的 bundle；只有选择 `com.ukey.pin` 的结果计入本工具 |
| UKEY-AUTH-007 | 六个 NUL 字节 | 观察到解密 `0,0,0,0,0,0` | 判为 passcode 传输链路失败，不记为用户输入 `000000`，不记为通过 |

### 6.7 升级和兼容

| ID | 场景 | 操作 | 预期 |
|---|---|---|---|
| UKEY-UPG-001 | 保留数据升级 | active 状态执行 `hdc install -r` | 首把绑定、凭据和开关状态保留 |
| UKEY-UPG-002 | inactive 升级 | 拔 A 后升级，再插回 A | 升级后仍能从 inactive 恢复 active |
| UKEY-UPG-003 | locked 升级 | locked 状态升级 | 锁定状态保留，不因升级自动解锁 |
| UKEY-UPG-004 | 72B 密钥迁移 | 使用专用历史数据环境触发读取 | 成功迁移为 68B；异常记录不得认证成功 |

## 7. 日志采集与结果判定

### 7.1 建议命令

```powershell
hdc shell hilog -x | rg "VERIFY_CHAIN|CustomAuthVerifier|CustomAuth.Service|CustomAuth.Stub|CustomAuth.Crypto|CustomAuth.UKeyProvider|Screenlock-UnlockPolicyManager|custom_auth_auth_context"
```

执行测试前记录开始时间；结果中至少保留 requestId、templateId、bundle、明文摘要、resultCode 和最终 SceneBoard `onResult`。

### 7.2 Model B 成功链路

以下条件必须同时成立：

1. 系统 `sensorInfo` 或等价日志选中 `com.ukey.pin`。
2. 出现 `VERIFY_CHAIN_BEGIN_AUTH_INPUT`。
3. 出现 `VERIFY_CHAIN_PROMPT_CALLBACK`，并成功发送 command `50012`。
4. 系统触发 `passcodePrompt`。
5. `VERIFY_CHAIN_IPC_RECEIVE` 收到本次 requestId 的 passcode 密文。
6. `VERIFY_CHAIN_RSA_DECRYPT_OUTPUT` 为 `54,54,54,54,54,54`。
7. `VERIFY_CHAIN_COMPARE_RESULT matched=true`。
8. `VERIFY_CHAIN_AUTH_RESULT_CALLBACK resultCode=0`。
9. SceneBoard 最终 `onResult: 0 of CUSTOM_AUTH`。

只看到页面提示成功、SceneBoard 打印了字符串、RSA 解密成功但明文未匹配，或另一个认证器 `direct complete (no onPrompt)`，都不能判定本工具 Model B 密码链路通过。

### 7.3 六个零的专项判定

```text
charCodes=0,0,0,0,0,0
```

表示六个 `0x00`，不是 ASCII 字符串 `000000`。建议按以下边界继续定位：

| 最后正常位置 | 优先检查 |
|---|---|
| SceneBoard 调用前已经是 0 | JS `Uint8Array` 只分配未填充 |
| SceneBoard 为 54，NAPI 入口为 0 | 参数索引、TypedArray 类型或 byteOffset 处理 |
| NAPI 入口为 54，异步任务为 0 | 未深拷贝、buffer 生命周期或提前清零 |
| RSA 加密输入为 0 | `needPinAuth=false`/SP 分支或 CDA 覆盖 |
| RSA 加密输入为 54，认证器解密为 0 | 再检查实际公钥、密文和 RSA 实现；该分支当前证据不足 |

RSA-OAEP 使用错误认证器私钥时通常会直接校验失败，因此不能仅因同机安装两个应用，就把六个 NUL 字节归因于“另一个应用加密、本应用解密”。

## 8. 自动化覆盖和执行命令

当前 `ukey/entry/src/test` 已覆盖：

- 首把绑定允许建立。
- 同一 fingerprint 允许更新凭据列表。
- 不同 fingerprint 不允许覆盖首把绑定。
- 过滤键盘、鼠标、触控板名称和 USB Hub。
- 接纳设备级或接口级 Mass Storage，以及非键鼠 HID。
- 拒绝 Smart Card/CCID、厂商自定义类、打印机、摄像头、音频、通信和其它非存储、非 HID 设备。
- 相同 VID/PID 详情歧义时不复用第一条 SN。

本地单元测试和构建命令：

```powershell
Push-Location ukey
& "$env:DEVECOSTUDIO_HOME\tools\hvigor\bin\hvigorw.bat" test --mode module -p product=default -p module=entry@default
& "$env:DEVECOSTUDIO_HOME\tools\hvigor\bin\hvigorw.bat" assembleHap --mode module -p product=default -p module=entry@default --no-daemon
Pop-Location
```

若未设置 `DEVECOSTUDIO_HOME`，按项目 `AGENTS.md` 的工具链查找规则定位 DevEco Studio，不在脚本中写死本机安装目录。

以下场景当前主要依赖真机手工验证：系统 PIN token、CustomAuth 凭据添加/删除、真实锁屏、Model B passcode、5 次持久化锁定、USB 插拔时序、多账户和多认证器共存。

## 9. 发布判定和缺陷分级

### 9.1 P0 发布阻断

- HAP 不是预期系统应用或缺少 CustomAuth/DDK/User IDM/PIN 权限。
- 首把绑定无法建立，或第二把可以替换首把。
- 正确 UKey 密码无法完成有效的 `com.ukey.pin` Model B 认证。
- 错误密码仍认证成功，或连续 5 次错误未锁定。
- 目标 UKey 拔出、开关关闭或第二把在位时仍认证成功。
- 删除凭据后仍可使用已删除凭据认证。
- 密钥迁移/密码学校验失败却返回成功。

### 9.2 P1 重要缺陷

- active/inactive 展示与实际在位状态不一致。
- 多账户只处理部分账户且页面未提示部分失败。
- USB 键鼠或 Hub 被误识别为 UKey，阻断正常添加。
- 升级后绑定、凭据、开关或锁定状态异常丢失。
- 窗口 X 导致后台运行时退出。

### 9.3 P2 一般缺陷

- 非关键文案、布局、时间展示或状态刷新延迟问题，不影响安全规则和凭据结果。

## 10. 测试记录模板

```text
用例 ID：
设备型号/系统版本：
HAP 路径/SHA-256：
安装方式：干净安装 / install -r / 日常回归
OS 用户 ID：
系统 PIN：已配置（禁止在报告中记录明文）
UKey A SN：
UKey B SN：
当前绑定 fingerprint：
系统选中 bundle/templateId：
操作步骤：
页面结果：
关键日志 requestId：
最终 resultCode/onResult：
结论：通过 / 失败 / 阻塞
缺陷等级：P0 / P1 / P2
附件：截图、完整 hilog、HAP 哈希
```

测试报告不得记录系统 PIN 明文；UKey 固定开发密码可按当前规格记录为 `666666`，但正式接入真实 UKey 密码能力后应同步调整脱敏规则。

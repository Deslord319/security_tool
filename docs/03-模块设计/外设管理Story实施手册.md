# 外设管理 Story 实施手册

## 1. 文档用法

本手册把外设管理拆成 40 个可单独领取的 Story。开发人员一次只选一个 Story，从“依赖什么”开始，按“怎么做”修改，最后逐条执行“怎么验收”。

本手册是 `外设管理组件设计说明.md` 第 3 章的可执行展开。状态真源、完整伪代码、数据模型和异常边界仍以组件设计说明为准。

### 1.1 公共开发前置

1. 阅读 `AGENTS.md`、`docs/05-AI开发/AI执行原则.md` 和 `docs/03-模块设计/外设管理组件设计说明.md`。
2. 确认本次只修改选中 Story。如果改动影响其它 Story，先在设计文档中修改依赖和验收条件。
3. 保持分层：Page/Component 只渲染和分发操作；ViewModel 管状态和编排；Service 管业务规则；Repository/Adapter 管持久化和系统 API。
4. 先补或确认该 Story 的 UT，再修改生产代码。测试名使用 `U-<Story ID>-<分支>`。
5. 涉及 MDM、USB 真实设备或蓝牙回调的 Story，不能只用 mock 判定完成。

### 1.2 公共验收环境

1. 按项目规范构建、签名并安装主 HAP。
2. 激活企业管理员：

```text
hdc shell edm enable-admin -n com.huawei.securitytool -a EnterpriseAdminAbility -t super
```

3. 准备至少以下设备：有 SN 的 USB 存储设备、无 SN 的 USB 设备、USB Hub、两个同 baseClass USB 设备、一个可显示名称的蓝牙设备。
4. 每次实机验收保留：设备型号、系统版本、操作前页面和系统回读、操作步骤、操作后页面和回读、脱敏日志。
5. 通用验证命令：

```text
hvigorw test --mode module -p product=default -p module=entry@default
python scripts/check_docs_consistency.py
git diff --check
```

### 1.3 整体怎么拆、按什么顺序开发

外设管理按“页面入口 -> USB 基础能力 -> USB 设备状态 -> 蓝牙事件 -> 策略维护 -> 记录维护”拆成 6 个 Feature。不要同时铺开 40 个 Story，建议按下面顺序逐组交付：

1. **F1 页面生命周期与接口管控（ST-IF-01～06）**：先建立页面初始化、真实状态回读和接口切换能力。它是页面可操作的基础。
2. **F2 USB 全局开关事务（ST-UG-01～07）**：完成禁用前快照、系统下发、失败补偿和恢复重枚举。F3 的设备级策略依赖这一组的 USB 全局状态。
3. **F3 USB 插拔与默认策略（ST-UR-01～08）**：完成设备识别、默认策略、已有意图重用、拔出恢复和 trace。F5 的 USB 黑白名单以这一组生成的设备策略状态为真源。
4. **F4 蓝牙连接准入（ST-BT-01～07）**：完成 ACL/Bond 关联、名称解析、并发隔离和停止清理。F5 的蓝牙黑白名单与 F6 的连接记录依赖本组输出的事件和快照。
5. **F5 黑白名单维护（ST-PL-01～07）**：在 USB/蓝牙底层状态稳定后，实现列表重建、策略变更、删除和导出。
6. **F6 连接记录维护（ST-RC-01～05）**：最后接入前述各组产生的 trace，实现列表、详情、导出和清理。

每组的执行规则相同：先完成该组编号最小且被其它 Story 依赖的基础项；每完成一个 Story 就单独跑其 UT 和手工验收；整组全部通过后再跑全量 UT、对应 E2E 和实机回归。某个 Story 的“依赖什么”未满足时，不得把该 Story 标记为开发完成。

### 1.4 什么叫验收通过

一个 Story 只有同时满足以下条件才能关闭：

1. “怎么做”列出的生产文件责任点已经实现，且没有把系统 API 或 RDB 访问下沉到 Page/Component。
2. “怎么验收”列出的 UT 用例全部通过；标注实机或 E2E 的步骤也必须有对应记录，不能用 UT 替代。
3. 失败分支、回滚或补偿分支与成功分支一起通过，不能只证明 happy path。
4. 页面显示值、系统真实回读、RDB/trace 持久化三者中凡是该 Story 涉及的真源都必须一致。
5. 交付记录填写本手册第 8 章模板，能从 Story ID 追到代码、测试和证据。

## 2. F1 页面生命周期与接口管控

### ST-IF-01 页面初始化门控

**目标**

进入外设页时，必须先读取真实接口状态，再首次创建接口选择器，避免先显示默认值再跳变。

**依赖什么**

- `PeripheralViewModel.initialize(context)` 能完成 trace、策略仓储和子 ViewModel 初始化。
- `InterfaceControlViewModel.reloadState()` 已实现真实状态回读。
- 只依赖页面本地 `interfaceControlReady`，不新增全局 loading 状态。

**怎么做**

1. 修改 `entry/src/main/ets/views/peripheral/overview/PeripheralPage.ets`。
2. 页面开始初始化时立即设 `interfaceControlReady=false`。
3. `await PeripheralViewModel.initialize(context)`，不在 Page 里直接读 MDM。
4. 初始化结束后再设 `interfaceControlReady=true`。
5. 只在 ready 为 true 时创建 `InterfaceControlTab`；false 时内容区留空。
6. 不增加 `LoadingProgress`、骨架屏或新错误页。

**怎么验收**

1. 在 `entry/src/test/views/PeripheralPage.test.ets` 新增 `U-ST-IF-01-A`，用可控 Promise 暂停 `initialize`。
2. Promise 未完成时断言页面未创建 `InterfaceControlTab` 和 Select。
3. Promise 完成后断言只创建一次，且首次值来自 ViewModel。
4. 实机上先禁用一个接口，退出再进入外设页；不应看到“启用”短暂闪现后变为“禁用”。
5. 上述任一步失败，Story 不通过。

### ST-IF-02 真实接口状态回读

**目标**

页面展示值必须来自 restrictions、USB 存储策略和当前有线网卡回读，不能来自页面缓存。

**依赖什么**

- ST-IF-01 的页面门控。
- `PeripheralService.getInterfaceDisabledWithResult()`、`getUsbStoragePolicyWithResult()` 和 `WiredNetworkService.getDisabledWithResult()`。

**怎么做**

1. 修改 `entry/src/main/ets/viewmodels/peripheral/interface-control/InterfaceControlViewModel.ets` 的 `reloadState()`。
2. 蓝牙、Wi-Fi、HDC、网络共享、打印机、麦克风、摄像头和 USB 逐项读 restrictions。
3. 有线网络调 `WiredNetworkService`；USB 存储读 MDM USB policy。
4. 所有结果准备完成后调一次 `commitState()`。
5. 任一读取抛错时记录错误并保留文档默认值，不下发任何系统策略。

**怎么验收**

1. 在 `entry/src/test/viewmodels/InterfaceControlViewModel.test.ets` 增补 `U-ST-IF-02-A/B`。
2. 预置蓝牙禁用、Wi-Fi 允许、tethering 禁用、USB 存储只读，断言四项展示值正确。
3. 让任意读 API 抛错，断言无写 API 调用且 ViewModel 保留默认值。
4. 实机修改系统策略后重进页面，每个选择器必须与回读一致。

### ST-IF-03 restrictions 通用接口切换

**目标**

企业管理员可切换七个普通 restrictions 接口，成功立即回显，失败回滚。

**依赖什么**

- ST-IF-02 已可回读真实状态。
- `PeripheralViewModel.ensureAdminReady()` 可拦截管理员未激活。

**怎么做**

1. PAGE 把 feature 和目标 disabled 值交给 PVM，PVM 先检查管理员。
2. ICVM `toggleInterface()` 设置 `processingKey`。
3. 调 `PeripheralService.setInterfaceDisabledWithResult(feature, disallow)`。
4. 成功才调 `updateInterfaceState()`；失败返回 reason code，不改 ViewModel 原值。
5. `finally` 必须清空 `processingKey`。

**怎么验收**

1. `InterfaceControlViewModel.test.ets` 中增补 `U-ST-IF-03-A/B`，对七个 feature 参数化测试。
2. 成功分支断言 feature/disallow 传参正确、状态变更、`processingKey` 清空。
3. 失败分支断言状态不变、失败原因可见。
4. 管理员未激活时断言系统写 API 零调用。
5. 执行 E2E `scripts/e2e/cases/peripheral/interfaces.json`，实机上切换后重进页面，值仍必须一致。

### ST-IF-04 有线网络逐接口切换

**目标**

只管理当前激活的有线网卡，多接口全部成功才显示成功。

**依赖什么**

- `ohos.permission.ENTERPRISE_GET_NETWORK_INFO` 和 `ENTERPRISE_SET_NETWORK`。
- 管理员已激活。

**怎么做**

1. 修改 `WiredNetworkService.ets`，每次操作都调 `getAllNetworkInterfacesSync()`。
2. 过滤出当前激活的有线接口，不持久化接口名。
3. 无接口时返回“当前未连接有线网络”专用原因。
4. 逐接口调 `setNetworkInterfaceDisabledSync()`，随后逐接口调 `isNetworkInterfaceDisabledSync()` 回读。
5. 任一接口失败即返回失败；ICVM 不提交目标状态。

**怎么验收**

1. 新增 `entry/src/test/peripheral/wired-network-service.test.ets`。
2. `U-ST-IF-04-A`：两个激活接口均下发且回读成功。
3. `U-ST-IF-04-B`：无激活接口，断言零下发和专用原因。
4. `U-ST-IF-04-C`：第二个接口失败，断言整体失败且 UI 不显示成功。
5. 实机分别验证无网线、单网卡和多网卡场景。

### ST-IF-05 Wi-Fi/蓝牙撤销禁用后开启硬件

**目标**

用户主动撤销 Wi-Fi/蓝牙禁用时开启一次硬件；普通刷新不得覆盖用户手动关闭。

**依赖什么**

- ST-IF-03。
- `ohos.permission.ENTERPRISE_MANAGE_SETTINGS`。

**怎么做**

1. `PeripheralService.setInterfaceDisabledWithResult()` 先撤销 restrictions。
2. 仅当 feature 是 Wi-Fi 或蓝牙且 `disallow=false` 时，调 `restoreEnabledInterfacePowerWithResult()`。
3. 统一使用 API 26 `deviceSettings.setSwitchStatus(..., ON)`，不用 `FORCE_ON`。
4. `reloadState()` 和页面初始化不得调用开启硬件 API。
5. 硬件开启失败时返回 `turn_on_wifi`/`turn_on_bluetooth` stage，不提交成功 UI。

**怎么验收**

1. `InterfaceControlViewModel.test.ets` 补 `U-ST-IF-05-A/B/C`。
2. 成功分支断言“撤销 restrictions -> 开启硬件”顺序和仅一次调用。
3. 刷新分支断言 `setSwitchStatus` 零调用。
4. 失败分支断言 UI 不提交、stage 正确。
5. 实机手动关闭 Wi-Fi/蓝牙后重进页面，硬件不应被自动开启；随后主动撤销禁用，硬件应开启一次。

### ST-IF-06 USB 存储访问策略

**目标**

支持只读、读写和禁止三种 USB 存储策略，与全局 USB 和单设备黑白名单正确协同。

**依赖什么**

- ST-IF-02 已读取当前 USB 存储策略。
- `PeripheralPolicySnapshotTraceService` 和 trace 仓储可用。
- 全局 USB 状态已回读。

**怎么做**

1. ICVM `setUsbStoragePolicy(index)` 先检查 `state.usbDisabled`。
2. 将页面索引映射为 `READ_ONLY/READ_WRITE/DISABLED`。
3. 调 `PeripheralService.setUsbStoragePolicyWithCleanupResult()`。
4. 系统返回 `9200010` 时映射为黑白名单冲突，不提示“USB 未启用”。
5. 成功后只对当前 USB_STORAGE 设备写 `discover` 策略快照。
6. PVM 把已确认目标值传给 POLVM 刷新，避免即时回读短暂返回旧值。

**怎么验收**

1. `InterfaceControlViewModel.test.ets` 补 `U-ST-IF-06-A/B/C`，覆盖三种策略、全局 USB 冲突和 `9200010`。
2. `policy-snapshot-trace-service.test.ets` 断言只记 USB_STORAGE，action 为 `discover`。
3. `PeripheralViewModel.test.ets` 断言黑白名单立即使用确认目标值刷新。
4. 执行 E2E `usb_policy.json`。
5. 实机用 USB 存储盘逐项切换，重进页面后值不变；DISABLED 时单设备策略不可编辑。

## 3. F2 USB 设备级全局管控

### ST-UG-01 全局禁用前置校验

**依赖什么**

- ST-IF-06 可读取 USB 存储策略。
- 只允许 `READ_WRITE` 进入全局禁用事务。

**怎么做**

1. 在 `UsbGlobalPolicyService.setDisabled(true)` 首先调 `getUsbStoragePolicyWithResult()`。
2. 读取失败直接返回原 error/stage。
3. 策略非 `READ_WRITE` 返回 `SET_USB_INTERFACE_CONFLICT`。
4. 上述失败时不调用 USTATE、SNAP 或 restrictions 写 API。

**怎么验收**

1. `usb-global-policy-service.test.ets` 补 `U-ST-UG-01-A/B/C`。
2. 分别输入 READ_ONLY、DISABLED 和读取抛错。
3. 断言返回原因正确，`suspendActivePolicies`、全局写和快照皆零调用。

### ST-UG-02 暂停 active deny 及失败补偿

**依赖什么**

- ST-UG-01 通过。
- `usb_device_policy_states` 已可查询在线和 active 状态。

**怎么做**

1. `UsbDevicePolicyStateService.suspendActivePolicies()` 只选 `present=true && activePolicy=deny`。
2. 逐记录 dispatch allow，成功后保存 `activePolicy=none`，不改 `desiredPolicy`。
3. 某项 dispatch 或保存失败时，对本轮已暂停记录调 `compensateSuspendedPolicies()` 重下 deny。
4. 补偿完成前不进入全局 restrictions 写入。

**怎么验收**

1. `usb-device-policy-state-service.test.ets` 补 `U-ST-UG-02-A/B/C`。
2. 准备在线 active deny、在线 allow、离线 deny，断言只处理第一类。
3. 让第二个 deny 恢复失败，断言第一个已重下 deny，全局写零调用。
4. 让 Repository 保存 none 失败，同样必须补偿。

### ST-UG-03 全局禁用提交

**依赖什么**

- ST-UG-01 和 ST-UG-02 均成功。

**怎么做**

1. 调 `PeripheralService.setInterfaceDisabledWithResult(USB, true)` 下发 restrictions `usb=true`。
2. 下发失败时调 `restorePresentDeniedPolicies()` 恢复禁用前单设备 deny。
3. 仅全局下发成功时向 ICVM 返回成功。
4. ICVM 仅成功时将 `usbDisabled=true`。

**怎么验收**

1. `usb-global-policy-service.test.ets` 补 `U-ST-UG-03-A/B`。
2. 成功分支断言调用顺序：预检 -> 暂停 -> restrictions。
3. 失败分支断言调恢复 deny，ICVM 保留原状态。
4. 实机禁用后重进页面，USB 必须回显禁用。

### ST-UG-04 全局禁用策略快照

**依赖什么**

- ST-UG-03。
- `PeripheralPolicySnapshotTraceService` 和 trace 仓储可用。

**怎么做**

1. 全局下发前调 `captureCurrentUsbDevices()`。
2. 过滤 Hub、非法 VID/PID 和无有效 class 设备。
3. 全局下发成功后对捕获集合各写一条 `discover/deny/BLOCKED/usb_disabled`。
4. 快照写失败只告警，不回滚已成功的全局策略。

**怎么验收**

1. `policy-snapshot-trace-service.test.ets` 补 `U-ST-UG-04-A/B`。
2. 捕获集合中加入普通 USB、Hub 和无效设备，断言只有普通有效设备入库。
3. 让 trace 写失败，断言全局策略仍返回成功。
4. 实机禁用前插入两个 USB 设备，禁用后连接记录应有对应两条策略变更。

### ST-UG-05 全局恢复提交

**依赖什么**

- 当前 restrictions `usb=true`。

**怎么做**

1. `UsbGlobalPolicyService.setDisabled(false)` 先调 restrictions `usb=false`。
2. 全局写失败时立即返回，不重放 deny，不等待重枚举，不写 allow 快照。
3. 全局写成功后才进入 ST-UG-06 和 ST-UG-07。

**怎么验收**

1. `usb-global-policy-service.test.ets` 补 `U-ST-UG-05-A/B`。
2. 失败分支断言 replay、timer 和 snapshot 零调用。
3. 成功分支断言先全局写，后 replay。
4. 实机恢复后重进页面，USB 必须回显启用。

### ST-UG-06 在线显式 deny 重放

**依赖什么**

- ST-UG-05 成功。
- UREPO 保留了全局禁用前的 `desiredPolicy`。

**怎么做**

1. `restorePresentDeniedPolicies()` 只选 `present=true && desiredPolicy=deny`。
2. 逐项 dispatch deny，成功后保存 `activePolicy=deny`。
3. 某项失败时不伪写 active deny，继续处理其它记录，最终返回部分失败。
4. 部分失败不把全局 USB 伪装成仍禁用。

**怎么验收**

1. `usb-device-policy-state-service.test.ets` 和 `usb-global-policy-service.test.ets` 补 `U-ST-UG-06-A/B/C`。
2. 同时准备在线 deny、离线 deny、在线 allow，断言仅第一类下发。
3. 让其中一个 dispatch 失败，断言其它设备继续重放。
4. 实机准备黑名单 USB 设备，全局禁用再恢复，黑名单设备应继续被禁止。

### ST-UG-07 恢复后重枚举与 allow 快照

**依赖什么**

- ST-UG-05 成功；ST-UG-06 已尝试重放。

**怎么做**

1. 全局恢复成功后等待 500ms。
2. 首次枚举非空时立即写 allow/default_allow/discover 快照，不再等待。
3. 首次为空时再等 1000ms，执行第二次枚举。
4. 第二次仍空时不伪造记录。

**怎么验收**

1. `usb-global-policy-service.test.ets` 补 `U-ST-UG-07-A/B/C`。
2. A：500ms 后非空，断言无第二次 timer。
3. B：第一次空、第二次非空，断言写一组快照。
4. C：两次均空，断言零快照。
5. 实机恢复 USB 后观察设备重枚举，连接记录不应出现历史设备伪造快照。

## 4. F3 USB 插拔、识别与默认策略

### ST-UR-01 USB 事件解析与 Hub 过滤

**依赖什么**

- `ApplicationRuntimeManager` 已启动 Producer 和 Pipeline。
- USB attach/detach common event 契约已定义。

**怎么做**

1. `PeripheralConnectionRecordRuntimeProducerAdapter` 只把 attach/detach 转为 USB 内部事件。
2. `PeripheralConnectionRecordPipeline` 把 USB channel 交给 `PeripheralConnectionRecordUsbConsumer`。
3. Consumer 通过 `PeripheralConnectionRecordPayloadUtils` 读 VID、PID、baseClass、SN、description、名称和时间。
4. `baseClass=0x09` 在指纹解析、Repository 和 MDM 调用前立即返回 null。

**怎么验收**

1. 在 `runtime-producer-adapter.test.ets`、`payload-utils.test.ets` 和 `connection-record-usb-consumer.test.ets` 增补 `U-ST-UR-01-A/B`。
2. attach/detach 应进入 Consumer；非法 action 应返回 null。
3. Hub attach/detach 必须同时断言：零 trace、零 UREPO 写入、零 MDM dispatch。
4. 实机插拔 Hub，连接记录和黑白名单均不应出现 Hub。

### ST-UR-02 SN/弱指纹识别

**依赖什么**

- ST-UR-01 已解析出设备字段。

**怎么做**

1. `UsbDeviceIdentityResolver` 先校验 VID/PID。
2. 有 SN 时生成 `USB-SN:<serial>` 强指纹。
3. 无 SN 时使用 VID/PID/description hash 生成弱指纹。
4. Resolver 只做纯计算，不读写 Repository，不调 MDM。
5. VID/PID 无效返回 null；Consumer 允许保留未识别 trace，但不建策略状态。

**怎么验收**

1. `usb-device-identity-resolver.test.ets` 增补 `U-ST-UR-02-A/B/C`。
2. 同 SN 不同其它字段仍为同强指纹。
3. 无 SN 但同 VID/PID/description 为同弱指纹；description 不同不得合并。
4. 无效 VID/PID 断言 Resolver 返 null 且 Repository/MDM 零调用。

### ST-UR-03 新 USB 设备默认 allow

**依赖什么**

- ST-UR-02 返回有效且尚无历史记录的指纹。
- `usb_default_policy=allow`。

**怎么做**

1. USTATE 查 UREPO，确认指纹不存在。
2. 读 DDEFAULT 得到 allow。
3. 不调 deny dispatch。
4. 保存 `present=true, desiredPolicy=allow, activePolicy=none`。
5. Consumer 写 allow connect trace，POLVM 刷新后设备进入白名单。

**怎么验收**

1. `usb-device-policy-state-service.test.ets` 和 `connection-record-usb-consumer.test.ets` 补 `U-ST-UR-03-A/B`。
2. 断言 dispatch 零调用，UREPO 字段完整，trace 是 allow。
3. 执行 E2E `usb_whitelist.json`。
4. 实机清除该指纹后插入设备，白名单应出现且设备可使用。

### ST-UR-04 新 USB 设备默认 deny

**依赖什么**

- ST-UR-02 返回新指纹。
- `usb_default_policy=deny`，USB 存储上层策略不冲突。

**怎么做**

1. USTATE 读到 default deny 后先按 baseClass dispatch deny。
2. 仅 dispatch 成功后保存 `desiredPolicy=deny, activePolicy=deny, present=true`。
3. dispatch 失败时不创建“已生效”黑名单状态。
4. Consumer 仍可写连接诊断，但必须显示真实失败结果。

**怎么验收**

1. `usb-device-policy-state-service.test.ets` 补 `U-ST-UR-04-A/B`。
2. 成功分支断言“dispatch -> save”顺序和 deny/deny 状态。
3. 失败分支断言 UREPO 无新黑名单、active deny 未伪写。
4. 执行 E2E `usb_blacklist.json`；实机插入新设备，系统禁止和黑名单展示必须同时成立。

### ST-UR-05 已有 USB 显式策略重用

**依赖什么**

- UREPO 已有同指纹 allow 或 deny 记录。

**怎么做**

1. attach 时先查 existing。
2. existing 存在时完全忽略当前 `usb_default_policy`。
3. existing allow 只刷新 present/名称/时间，不下 deny。
4. existing deny 确保 dispatch deny 成功后把 active 收敛为 deny。
5. 不覆盖管理员的 desired 意图。

**怎么验收**

1. `usb-device-policy-state-service.test.ets` 新增 `U-ST-UR-05-A/B/C`。
2. 给 existing allow 配 default deny，断言仍 allow 且无 deny dispatch。
3. 给 existing deny 配 default allow，断言仍 deny 且 dispatch deny。
4. 实机切换默认策略后重插已知设备，其卡片策略不得被改写。

### ST-UR-06 USB_STORAGE 上层策略冲突

**依赖什么**

- 设备类型为 USB_STORAGE。
- USB 存储总策略为 DISABLED。

**怎么做**

1. Consumer/USTATE 在单设备 dispatch 前读存储总策略。
2. DISABLED 时，无论 desired allow 还是 deny，都不下发单设备类型策略。
3. trace 优先表达“USB 存储已禁止”，不伪写单设备 active deny。
4. POLVM 将该设备 `editable=false`。

**怎么验收**

1. `connection-record-usb-consumer.test.ets` 和 `device-policy-dispatch-service.test.ets` 补 `U-ST-UR-06-A/B`。
2. allow/deny 两组都断言 dispatch 零调用。
3. 断言 trace 优先是存储级禁止，active 未伪写 deny。
4. 实机禁用 USB 存储后插盘，单设备选择器必须置灰。

### ST-UR-07 detach 内部 allow 恢复

**依赖什么**

- 拔出设备已有 `activePolicy=deny`。

**怎么做**

1. detach 时查同 baseClass 其它 `present=true && activePolicy=deny` 记录。
2. 存在其它同类 deny 时不调 allow，避免误恢复其它设备。
3. 不存在时 dispatch allow；成功保存 `active=none`，失败保留 `active=deny`。
4. 始终更新 `present=false`，保留 `desired=deny`。
5. 内部 allow 不写 policy snapshot，只保留真实 detach trace。

**怎么验收**

1. `usb-device-policy-state-service.test.ets` 新增 `U-ST-UR-07-A/B/C`。
2. 单设备场景断言 allow 下发、none/false/deny 状态和零快照。
3. 同 baseClass 双设备场景断言零 allow 调用。
4. allow 失败断言 active 仍 deny。
5. 实机分别验证单设备和同类双设备拔出。

### ST-UR-08 USB trace 落库

**依赖什么**

- ST-UR-01～07 已给出当时真实判定。
- TRACE 已初始化。

**怎么做**

1. Consumer 使用当时事件、策略判定和统一 USB 名称规则组装 trace。
2. 一个真实 attach/detach 只生成一条对应记录。
3. Pipeline 调 `PeripheralTraceMaintenanceService.appendEntries()`。
4. Repository 未就绪或写失败时记录错误，不返回虚假已持久化结果。

**怎么验收**

1. `connection-record-usb-consumer.test.ets`、`connection-record-pipeline.test.ets` 和 `trace-maintenance-service.test.ets` 补 `U-ST-UR-08-A/B`。
2. 断言 source/action/decision/result/matchedPolicyKind/名称完整且与当时判定一致。
3. 让 Repository 未初始化和写失败，断言无虚假成功。

## 5. F4 蓝牙 ACL/Bond 运行时采集

### ST-BT-01 蓝牙权限与监听生命周期

**依赖什么**

- `ACCESS_BLUETOOTH` 和 `GET_BLUETOOTH_PEERS_MAC`。
- Producer 已绑定 context 和 Pipeline listener。

**怎么做**

1. Producer 启动前检查两个权限。
2. 分别注册 API 26 ACL 和 Bond callback。
3. 任一注册失败时注销已成功的另一个，设 `bluetoothRuntimeEvents=false`。
4. 重复 start 不重复注册；stop 使用原 callback 注销。
5. 蓝牙关闭过程不提前释放 ACL 监听。

**怎么验收**

1. `runtime-producer-adapter.test.ets` 补 `U-ST-BT-01-A/B/C`。
2. 验证成功、权限拒绝、ACL 注册失败、Bond 注册失败、重复 start/stop。
3. 失败分支断言无旧 common event 或私有 action 回退。
4. 实机保留注册状态和关闭蓝牙后的真实 DISCONNECTED 日志。

### ST-BT-02 普通 ACL 最终态准入

**依赖什么**

- ST-BT-01 监听已启动。
- BTCOORD 已绑定 record sink。

**怎么做**

1. Producer 只转 CONNECTED/DISCONNECTED，忽略 CONNECTING/DISCONNECTING。
2. BTCOORD 规范化系统提供的地址。
3. connect 先更新 BTSTORE；disconnect 先取快照/缓存名，再移除 Store。
4. 非配对设备名称有效后立即交 BTC 入库。
5. 不增加通用时间去重，不合并不同地址。

**怎么验收**

1. 在 Producer、Coordinator 和 Bluetooth Consumer 测试中补 `U-ST-BT-02-A/B`。
2. 输入四个 ACL 阶段，断言仅两个最终态入库。
3. 连续输入两个真实同类回调，断言不被通用去重。
4. 实机连接再断开蓝牙设备，页面应各有一条最终态记录。

### ST-BT-03 蓝牙有限名称补查

**依赖什么**

- ST-BT-02 提供系统地址和时间。

**怎么做**

1. `BluetoothDeviceNameResolver` 按 T+0 系统查询 -> 同地址 Store/cache -> T+500ms -> T+1500ms 顺序执行。
2. 首次命中有效名称即结束后续任务并刷新 Store。
3. “蓝牙设备”、空串和通用占位名均视为无效。
4. 最终无名不入 RDB；但 connect 事实可保留在 BTSTORE。
5. stop/candidate cancel 必须取消所属 timer。

**怎么验收**

1. `bluetooth-connection-record-coordinator.test.ets` 补 `U-ST-BT-03-A/B/C/D`。
2. 分别让 T+0、cache、500ms、1500ms 命中，断言命中后无多余 timer。
3. 四步均无名时断言零 RDB 写入，Store 仍有 connect 事实。
4. 两个不同地址不得共用名称。

### ST-BT-04 蓝牙配对会话建立与超时

**依赖什么**

- ST-BT-01 Bond 回调可用。

**怎么做**

1. BONDING 到达时建立只绑定当前规范化地址的 30s session。
2. 同会话重复 BONDING 更新地址，不重复建 timer。
3. 30s 超时关闭 session，取消该 session 所属 candidate。
4. 其它地址的普通 ACL 不归入该 session。

**怎么验收**

1. Coordinator 测试补 `U-ST-BT-04-A/B`。
2. fake timer 推进 30s，断言 session/candidate 被清且零合成记录。
3. session 存在时输入另一地址的带名 ACL，断言按普通链路入库。

### ST-BT-05 ACL/BONDED 乱序结算

**依赖什么**

- ST-BT-03 可解析名称，ST-BT-04 可维护 session。

**怎么做**

1. ACL 先到：保存同地址 candidate，等 BONDED。
2. BONDED 先到：标记 session bonded，最多等同地址 ACL 3s。
3. 只在同地址 ACL CONNECTED、BONDED、Store 仍 connected 和名称有效四条同时成立时入库一次。
4. BONDED 后 3s 无 ACL 则关会话，不伪造 connect。

**怎么验收**

1. Coordinator 测试补 `U-ST-BT-05-A/B/C`。
2. 分别输入 ACL->BONDED 和 BONDED->ACL，断言均只有一条 connect。
3. BONDED 后推进 3s 且不输入 ACL，断言零记录。
4. 实机新配对设备，连接记录不得因 Bond 本身重复。

### ST-BT-06 配对失败或先断开取消

**依赖什么**

- ST-BT-04/05 已建立 candidate。

**怎么做**

1. INVALID 到达时关闭本 session 并取消所属 candidate。
2. candidate 在 BONDED 前 DISCONNECTED 时，取消 candidate 和其名称任务。
3. 上述场景不补 connect 或 disconnect。
4. 不取消其它地址的普通 ACL 名称任务。

**怎么验收**

1. Coordinator 测试补 `U-ST-BT-06-A/B/C`。
2. INVALID 和先 disconnect 两组均断言零 connect/disconnect trace。
3. 同时存在另一普通 ACL 名称任务时，断言其仍可入库。

### ST-BT-07 蓝牙全局禁用快照与真实断开

**依赖什么**

- ST-IF-03 可禁用蓝牙，ST-BT-02 可记真实断开。
- BTSTORE 已维护当前 connected 快照。

**怎么做**

1. ICVM 禁用前 capture Store 并为设备预置一次性 disabled-disconnect pending。
2. restrictions 下发失败/抛错立即清 pending，不写快照。
3. 成功后 BTSNAP 仅对带有效名称设备写 `discover/deny/BLOCKED/bluetooth_disabled`。
4. 后续真实 DISCONNECTED 仍入库，消费一次 pending 后清除。

**怎么验收**

1. 在 ICVM、BTSNAP 和 Bluetooth Consumer 测试中补 `U-ST-BT-07-A/B/C`。
2. 成功场景断言先有策略快照，后有真实 disconnect，两条都存在。
3. 无名设备不写快照，但 Store 事实不因此伪造名称。
4. 失败场景断言 pending 清除，后续 disconnect 不被误标禁用。
5. 实机连接蓝牙设备后禁用蓝牙，页面应同时可查策略变更和真实断开。

## 6. F5 USB 黑白名单维护

### ST-PL-01 黑白名单从 USB 策略状态库生成

**依赖什么**

- `UsbDevicePolicyStateRepository` 已初始化。
- F3 能为 USB 设备建立策略状态。

**怎么做**

1. `PeripheralPolicyViewModel.reloadRecords()` 调 UREPO `listAll()`。
2. 将记录交 `PeripheralPolicyService.buildPolicyRecords()` 转成展示模型。
3. 一个 fingerprint 只生成一张卡片。
4. 不查连接 trace，不读旧 `device_policies`，不把蓝牙设备加入名单。

**怎么验收**

1. `PeripheralPolicyViewModel.test.ets` 补 `U-ST-PL-01-A/B`。
2. UREPO 准备 allow/deny、online/offline，trace 另放额外 USB/蓝牙。
3. 断言输出只与 UREPO 一致，额外 trace 不影响列表。

### ST-PL-02 USB 黑白名单可编辑态计算

**依赖什么**

- ST-PL-01 已生成卡片。
- 全局 USB、USB 存储策略和 present 状态可用。

**怎么做**

1. global USB disabled 时所有卡片 `editable=false`。
2. 设备 `present=false` 时 `editable=false`。
3. USB_STORAGE + 存储 DISABLED 时 `editable=false`。
4. 只有全局允许、设备在线，且未命中存储上层禁止时为 true。
5. PAGE 绑定 `editable`，POLVM/Service 仍要二次校验，不能只依赖 UI 置灰。

**怎么验收**

1. `PeripheralPolicyViewModel.test.ets` 新增参数化 `U-ST-PL-02-A`。
2. 覆盖 global on/off、storage RW/DISABLED、online/offline、storage/non-storage 全组合。
3. 对每个 false 组合直接调写方法，断言 MDM 和 Repository 零写入。
4. 执行 E2E `policy_tab.json`。

### ST-PL-03 在线 USB 设备 allow/deny 修改

**依赖什么**

- ST-PL-02 判定设备可编辑。
- DISPATCH、UREPO 和 SNAP 可用。

**怎么做**

1. PAGE 把 fingerprint、deviceType 和目标 policy 交 PVM/POLVM。
2. POLVM 再校验指纹、设备类型、present、global USB 和 storage conflict。
3. USTATE 先 dispatch 目标 allow/deny，成功后才保存 desired/active。
4. 成功后 SNAP 仅对当前枚举且 VID/PID 精确匹配设备写 policy snapshot。
5. 最后重读列表和 `hasRestorableRecords`。
6. 任一失败不提前改列表或本地成功态。

**怎么验收**

1. 在 POLVM、USTATE 和 SNAP 测试中补 `U-ST-PL-03-A/B/C`。
2. allow->deny 断言 dispatch 先于 save，最终 desired/active 均 deny。
3. deny->allow 断言最终 desired=allow/active=none。
4. 下发失败、离线、global disabled、storage conflict 均断言本地状态不变。
5. 执行 USB allow/deny E2E，实机重插后策略仍应生效。

### ST-PL-04 新设备默认策略修改

**依赖什么**

- `PeripheralDevicePolicyRepository` 已初始化。
- global USB 当前允许。

**怎么做**

1. POLVM 校验页面索引并转 allow/deny。
2. 只调 DDEFAULT `setUsbDefaultPolicy()` 写 `peripheral_device_policy.usb_default_policy`。
3. 不枚举当前设备，不调 DISPATCH，不改 UREPO 已有记录，不写批量快照。
4. 写失败时选择器回滚。

**怎么验收**

1. `device-policy-repository.test.ets` 和 `PeripheralPolicyViewModel.test.ets` 补 `U-ST-PL-04-A/B/C`。
2. 列表预置多个 allow/deny，切默认值后断言所有 UREPO 记录不变。
3. 断言 USB 枚举、MDM dispatch 和 SNAP 零调用。
4. 执行 E2E `usb_policy.json`。

### ST-PL-05 本地 + EDM 可还原态计算

**依赖什么**

- ST-PL-01 可读本地状态。
- DISPATCH 可读 `getDisallowedUsbDevices()`。

**怎么做**

1. POLVM 刷新时计算本地是否存在 desired deny。
2. 同时查 EDM 是否仍有任何 USB 类型 deny。
3. 任一真源有 deny，`hasRestorableRecords=true`。
4. 两者均无 deny 才为 false。
5. PAGE 还原按钮只绑定该状态。

**怎么验收**

1. POLVM/PVM 测试补 `U-ST-PL-05-A/B/C`。
2. 仅本地 deny：按钮可用。
3. 仅 EDM 残留 deny：按钮仍可用。
4. 两者均无：按钮置灰。
5. 不得用 `activePolicy` 单独决定按钮状态。

### ST-PL-06 还原全部 USB 策略

**依赖什么**

- ST-PL-05 判定存在可还原状态。
- global USB 当前允许。

**怎么做**

1. 用户确认后，POLVM 调 USTATE `clearAllPolicies()`。
2. DISPATCH 先读并移除 EDM 全部 USB 类型 deny。
3. EDM 清理成功后，UREPO 批量保存所有记录为 `desired=allow, active=none`。
4. 保留 fingerprint、卡片、present 和最后发现信息。
5. 最后重读本地和 EDM，只有两者都无 deny 才显示成功。

**怎么验收**

1. USTATE/POLVM 测试补 `U-ST-PL-06-A/B/C`。
2. 本地有 deny + EDM 有 deny：断言先清 EDM，后批量保存。
3. 本地空 + EDM 有 deny：仍必须清 EDM。
4. EDM 失败或本地批量保存失败：不显示成功，重读决定按钮状态。
5. 执行 E2E `policy_actions_visible.json`；实机还原后卡片仍在且全部显示允许。

### ST-PL-07 USB 黑白名单导出

**依赖什么**

- ST-PL-01 已生成列表。
- `CsvFileExportService` 可用。

**怎么做**

1. POLVM `exportRecords()` 先短路空列表和空 context。
2. 使用固定表头导出 fingerprint、名称、类型、desired policy、online 和时间。
3. 通过公共 CSV 服务加 BOM、字段转义并截断覆盖同名文件。
4. 写失败返回可重试失败，不显示虚假文件名。

**怎么验收**

1. `PeripheralPolicyViewModel.test.ets` 补 `U-ST-PL-07-A/B/C`。
2. 用包含中文、逗号、引号和换行的设备名验证 CSV。
3. 空列表断言文件选择器零调用。
4. 以更短内容覆盖同名文件，人工打开确认无旧尾部。

## 7. F6 连接记录查询与维护

### ST-RC-01 连接记录列表查询与刷新

**依赖什么**

- TRACE 已初始化，F3/F4 可产生 trace。

**怎么做**

1. `PeripheralConnectionRecordService.queryRecords()` 只查 `PeripheralTraceEntryRepository`。
2. 保留 action、decision、result、source、matched kind 和 USB policy 等完整元数据。
3. RECVM `reloadRecords()` 用查询结果替换列表。
4. PVM trace listener 只刷新记录驱动数据，不重建黑白名单。
5. Mapper 把 runtime connect/disconnect 和 policy snapshot 展示为不同动作。

**怎么验收**

1. RECSVC、RECVM 和 PVM 测试补 `U-ST-RC-01-A/B/C`。
2. 准备 USB connect/disconnect、USB/BT policy snapshot 和 BT ACL，断言列表语义正确。
3. 触发 trace listener，断言记录刷新而 policy rebuild 零调用。
4. 执行 E2E `record_tab.json`。

### ST-RC-02 同设备历史详情

**依赖什么**

- ST-RC-01 已有列表。
- `PeripheralRecordPresentationMapper` 可组合历史。

**怎么做**

1. RECVM `openConnectionDetailDialog(record)` 保存选中记录。
2. `buildConnectionHistoryItems(records, record)` 只聚合同稳定设备标识。
3. 策略结论、命中类型和结果只从历史 trace 快照读，不查当前策略。
4. 弹窗打开时列表刷新，同步重建 historyItems。
5. close 清空 record 和 historyItems。

**怎么验收**

1. `PeripheralRecordViewModel.test.ets` 补 `U-ST-RC-02-A/B/C`。
2. 准备同设备多条和另一设备记录，断言只聚合同设备。
3. 修改当前 policy 后重建详情，断言历史语义不变。
4. 弹窗打开时新增同设备 trace，断言 historyItems 刷新。

### ST-RC-03 连接记录 CSV 导出

**依赖什么**

- ST-RC-01 列表非空。
- CSV 服务和页面 context 可用。

**怎么做**

1. RECVM `exportConnectionHistory()` 先检查空数据和 context。
2. `buildConnectionHistoryCsv()` 按固定表头输出时间、名称、类型、ID、动作、策略、结果和来源。
3. 使用 Mapper 生成展示文案，使用 CSV 服务做 BOM/转义/截断写入。
4. 成功返实际 fileName；失败返精确 reason。

**怎么验收**

1. 将 `PeripheralRecordViewModel.test.ets` 现有 U-RVM-005～010 映射到 `U-ST-RC-03-A/B/C/D`。
2. 验证空数据、空 context、写失败和成功。
3. 用中文、逗号、引号和换行值验证 CSV。
4. 用更短内容覆盖同名文件，人工打开确认无旧尾部。

### ST-RC-04 仅清理 trace

**依赖什么**

- TRACE 可清理；同时准备一组 USB 黑白名单作隔离校验。

**怎么做**

1. PVM `clearConnectionHistory()` 调 `PeripheralConnectionRecordClearUsecase`。
2. Usecase 确保 context 和 TRACE 初始化后，只调 `PeripheralTraceMaintenanceService.clearAll()`。
3. 成功后重读 RECVM；失败保留当前列表。
4. 不调 UREPO、DDEFAULT、DISPATCH，不改本地或 EDM 策略。

**怎么验收**

1. `PeripheralViewModel.test.ets` 补 `U-ST-RC-04-A/B/C`。
2. 成功时断言 trace 清空，UREPO/DDEFAULT/DISPATCH 零调用。
3. clear 失败断言列表不被先置空。
4. 实机清理前记录黑白名单和 EDM 状态，清理后两者必须不变。

### ST-RC-05 连接记录空态与可重试失败

**依赖什么**

- ST-RC-01/03/04。

**怎么做**

1. PAGE 的导出和清理按钮直接绑 `records.length > 0`，不维护重复 `hasRecords`。
2. 两个 handler 再检查空数据，防止绕过 UI 触发。
3. 空数据不打开文件选择器或确认弹窗，不弹“操作失败”。
4. RDB 查询失败时记日志并交付可用空列表，不崩溃。

**怎么验收**

1. `PeripheralRecordViewModel.test.ets` 和 `views/PeripheralPage.test.ets` 补 `U-ST-RC-05-A/B/C`。
2. 空列表断言两个按钮置灰，直接调 handler 仍无下游调用。
3. Repository 查询抛错断言页面可用、列表为空、无伪造数据。
4. 执行 E2E `record_tab.json`。

## 8. 单个 Story 交付记录模板

```text
Story ID:
目标分支: A / B / C
实施人:
开始前依赖检查:
修改文件:
新增/修改测试:
UT 结果:
E2E/ohosTest 结果:
实机证据编号:
操作前系统回读:
操作后系统回读:
UI 结果:
持久化结果:
失败/补偿分支结果:
未完成项:
Story 结论: PASS / FAIL / BLOCKED
```

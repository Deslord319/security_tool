# Story：USB 设备级全局禁用与单设备黑白名单协同

## Story 状态

- **状态**：代码、签名安装和管理员激活已完成，待 2in1 USB 功能矩阵验收
- **所属模块**：外设管理（`peripheral-manage`）
- **优先级建议**：高
- **目标设备**：2in1
- **关联设计**：`docs/03-模块设计/外设管理组件设计说明.md` 的“2.1 USB 全局管控与黑白名单默认策略规格”
- **系统能力**：`@kit.MDMKit.restrictions`、`@kit.MDMKit.usbManager`

## 背景与问题

当前“接口管控 > USB 接口”并不是真正的设备级 USB 总控。页面开关实际读写本地 `peripheral_device_policy.usb_default_policy`：

- `deny` 表示未知 USB 首次接入时尝试自动加入设备级禁止策略；
- `allow` 表示未知 USB 首次接入时默认允许；
- 已保存的 SN/弱指纹设备策略优先于该默认值。

该语义与页面“启用或禁用 USB 接口”的文案不一致，用户容易把默认接入策略理解为设备 USB HOST 能力总开关。

HarmonyOS MDM 已提供真正的设备级接口：

```ts
restrictions.setDisallowedPolicy(ADMIN_WANT, 'usb', true)
restrictions.getDisallowedPolicy(ADMIN_WANT, 'usb')
```

但设备级 USB 总控与 USB 类型黑名单、USB 白名单及 USB 存储策略存在系统冲突，不能直接替换现有调用，必须建立全局状态与单设备策略的协同、补偿和恢复机制。

## 现有 USB 默认策略逻辑位置

原“USB 接口”逻辑由以下链路共同实现，实施时应整体迁移职责，不能只移动页面控件：

| 位置 | 当前职责 | 调整方向 |
|---|---|---|
| `InterfaceControlTab.ets` | 在接口管控页展示“USB 接口”选择行 | 改为真正的 restrictions USB 全局开关 |
| `InterfaceControlViewModel.ets` | USB 分支读写 `usb_default_policy`，并追加默认策略快照 | USB 分支改为全局事务；默认策略读写移交黑白名单 ViewModel |
| `PeripheralDevicePolicyRepository.ets` | 持久化 `usb_default_policy=allow/deny` | 保留，继续作为独立默认策略唯一 owner |
| `PeripheralConnectionRecordUsbConsumer.ets` / `UsbDevicePolicyStateService.ets` | 新设备无显式状态时读取默认策略，deny 时首次自动下发 | 保留业务规则，增加全局 USB 禁用门控 |
| `PeripheralPolicySnapshotTraceService.ets` | 当前默认策略变化时可能枚举当前 USB 设备补快照 | 默认值切换不扫描当前设备、不生成设备策略快照；如需审计，只记录一条配置变更结论，不关联具体设备 |
| `PeripheralPolicyViewModel.ets` / `PolicyList.ets` | 当前只展示和修改单设备策略 | 新增独立默认策略状态与选择行，并在全局禁用时置灰 |

迁移后的页面归属：

```text
接口管控
  └─ USB 接口：系统设备级全局启用/禁用

黑白名单
  ├─ 未配置 USB 设备默认策略：允许接入/禁止接入
  └─ 已登记设备：各自的 SN/弱指纹 allow/deny
```

## 用户故事

作为企业设备管理员，我希望能够在外设管理中全局禁用设备 USB 接口，使所有外接 USB 设备立即不可用；同时把原来的未知设备默认 allow/deny 能力独立放到黑白名单页。全局禁用期间我仍能看到默认策略和已经配置的单设备意图但不能修改；恢复 USB 接口后，系统应恢复显式单设备策略，尚未配置的设备继续按独立默认策略处理。

## 业务目标

1. “USB 接口”开关与系统设备级 USB 禁用状态一致。
2. 全局禁用优先于所有单设备和 USB 存储策略。
3. 全局切换不覆盖或丢失 SN/弱指纹的 `desiredPolicy`。
4. 全局恢复后，在线显式 deny 自动重放，离线 deny 在再次接入时重放。
5. 系统策略冲突、部分失败和补偿失败均不得显示假成功。
6. `usb_default_policy` 从接口总控中拆出，作为黑白名单页独立的“未配置 USB 设备默认策略”，继续决定新设备首次接入的 allow/deny。

## 非目标范围

- 不关闭 USB 充电能力。
- 不把 HDC、MTP、USB 转串口或外置存储卡策略合并到 USB 总控中。
- 不改变 USB 设备 SN 强指纹和无 SN 弱指纹生成规则。
- 不扩大蓝牙黑白名单能力。
- 不自动修改 USB 存储只读/禁用策略以规避冲突。
- 不删除或迁移 `usb_default_policy` Preferences key，只迁移页面入口和职责归属。

## 策略模型与优先级

```text
全局 USB 禁用
  └─ 所有 USB DEVICE 当前有效结果为禁止，细粒度控件不可操作

全局 USB 启用
  ├─ 已有设备状态：使用 usb_device_policy_states.desired_policy
  └─ 没有设备状态：使用 usb_default_policy
```

| 状态 | 真源 | 生命周期 |
|---|---|---|
| `usbGloballyDisabled` | `restrictions.getDisallowedPolicy(..., 'usb')` | 系统策略，不做本地持久化 |
| `desiredPolicy` | `usb_device_policy_states` | 管理员保存的 allow/deny 意图 |
| `activePolicy` | `usb_device_policy_states` | 设备级 deny 是否真实下发；全局禁用期间收敛为 `none` |
| `usbDefaultPolicy` | `peripheral_device_policy.usb_default_policy` | 未配置设备首次接入的 allow/deny 默认值 |
| `present` | USB attach/detach 运行时状态 | 决定恢复时是否立即重放 deny |

## 权威判定规格

以下表格是实现与验收的唯一判定口径；其它描述与本表冲突时以本表为准。

| 全局 USB | 是否存在设备显式记录 | 显式策略/默认值 | 连接时动作 | 是否新增或修改设备记录 |
|---|---|---|---|---|
| 禁用 | 任意 | 任意 | 不执行设备级 allow/deny；由全局策略统一阻断 | 不因本次连接新增或修改显式策略 |
| 启用 | 是 | 显式 allow | 忽略默认值；不下发 deny | 保持原显式 allow 记录不变 |
| 启用 | 是 | 显式 deny | 忽略默认值；立即确保 deny 已下发 | 下发成功后保持/更新 deny 与 active 状态；失败不得伪造 active 成功 |
| 启用 | 否 | 默认 allow | 不下发任何设备策略 | 不新增 allow 记录，设备仍属于“未显式配置” |
| 启用 | 否 | 默认 deny | 立即下发 deny | 仅下发成功后新增显式 deny 记录；失败不新增记录 |

补充约束：

- “存在显式记录”按设备稳定标识查询：优先 SN；无 SN 时使用既有弱指纹。只要命中显式记录，就不得再读取默认值参与决策。
- 默认 allow 不是一条设备白名单记录，而是“无显式策略时不采取禁止动作”。
- 默认 deny 是连接时的策略生成规则，不是切换默认值时批量下发的系统策略。
- 默认 deny 下发成功后生成的显式 deny 与管理员手工设置的 deny 使用同一状态模型；后续默认值变化不得覆盖它。
- 默认 deny 下发失败时可以写连接失败/诊断记录，但不得写入 `usb_device_policy_states` 的显式 deny 成功状态。
- 切换默认值只持久化 `usb_default_policy`，不得枚举当前设备、不得调用 USB MDM 单设备接口、不得生成当前设备策略快照。

## 页面规格

黑白名单页的默认策略必须作为独立配置行展示，不能伪装成一台设备：

- 标题：`未配置 USB 设备默认策略`。
- 选项：`允许接入`、`禁止接入`。
- 说明：`仅用于尚未存在 SN/弱指纹策略的设备；不会修改已有设备策略。`
- 修改成功条件：默认值持久化成功；不等待也不触发设备策略下发。
- 全局 USB 禁用时：显示当前默认值但控件置灰。
- 单设备列表只展示显式记录；默认 allow 的新设备不会因为一次连接自动出现在白名单中。

## 关键交互

### 全局 USB 启用

- “USB 接口”显示启用。
- USB 存储策略、单设备策略和还原按钮按原条件可操作。
- 已登记设备显示自身 `desiredPolicy`。
- 黑白名单页顶部独立显示“未配置 USB 设备默认策略”，可选择允许接入或禁止接入。
- 默认策略选择只保存 `usb_default_policy`，切换时不下发、不扫描当前设备、不批量新增或修改单设备记录。
- 新设备首次接入且没有 SN/弱指纹显式状态时读取 `usb_default_policy`；默认 allow 时不下发且不新增显式记录，默认 deny 时立即下发禁止，成功后才新增显式 deny 记录。已经存在显式状态的设备完全忽略后续默认值变化。

### 全局 USB 禁用

- “USB 接口”显示禁用，值来自系统回读。
- 黑白名单仍显示每台设备原 allow/deny，不批量改成 deny。
- 单设备策略选择器、USB 存储策略和还原按钮置灰。
- 页面显示：“USB 已全局禁用，设备策略将在恢复 USB 后生效。”
- ViewModel/Service 必须拒绝绕过 UI 发起的细粒度写操作。

### 部分恢复失败

- 全局 USB 已恢复时，总开关必须显示启用。
- 成功重放的设备更新 `activePolicy=deny`。
- 失败设备保持 `desiredPolicy=deny、activePolicy=none`。
- 提示“USB 已启用，部分设备禁止策略恢复失败”，不得重新禁用全局 USB。

## 系统策略冲突规则

全局禁用前必须检查 USB 存储策略：

- `READ_WRITE`：允许继续。
- `READ_ONLY` 或 `DISABLED`：阻止全局禁用，提示先恢复为可读写。

当前已下发的 USB 设备类型 deny 需要在全局禁用前暂停，否则 restrictions `usb` 可能返回策略冲突。管理员意图保存在 `desiredPolicy` 中，不得随暂停动作丢失。

对于系统中存在但不受当前应用状态库管理的 USB 白名单或其它冲突策略：

- 不自动清理；
- 保留系统返回的冲突结果；
- 页面提示存在系统 USB 冲突策略；
- 全局状态继续以回读结果为准。

## 事务设计

### 禁用事务

1. 校验企业管理员状态。
2. 回读全局 USB；已禁用则幂等成功。
3. 回读 USB 存储策略；非 `READ_WRITE` 直接失败。
4. 读取全部设备策略状态，保存本次事务快照。
5. 逐条移除 `activePolicy=deny` 的设备级 deny。
6. 单条移除成功后写 `activePolicy=none`，保留 `desiredPolicy`。
7. 任一移除失败则停止，向已移除成功的在线 deny 做补偿重放。
8. 全部暂停成功后下发 restrictions `usb=true`。
9. 回读确认；确认失败则补偿重放在线 deny。
10. 成功后刷新接口状态、黑白名单及提示状态。

### 恢复事务

1. 下发 restrictions `usb=false`。
2. 回读确认全局已经启用。
3. 查询 `present=true && desiredPolicy=deny`。
4. 按稳定顺序逐条重放设备级 deny。
5. 成功项更新 `activePolicy=deny`；失败项保持 `activePolicy=none`。
6. 汇总完整成功或部分失败结果，刷新页面。

## 失败与补偿要求

| 失败点 | 后续动作 | 页面状态 |
|---|---|---|
| 企业管理员未激活 | 不调用 MDM | 保持原值，提示激活 |
| USB 存储策略冲突 | 不暂停设备策略、不调用全局禁用 | 保持原值，提示先恢复存储策略 |
| 暂停某条 deny 失败 | 停止事务，补偿已暂停项 | 以全局回读为准，显示失败 |
| 全局禁用下发失败 | 补偿重放在线 deny | 不显示禁用成功 |
| 全局禁用回读不一致 | 视为失败并补偿 | 展示回读真实值 |
| 全局恢复失败 | 不重放 deny | 继续显示全局禁用 |
| 单设备 deny 重放部分失败 | 不回滚全局恢复 | 显示启用并提示部分失败 |
| 状态库写入失败 | 记录 error，返回失败或部分失败 | 不伪造 activePolicy |

## 实施任务拆分

### Task 1：设计与模型收敛

- 更新外设模块当前行为描述。
- 定义全局切换结果、部分失败项和补偿结果模型。
- 明确 `desiredPolicy`、`activePolicy` 和全局覆盖语义。

### Task 2：全局策略编排 Service

- 新增独立编排 Service，封装禁用/恢复事务。
- `PeripheralService` 只负责 restrictions USB 原子读写和错误映射。
- 编排 Service 负责快照、暂停、补偿、回读确认和重放。

### Task 3：设备状态服务调整

- 新设备无显式状态时读取独立默认策略；已有设备继续使用自身 `desiredPolicy`。
- 增加暂停 active deny 和恢复在线 deny 方法。
- 全局禁用期间 `handleConnect()` 不执行设备级 dispatch。
- 离线 deny 再连接时恢复下发。

### Task 4：ViewModel 与页面

- USB 开关绑定真实全局回读。
- 接口管控与黑白名单共享同一全局状态来源。
- 全局禁用时置灰 USB 存储、单设备策略和还原按钮。
- 增加覆盖说明、冲突提示和部分失败提示。

### Task 5：拆出旧默认策略入口

- 从“接口管控 > USB 接口”移除 `usb_default_policy` 读写。
- 在黑白名单页顶部新增“未配置 USB 设备默认策略”选择行，继续读写原 Preferences key。
- 默认策略变化只影响之后首次出现且没有状态行的设备，不立即下发，也不批量覆盖已有 `desiredPolicy`。
- 保留首次接入按默认 deny 自动下发的行为：下发成功后才记录显式 deny，下发失败不新增黑名单记录；默认 allow 不下发、不新增记录。

### Task 6：测试与实机闭环

- 补齐 Service/ViewModel/Repository UT。
- 补齐全局置灰和绕过 UI 拒绝的 ohosTest。
- 使用签名 HAP 和 super 企业管理员完成实机矩阵。
- 记录充电、HDC、MTP 等边界现象，不做未经验证的结论。

## 验收标准

### AC1：全局状态真源

- 页面重新进入、应用重启和设备重启后，USB 开关均来自 restrictions 回读。
- 本地 Preferences 值不能覆盖系统全局状态。

### AC2：全局禁用

- 存储可读写、无冲突策略时可以成功禁用。
- U盘、USB HID、UKey 和其它 USB 外设均不能使用。
- 所有细粒度 USB 控件置灰，直接调用 ViewModel/Service 同样被拒绝。

### AC3：单设备意图保留

- 全局禁用前 A=deny、B=allow，禁用后两者 `desiredPolicy` 不变。
- 全局禁用不会为所有设备创建 deny 状态。

### AC4：恢复与重放

- 恢复全局 USB 后，在线 A=deny 自动重新下发，B=allow 不下发 deny。
- 离线 deny 在再次接入时下发。
- 单项失败不影响全局恢复结果，页面展示部分失败。

### AC5：独立默认策略

- 黑白名单页能独立设置“未配置 USB 设备默认策略”为 allow 或 deny。
- 没有状态行的新设备在全局启用时读取当前默认值：默认 allow 不做任何下发且不创建显式记录；默认 deny 立即下发，成功后创建显式 deny 记录。
- 已经存在状态行的设备不随默认策略变化而改变。
- 切换默认 allow/deny 本身只保存默认值，不对当前在线设备下发策略。
- 全局 USB 禁用时默认策略控件置灰，且新设备不得额外下发设备级 deny；恢复后再按显式状态或默认策略处理。

### AC6：冲突与假成功防护

- USB 存储只读/禁用时，全局禁用被阻止且不改变存储策略。
- 系统返回策略冲突或回读不一致时，页面不显示禁用成功。
- 补偿失败必须留下可诊断日志和明确失败结果。

## 测试矩阵

| 编号 | 场景 | 层级 |
|---|---|---|
| USB-G-01 | 无策略时禁用/恢复全局 USB | UT + 实机 |
| USB-G-02 | 重复禁用幂等 | UT |
| USB-G-03 | USB 存储只读/禁用冲突 | UT + 实机 |
| USB-G-04 | A deny、B allow 的暂停与意图保留 | UT + Repository UT |
| USB-G-05 | 暂停中途失败及补偿成功 | UT |
| USB-G-06 | 补偿失败和失败项汇总 | UT |
| USB-G-07 | 全局下发成功但回读不一致 | UT |
| USB-G-08 | 在线 deny 恢复重放 | UT + 实机 |
| USB-G-09 | 离线 deny 再接入重放 | UT + 实机 |
| USB-G-10 | 部分 deny 重放失败 | UT |
| USB-G-11 | 全局禁用时 UI 置灰和后端拒绝 | UT + ohosTest |
| USB-G-12 | 默认策略切换只保存值；新设备默认 allow 无动作、默认 deny 下发成功后才入黑名单；已有设备不受影响 | UT + 实机 |
| USB-G-13 | 管理员未激活 | UT + 实机 |
| USB-G-14 | 应用/设备重启后的状态恢复 | ohosTest + 实机 |
| USB-G-15 | 同 baseClass 多设备同时在线 | UT + 实机 |
| USB-G-16 | 有 SN、无 SN、UKey、存储、HID | 实机 |

## 实机验收步骤

1. 构建并签名主 HAP。
2. 安装 HAP 并激活 `com.huawei.securitytool/EnterpriseAdminAbility` 为 super 管理员。
3. 准备有 SN UKey、无 SN USB 设备、U盘、键鼠或其它 HID。
4. 先分别配置 allow/deny，确认状态库与实际行为一致。
5. 执行全局禁用，验证设备不可用、控件置灰和意图保留。
6. 执行全局恢复，验证在线 deny 重放、allow 可用。
7. 恢复时保持一台 deny 设备离线，随后插入验证延迟重放。
8. 设置 USB 存储只读和禁用，验证全局禁用被明确阻止。
9. 重启应用和设备，验证全局状态与单设备意图回显。
10. 单独记录充电、HDC、MTP 和 USB 转串口表现，不把观察结果扩大为接口契约。

## 最小验证命令

```bash
python scripts/check_docs_consistency.py
hvigorw test --mode module -p product=default -p module=entry@default
hvigorw test --mode module -p product=default -p module=entry@ohosTest
hvigorw assembleHap --mode module -p product=default -p module=entry
```

## 风险

- USB 设备级 deny 当前按 USB class 下发，多个相同 baseClass 设备可能共享系统策略效果，不能仅凭 SN 页面记录认定系统具备真正的 SN 粒度隔离。
- 全局策略和细粒度策略互斥，事务中途失败可能造成意图状态与系统 active 状态短暂不一致。
- 运行时 attach/detach 与全局切换并发时，需要串行化或请求版本控制，避免旧请求覆盖新状态。
- 全局禁用可能导致现有 USB 设备立即断开，策略快照不得伪装成普通 detach 事件。
- 未由本应用管理的系统 USB 白名单/限制策略只能报告冲突，不能擅自清除。

## 回滚方案

- 代码回滚时把 `usb_default_policy` 入口恢复到旧页面前，必须先确认系统 restrictions `usb` 已解除，避免页面显示启用但系统仍全局禁用。
- 不删除 `usb_device_policy_states`，保留管理员单设备意图。
- 若新事务能力上线后发生严重问题，可临时隐藏全局切换入口，但仍应回读并展示真实全局状态，不能回退为本地假状态。
- 回滚不自动恢复 USB 存储策略或清除系统中非本应用管理的策略。

## Definition of Done

- 模块设计文档已从“待实施”更新为真实落地行为。
- Story 中 Task 1～Task 6 全部完成。
- 所有 AC 均有对应 UT、ohosTest 或实机证据。
- 文档一致性检查、单元测试、ohosTest 编译和主 HAP 构建通过。
- 签名 HAP 在 2in1 实机完成 USB-G-01～USB-G-16 适用场景。
- 中文文件 UTF-8 回读正常，无乱码、Unicode 替换字符或异常转码文本。
- 最终提交说明明确列出全局策略冲突、部分失败语义和未覆盖设备边界。

# 外设管理-设备连接记录 Mock 测试追踪表

> 状态：In Progress  
> 最后更新：2026-04-03  
> 关联计划：`device-connection-record-mock-test-implementation-plan.md`

## 1. 说明

- 本表是“设备连接记录 Mock 测试实施”的唯一追踪面板。
- 每个用例 ID 必须绑定唯一 session。
- 状态只允许使用：`todo`、`in_progress`、`done`、`blocked`。
- `最近一次执行结果` 统一记录为：`not_run`、`pass`、`fail`。
- 每个子步骤都必须单独形成一个最小 Git 提交；未提交前，相关行不得标记为 `done`。
- 提交摘要格式固定为：`test(peripheral-record): <步骤ID> cover <用例ID范围>`。

## 2. 汇总

| Session | 范围 | 当前步骤 | 提交状态 | 目标测试文件 | 当前状态 |
|---|---|---|---|
| A | USB / Bluetooth consumer | `A-1`,`A-2` | pending | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets`、`entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets` | in_progress |
| B | pipeline / service | `B-1`,`B-2` | pending | `entry/src/test/peripheral/connection-record-pipeline.test.ets`、`entry/src/test/peripheral/connection-record-service.test.ets` | in_progress |
| C | record viewmodel / clear usecase / page viewmodel | `C-1`,`C-2`,`C-3`,`C-4` | pending | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets`、`entry/src/test/viewmodels/PeripheralViewModel.test.ets` | in_progress |
| D | mapper / repository | `D-1`,`D-2` | pending | `entry/src/test/utils/PeripheralRecordDisplayUtils.test.ets`、`entry/src/test/utils/PeripheralRecordViewDataUtils.test.ets`、`entry/src/test/peripheral/trace-repository.test.ets` | in_progress |
| E | 页面最小契约 | `E-1`,`E-2` | pending | `entry/src/test/views/PeripheralPage.test.ets`、`entry/src/ohosTest/ets/test/peripheral/snapshot.test.ets`、`entry/src/ohosTest/ets/test/peripheral/connection-record-contract.test.ets` | in_progress |

## 3. 用例清单

| 步骤 ID | Session | 覆盖范围 | 提交状态 | 提交摘要 | 备注 |
|---|---|---|---|---|---|
| A-1 | A | `U-USB-001..007` | pending |  | 已收到 handoff；待按步骤提交 |
| A-2 | A | `U-USB-008..010`,`U-BT-001..008` | pending |  | 已收到 handoff；待按步骤提交 |
| B-1 | B | `U-PIPE-001..009` | pending |  | 已收到 handoff；待按步骤提交 |
| B-2 | B | `U-SVC-001..005` | pending |  | 已收到 handoff；待按步骤提交 |
| C-1 | C | `U-RVM-001..010` | pending |  | 已收到 handoff；待按步骤提交 |
| C-2 | C | `U-CLEAR-001..004` | pending |  | 已收到 handoff；待按步骤提交 |
| C-3 | C | `U-PVM-001..005` | pending |  | 已收到 handoff；待按步骤提交 |
| C-4 | C | `U-PVM-006..011` | pending |  | 已收到 handoff；待按步骤提交 |
| D-1 | D | `U-MAP-001..009` | pending |  | 已收到 handoff；待按步骤提交 |
| D-2 | D | `U-REPO-001..016` | pending |  | 已收到 handoff；待按步骤提交 |
| E-1 | E | `U-VIEW-001`,`U-VIEW-003` | pending |  | 本地已落测试文件；待统一验证与提交 |
| E-2 | E | `U-VIEW-002`,`U-VIEW-004`,`U-VIEW-005` | pending |  | 依赖前置数据，后续推进 |

用例级行默认继承上表中的 `步骤 ID`、`提交状态`、`提交摘要`；只有当单个用例与所属步骤状态不一致时，才在备注中单独说明。

| 用例 ID | Session | 状态 | 目标测试文件 | 最近一次执行命令 | 最近一次执行结果 | 备注 |
|---|---|---|---|---|---|---|
| U-USB-001 | A | todo | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets` |  | not_run |  |
| U-USB-002 | A | todo | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets` |  | not_run |  |
| U-USB-003 | A | todo | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets` |  | not_run |  |
| U-USB-004 | A | todo | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets` |  | not_run |  |
| U-USB-005 | A | todo | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets` |  | not_run |  |
| U-USB-006 | A | todo | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets` |  | not_run |  |
| U-USB-007 | A | todo | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets` |  | not_run |  |
| U-USB-008 | A | todo | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets` |  | not_run |  |
| U-USB-009 | A | todo | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets` |  | not_run |  |
| U-USB-010 | A | todo | `entry/src/test/peripheral/connection-record-usb-consumer.test.ets` |  | not_run |  |
| U-BT-001 | A | todo | `entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets` |  | not_run |  |
| U-BT-002 | A | todo | `entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets` |  | not_run |  |
| U-BT-003 | A | todo | `entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets` |  | not_run |  |
| U-BT-004 | A | todo | `entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets` |  | not_run |  |
| U-BT-005 | A | todo | `entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets` |  | not_run |  |
| U-BT-006 | A | todo | `entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets` |  | not_run |  |
| U-BT-007 | A | todo | `entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets` |  | not_run |  |
| U-BT-008 | A | todo | `entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets` |  | not_run |  |
| U-PIPE-001 | B | todo | `entry/src/test/peripheral/connection-record-pipeline.test.ets` |  | not_run |  |
| U-PIPE-002 | B | todo | `entry/src/test/peripheral/connection-record-pipeline.test.ets` |  | not_run |  |
| U-PIPE-003 | B | todo | `entry/src/test/peripheral/connection-record-pipeline.test.ets` |  | not_run |  |
| U-PIPE-004 | B | todo | `entry/src/test/peripheral/connection-record-pipeline.test.ets` |  | not_run |  |
| U-PIPE-005 | B | todo | `entry/src/test/peripheral/connection-record-pipeline.test.ets` |  | not_run |  |
| U-PIPE-006 | B | todo | `entry/src/test/peripheral/connection-record-pipeline.test.ets` |  | not_run |  |
| U-PIPE-007 | B | todo | `entry/src/test/peripheral/connection-record-pipeline.test.ets` |  | not_run |  |
| U-PIPE-008 | B | todo | `entry/src/test/peripheral/connection-record-pipeline.test.ets` |  | not_run |  |
| U-PIPE-009 | B | todo | `entry/src/test/peripheral/connection-record-pipeline.test.ets` |  | not_run |  |
| U-SVC-001 | B | todo | `entry/src/test/peripheral/connection-record-service.test.ets` |  | not_run |  |
| U-SVC-002 | B | todo | `entry/src/test/peripheral/connection-record-service.test.ets` |  | not_run |  |
| U-SVC-003 | B | todo | `entry/src/test/peripheral/connection-record-service.test.ets` |  | not_run |  |
| U-SVC-004 | B | todo | `entry/src/test/peripheral/connection-record-service.test.ets` |  | not_run |  |
| U-SVC-005 | B | todo | `entry/src/test/peripheral/connection-record-service.test.ets` |  | not_run |  |
| U-RVM-001 | C | todo | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets` |  | not_run |  |
| U-RVM-002 | C | todo | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets` |  | not_run |  |
| U-RVM-003 | C | todo | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets` |  | not_run |  |
| U-RVM-004 | C | todo | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets` |  | not_run |  |
| U-RVM-005 | C | todo | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets` |  | not_run |  |
| U-RVM-006 | C | todo | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets` |  | not_run |  |
| U-RVM-007 | C | todo | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets` |  | not_run |  |
| U-RVM-008 | C | todo | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets` |  | not_run |  |
| U-RVM-009 | C | todo | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets` |  | not_run |  |
| U-RVM-010 | C | todo | `entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets` |  | not_run |  |
| U-CLEAR-001 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-CLEAR-002 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-CLEAR-003 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-CLEAR-004 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-001 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-002 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-003 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-004 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-005 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-006 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-007 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-008 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-009 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-010 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-PVM-011 | C | todo | `entry/src/test/viewmodels/PeripheralViewModel.test.ets` |  | not_run |  |
| U-MAP-001 | D | todo | `entry/src/test/utils/PeripheralRecordDisplayUtils.test.ets` |  | not_run |  |
| U-MAP-002 | D | todo | `entry/src/test/utils/PeripheralRecordDisplayUtils.test.ets` |  | not_run |  |
| U-MAP-003 | D | todo | `entry/src/test/utils/PeripheralRecordDisplayUtils.test.ets` |  | not_run |  |
| U-MAP-004 | D | todo | `entry/src/test/utils/PeripheralRecordDisplayUtils.test.ets` |  | not_run |  |
| U-MAP-005 | D | todo | `entry/src/test/utils/PeripheralRecordDisplayUtils.test.ets` |  | not_run |  |
| U-MAP-006 | D | todo | `entry/src/test/utils/PeripheralRecordDisplayUtils.test.ets` |  | not_run |  |
| U-MAP-007 | D | todo | `entry/src/test/utils/PeripheralRecordViewDataUtils.test.ets` |  | not_run |  |
| U-MAP-008 | D | todo | `entry/src/test/utils/PeripheralRecordViewDataUtils.test.ets` |  | not_run |  |
| U-MAP-009 | D | todo | `entry/src/test/utils/PeripheralRecordViewDataUtils.test.ets` |  | not_run |  |
| U-REPO-001 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-002 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-003 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-004 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-005 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-006 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-007 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-008 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-009 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-010 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-011 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-012 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-013 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-014 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-015 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-REPO-016 | D | todo | `entry/src/test/peripheral/trace-repository.test.ets` |  | not_run | new file |
| U-VIEW-001 | E | in_progress | `entry/src/ohosTest/ets/test/peripheral/connection-record-contract.test.ets` |  | not_run | 首轮自动化 |
| U-VIEW-002 | E | in_progress | `entry/src/ohosTest/ets/test/peripheral/connection-record-contract.test.ets` |  | not_run | 可能依赖空数据前置 |
| U-VIEW-003 | E | in_progress | `entry/src/ohosTest/ets/test/peripheral/connection-record-contract.test.ets` |  | not_run | 首轮自动化 |
| U-VIEW-004 | E | in_progress | `entry/src/ohosTest/ets/test/peripheral/connection-record-contract.test.ets` |  | not_run | 可能依赖有记录前置 |
| U-VIEW-005 | E | in_progress | `entry/src/ohosTest/ets/test/peripheral/connection-record-contract.test.ets` |  | not_run | 可能依赖有记录前置 |

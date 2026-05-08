# 测试用例基线 UT 支撑调研矩阵

## 背景

基于当前基线测试用例与仓库内现有 `entry/src/test` 资产，梳理每条基线用例在 UT 范围内的覆盖状态。本文档只讨论本地 UT，不把页面渲染、导航、弹窗交互、真实设备和系统触发链路纳入补充范围。

## 判定口径

- `已有UT覆盖`：当前本地 UT 已能支撑该用例在 UT 范围内的核心结论。
- `UT部分覆盖`：当前本地 UT 已覆盖该用例在 UT 范围内的核心分发或模型逻辑，但真实系统 API、持久化落盘、页面刷新等链路不纳入本地 UT。
- `待补UT`：该用例存在可单元化的业务逻辑缺口，后续应补本地 UT。
- `不补UT`：该用例核心是 UI、导航、弹窗、真实设备、系统触发或集成语义，本轮不补 UT。

## 总览

- 基线用例总数：`111`
- `已有UT覆盖`：`85`
- `UT部分覆盖`：`4`
- `待补UT`：`0`
- `不补UT`：`22`

## 安全总览

| 用例ID | 功能点 | 用例描述 | UT覆盖状态 | UT覆盖位置/不覆盖原因 |
| --- | --- | --- | --- | --- |
| DASH-001 | 页面展示 | 验证应用进入后默认展示安全总览页 | 不补UT | 应用默认页渲染场景，不进入本轮 UT 补充范围。 |
| DASH-004 | 防火墙状态展示 | 验证安全总览同步展示防火墙当前状态 | 已有UT覆盖 | entry/src/test/dashboard/viewmodel.test.ets |
| DASH-005 | 日志统计展示 | 验证安全总览展示日志统计数据 | 已有UT覆盖 | entry/src/test/dashboard/viewmodel.test.ets |
| DASH-006 | 外设统计展示 | 验证安全总览展示外设连接统计 | 已有UT覆盖 | entry/src/test/dashboard/viewmodel.test.ets |
| DASH-007 | 快捷入口跳转 | 验证安全总览快捷入口可以进入各业务页面 | 不补UT | 快捷入口真实跳转属于导航/页面交互场景，不进入本轮 UT 补充范围。 |
| DASH-008 | 页面刷新 | 验证从其他页面返回安全总览后数据刷新 | 已有UT覆盖 | entry/src/test/dashboard/viewmodel.test.ets |

## 防火墙管理

| 用例ID | 功能点 | 用例描述 | UT覆盖状态 | UT覆盖位置/不覆盖原因 |
| --- | --- | --- | --- | --- |
| FW-001 | 防火墙开关 | 验证防火墙开关可以从关闭切换为开启 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets |
| FW-002 | 防火墙开关 | 验证防火墙开关可以从开启切换为关闭 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets |
| FW-003 | 模式切换 | 验证防火墙开启时可以切换公共网络模式 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets；entry/src/test/firewall/mode-strategy.test.ets |
| FW-004 | 模式切换 | 验证防火墙开启时可以切换私有网络模式 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets；entry/src/test/firewall/mode-strategy.test.ets |
| FW-005 | 模式切换 | 验证防火墙关闭时模式卡片不可选择 | 不补UT | 模式卡片不可选择属于页面禁用态，不进入本轮 UT 补充范围。 |
| FW-006 | 预置策略展示 | 验证公共网络和私有网络模式卡片展示完整 | 不补UT | 模式卡片展示完整属于页面渲染场景，不进入本轮 UT 补充范围。 |
| FW-007 | 自定义规则入口 | 验证可以从防火墙管理页进入规则详情页 | 不补UT | 进入规则详情页属于导航场景，不进入本轮 UT 补充范围。 |
| FW-008 | 规则列表展示 | 验证无自定义规则时展示空状态 | 不补UT | 空状态展示属于页面渲染场景；service 层空数组返回已有基础支撑，不再补 UT。 |
| FW-009 | 规则新增 | 验证新增 IP 规则 `8.8.8.8/32`、出站、TCP、443、允许 成功 | 已有UT覆盖 | entry/src/test/firewall/rule-utils.test.ets |
| FW-010 | 规则新增 | 验证新增域名规则 `www.baidu.com`、出站、允许 成功 | 已有UT覆盖 | entry/src/test/firewall/rule-utils.test.ets |
| FW-011 | 规则参数校验 | 验证新增 IP 规则时地址为空按全部地址保存成功 | 已有UT覆盖 | entry/src/test/firewall/rule-utils.test.ets |
| FW-012 | 规则参数校验 | 验证新增 IP 规则时非法地址 `999.1.1.1` 被拦截 | 已有UT覆盖 | entry/src/test/firewall/rule-utils.test.ets |
| FW-013 | 规则编辑 | 验证将域名规则 `www.baidu.com / 出站 / 允许` 编辑为 `阻止` 成功 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets |
| FW-014 | 规则删除 | 验证删除已有规则成功 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets |
| FW-015 | 规则重复检测 | 验证重复新增域名规则 `www.baidu.com / 出站 / 允许` 时被识别为重复 | 已有UT覆盖 | entry/src/test/firewall/rule-utils.test.ets |
| FW-016 | 规则冲突检测 | 验证新增规则 `www.baidu.com / 出站 / 阻止` 时触发冲突提示 | 已有UT覆盖 | entry/src/test/firewall/rule-utils.test.ets |
| FW-017 | 规则重叠检测 | 验证新增规则 `www.baidu.com / 出站 / 阻止` 时与 `*.baidu.com / 出站 / 允许` 触发重叠提示 | 已有UT覆盖 | entry/src/test/firewall/rule-utils.test.ets |
| FW-019 | 用户级策略下发 | 验证选择目标用户后通过 PIN 校验下发白名单模式策略 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets |
| FW-020 | 用户级策略下发 | 验证选择目标用户后通过 PIN 校验下发黑名单模式策略 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets |
| FW-023 | 规则新增 | 验证新增 DNS 规则 `8.8.8.8 / 出站 / 允许` 成功 | 已有UT覆盖 | entry/src/test/firewall/rule-utils.test.ets |
| FW-024 | 规则参数校验 | 验证新增 DNS 规则时非法地址 `999.999.1.1` 被拦截 | 已有UT覆盖 | entry/src/test/firewall/rule-utils.test.ets |
| FW-025 | 模式切换 | 验证防火墙开启时可以从公共网络模式切换到自定义模式 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets；entry/src/test/firewall/mode-strategy.test.ets |
| FW-026 | 模式切换 | 验证防火墙开启时可以从私有网络模式切换到自定义模式 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets；entry/src/test/firewall/mode-strategy.test.ets |
| FW-027 | 模式切换 | 验证防火墙开启时可以从自定义模式切换到公共网络模式 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets；entry/src/test/firewall/mode-strategy.test.ets |
| FW-028 | 模式切换 | 验证防火墙开启时可以从自定义模式切换到私有网络模式 | 已有UT覆盖 | entry/src/test/firewall/service.test.ets；entry/src/test/firewall/mode-strategy.test.ets |
| FW-029 | 规则新增 | 验证新增用户后重新打开新增规则弹窗，用户范围列表包含新用户 | UT部分覆盖 | entry/src/test/entryability/entryability.test.ets；entry/src/test/firewall/system-user-provider.test.ets：覆盖账户新增事件分发到 SystemUserProvider.trackAddedUser、用户维护方法入口、用户列表结果结构和用户策略结果。Local UT 不覆盖 application.getApplicationContext() 后的 Preferences 真实落盘，不覆盖弹窗重新打开 UI 刷新。 |
| FW-030 | 规则新增 | 验证删除用户后重新打开新增规则弹窗，用户范围列表不再包含已删除用户 | UT部分覆盖 | entry/src/test/entryability/entryability.test.ets；entry/src/test/firewall/system-user-provider.test.ets：覆盖账户删除事件分发到 SystemUserProvider.trackRemovedUser、用户维护方法入口、用户列表结果结构和用户策略结果。Local UT 不覆盖 application.getApplicationContext() 后的 Preferences 真实落盘，不覆盖弹窗重新打开 UI 刷新。 |
| FW-031 | 用户级策略下发 | 验证新增用户后重新打开全局策略弹窗，目标用户列表包含新用户 | UT部分覆盖 | entry/src/test/entryability/entryability.test.ets；entry/src/test/firewall/system-user-provider.test.ets：覆盖账户新增事件分发到 SystemUserProvider.trackAddedUser、用户维护方法入口、用户列表结果结构和用户策略结果。Local UT 不覆盖 application.getApplicationContext() 后的 Preferences 真实落盘，不覆盖弹窗重新打开 UI 刷新。 |
| FW-032 | 用户级策略下发 | 验证删除用户后重新打开全局策略弹窗，目标用户列表不再包含已删除用户 | UT部分覆盖 | entry/src/test/entryability/entryability.test.ets；entry/src/test/firewall/system-user-provider.test.ets：覆盖账户删除事件分发到 SystemUserProvider.trackRemovedUser、用户维护方法入口、用户列表结果结构和用户策略结果。Local UT 不覆盖 application.getApplicationContext() 后的 Preferences 真实落盘，不覆盖弹窗重新打开 UI 刷新。 |

## 日志管理

| 用例ID | 功能点 | 用例描述 | UT覆盖状态 | UT覆盖位置/不覆盖原因 |
| --- | --- | --- | --- | --- |
| LOG-001 | 日志列表展示 | 验证日志管理页可正常展示日志列表和统计 | 已有UT覆盖 | entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-002 | 日志采集 | 验证在下载目录新建文件 `log_test_file.txt` 后记录 FILE 审计事件 | 已有UT覆盖 | entry/src/test/log-manage/audit-source.test.ets；entry/src/test/log-manage/collector-service.test.ets |
| LOG-003 | 日志采集 | 验证在系统设置 > 生物识别和密码 中拉起 PIN 认证后记录用户认证事件 | 已有UT覆盖 | entry/src/test/log-manage/audit-source.test.ets；entry/src/test/log-manage/collector-service.test.ets |
| LOG-004 | 日志详情 | 验证不同类型日志的详情弹窗展示对应结构化字段 | 已有UT覆盖 | entry/src/test/log-manage/audit-source.test.ets；entry/src/test/log-manage/crash-source.test.ets；entry/src/test/log-manage/entry-normalizer.test.ets |
| LOG-005 | 事件类型筛选 | 验证按事件类型筛选日志时仅展示指定类型结果 | 已有UT覆盖 | entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-006 | 执行结果筛选 | 验证按执行结果筛选日志时仅展示指定结果 | 已有UT覆盖 | entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-007 | 关键字搜索 | 验证按关键字 `log_test_file.txt` 搜索日志内容 | 已有UT覆盖 | entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-008 | 分页查询 | 验证日志数量超过一页时可以翻页 | 已有UT覆盖 | entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-009 | 分页查询 | 验证修改每页条数后分页状态正确 | 已有UT覆盖 | entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-010 | 日志刷新 | 验证返回日志管理页时数据自动刷新 | 已有UT覆盖 | entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-011 | 日志清空 | 验证清空日志成功 | 已有UT覆盖 | entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-012 | 日志导出 | 验证有日志时可以导出日志文件 | 已有UT覆盖 | entry/src/test/log-manage/export-service.test.ets；entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-013 | 日志导出 | 验证无日志时导出提示明确 | 已有UT覆盖 | entry/src/test/log-manage/export-service.test.ets；entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-014 | 存储设置 | 验证修改最大存储条数并保存成功 | 已有UT覆盖 | entry/src/test/log-manage/settings-viewmodel.test.ets；entry/src/test/log-manage/maintenance-service.test.ets |
| LOG-015 | 存储设置 | 验证修改日志保留天数并保存成功 | 已有UT覆盖 | entry/src/test/log-manage/settings-viewmodel.test.ets；entry/src/test/log-manage/maintenance-service.test.ets |
| LOG-016 | 空状态展示 | 验证无日志时页面展示空状态 | 已有UT覆盖 | entry/src/test/log-manage/list-viewmodel.test.ets |
| LOG-017 | 日志采集 | 验证应用新增或删除权限后记录 PERMISSION 权限变更事件 | 已有UT覆盖 | entry/src/test/log-manage/audit-source.test.ets；entry/src/test/log-manage/collector-service.test.ets |
| LOG-018 | 日志采集 | 验证应用自身崩溃后记录 CRASH 崩溃事件 | 已有UT覆盖 | entry/src/test/log-manage/crash-source.test.ets；entry/src/test/log-manage/collector-service.test.ets |

## 外设管理

| 用例ID | 功能点 | 用例描述 | UT覆盖状态 | UT覆盖位置/不覆盖原因 |
| --- | --- | --- | --- | --- |
| PER-001 | 接口管控 | 验证外设管理页默认展示接口管控页签 | 不补UT | 默认页签展示属于页面渲染场景，不进入本轮 UT 补充范围。 |
| PER-002 | USB接口策略 | 验证 USB 接口策略可从启用切换为禁用 | 已有UT覆盖 | entry/src/test/viewmodels/InterfaceControlViewModel.test.ets |
| PER-003 | USB接口策略 | 验证 USB 接口策略可从禁用切换为启用 | 已有UT覆盖 | entry/src/test/viewmodels/InterfaceControlViewModel.test.ets |
| PER-004 | USB存储策略 | 验证 USB 存储策略可从读写切换为只读 | 已有UT覆盖 | entry/src/test/viewmodels/InterfaceControlViewModel.test.ets |
| PER-005 | USB存储策略 | 验证 USB 存储策略可从读写切换为禁止访问 | 已有UT覆盖 | entry/src/test/viewmodels/InterfaceControlViewModel.test.ets |
| PER-006 | 策略冲突处理 | 验证 USB 接口禁用时切换 USB 存储策略提示冲突 | 已有UT覆盖 | entry/src/test/viewmodels/InterfaceControlViewModel.test.ets |
| PER-007 | 蓝牙策略 | 验证蓝牙接口策略可从启用切换为禁用 | 已有UT覆盖 | entry/src/test/viewmodels/InterfaceControlViewModel.test.ets |
| PER-008 | Wi-Fi策略 | 验证 Wi-Fi 接口策略可从启用切换为禁用 | 已有UT覆盖 | entry/src/test/viewmodels/InterfaceControlViewModel.test.ets |
| PER-009 | 设备连接记录 | 验证 USB 设备接入后生成连接记录 | 已有UT覆盖 | entry/src/test/peripheral/connection-record-usb-consumer.test.ets |
| PER-010 | 设备连接记录 | 验证 USB 设备断开后生成断开记录 | 已有UT覆盖 | entry/src/test/peripheral/connection-record-usb-consumer.test.ets |
| PER-011 | 设备详情 | 验证点击设备记录后展示设备详情 | 不补UT | 设备详情展示属于 UI 侧场景，不进入本轮 UT 补充范围。 |
| PER-012 | 黑白名单策略 | 验证黑白名单页签展示可管理设备 | 不补UT | 黑白名单页签展示属于页面渲染场景，不进入本轮 UT 补充范围。 |
| PER-013 | 单设备策略切换 | 验证单设备策略可从允许接入切换为禁止接入 | 已有UT覆盖 | entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets |
| PER-014 | 单设备策略切换 | 验证单设备策略可从禁止接入切换为允许接入 | 已有UT覆盖 | entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets |
| PER-015 | 策略冲突处理 | 验证 USB 接口禁用时单设备策略切换提示冲突 | 已有UT覆盖 | entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets |
| PER-016 | 记录导出 | 验证设备连接记录可以导出 | 已有UT覆盖 | entry/src/test/viewmodels/PeripheralRecordViewModel.test.ets |
| PER-017 | 记录清理 | 验证设备连接记录可以清理 | 已有UT覆盖 | entry/src/test/viewmodels/PeripheralViewModel.test.ets |
| PER-018 | 策略导出 | 验证黑白名单策略可以导出 | 已有UT覆盖 | entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets |
| PER-019 | 策略还原 | 验证黑白名单策略还原后列表状态同步恢复默认值 | 已有UT覆盖 | entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets |
| PER-020 | 设备连接记录 | 验证蓝牙设备连接后生成连接记录 | 已有UT覆盖 | entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets |
| PER-021 | 设备连接记录 | 验证蓝牙设备断开后生成断开记录 | 已有UT覆盖 | entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets |
| PER-022 | 设备详情 | 验证点击蓝牙设备记录后展示设备详情 | 不补UT | 蓝牙详情展示属于 UI 侧场景；蓝牙记录建模已有 UT，不再补展示 UT。 |
| PER-023 | 单设备策略切换 | 验证蓝牙设备可切换为禁止接入策略 | 已有UT覆盖 | entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets |
| PER-024 | 单设备策略切换 | 验证蓝牙设备可从禁止接入恢复为允许接入 | 已有UT覆盖 | entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets |
| PER-025 | USB接口策略 | 验证 USB 接口策略下发失败时 Select 从禁用回滚到启用 | 不补UT | Select 显示回滚属于 AsyncSelectRow 组件本地交互状态，不进入本轮 UT 补充范围。 |
| PER-026 | USB存储策略 | 验证 USB 存储策略下发失败时 Select 从只读回滚到读写 | 不补UT | Select 显示回滚属于 AsyncSelectRow 组件本地交互状态，不进入本轮 UT 补充范围。 |
| PER-027 | 单设备策略切换 | 验证黑白名单策略下发失败时 Select 从禁止接入回滚到允许接入 | 已有UT覆盖 | entry/src/test/viewmodels/PeripheralPolicyViewModel.test.ets |
| PER-028 | 首次连接自动拉黑 | 验证 USB 设备首次连接且本地无策略时自动下发禁止接入并写入黑名单 | 已有UT覆盖 | entry/src/test/peripheral/connection-record-usb-consumer.test.ets |
| PER-029 | 首次连接自动拉黑 | 验证蓝牙设备首次连接且本地无策略时按 MAC 自动下发禁止接入并写入黑名单 | 已有UT覆盖 | entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets |
| PER-030 | 首次连接自动拉黑 | 验证已有允许接入策略的设备再次连接时不被自动改回禁止接入 | 已有UT覆盖 | entry/src/test/peripheral/connection-record-usb-consumer.test.ets；entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets |
| PER-031 | 首次连接自动拉黑 | 验证已有禁止接入策略的设备再次连接时不重复下发策略 | 已有UT覆盖 | entry/src/test/peripheral/connection-record-usb-consumer.test.ets；entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets |
| PER-032 | 首次连接自动拉黑 | 验证自动拉黑系统下发失败时不保存本地黑名单策略，连接记录仍保留失败原因 | 已有UT覆盖 | entry/src/test/peripheral/connection-record-usb-consumer.test.ets；entry/src/test/peripheral/connection-record-bluetooth-acl-consumer.test.ets |
| PER-033 | 首次连接自动拉黑 | 验证 USB 存储总策略为禁止访问时，首次接入 USB 存储设备不自动下发设备级黑名单 | 已有UT覆盖 | entry/src/test/peripheral/connection-record-usb-consumer.test.ets |

## 身份鉴别

| 用例ID | 功能点 | 用例描述 | UT覆盖状态 | UT覆盖位置/不覆盖原因 |
| --- | --- | --- | --- | --- |
| ID-001 | 口令复杂度策略 | 验证保存口令复杂度策略：最小长度 8，大写/小写/数字开启，特殊字符关闭 | 已有UT覆盖 | entry/src/test/identity/settings-viewmodel.test.ets；entry/src/test/identity/service.test.ets |
| ID-002 | 密码有效期策略 | 验证将密码有效期设置为 180 天后保存成功 | 已有UT覆盖 | entry/src/test/identity/settings-viewmodel.test.ets；entry/src/test/identity/service.test.ets |
| ID-003 | 密码有效期策略 | 验证将自定义密码有效期设置为 30 天后保存成功 | 已有UT覆盖 | entry/src/test/identity/settings-viewmodel.test.ets；entry/src/test/identity/service.test.ets |
| ID-004 | 输入参数校验 | 验证自定义密码有效期非法字符被过滤，空值保存时被拦截 | 已有UT覆盖 | entry/src/test/identity/settings-viewmodel.test.ets；entry/src/test/identity/service.test.ets |
| ID-007 | 策略保存 | 验证自定义密码有效期输入 0 天时触发风险提示 | 已有UT覆盖 | entry/src/test/identity/settings-viewmodel.test.ets；entry/src/test/identity/service.test.ets |

## 工具设置

| 用例ID | 功能点 | 用例描述 | UT覆盖状态 | UT覆盖位置/不覆盖原因 |
| --- | --- | --- | --- | --- |
| SET-002 | 启动认证开关 | 验证关闭启动时身份校验后保存成功 | 已有UT覆盖 | entry/src/test/tool-settings/viewmodel.test.ets |
| SET-003 | 认证方式选择 | 验证选择 PIN 认证方式后保存成功 | 已有UT覆盖 | entry/src/test/tool-settings/viewmodel.test.ets |
| SET-004 | 认证方式选择 | 验证选择指纹认证方式后保存成功 | 已有UT覆盖 | entry/src/test/tool-settings/viewmodel.test.ets |
| SET-005 | 无变更保存 | 验证未修改设置时保存按钮不可点击 | 已有UT覆盖 | entry/src/test/tool-settings/viewmodel.test.ets |
| SET-006 | 认证方式不可用提示 | 验证选择当前设备不可用的认证方式时出现不可用确认提示 | 已有UT覆盖 | entry/src/test/tool-settings/viewmodel.test.ets |
| SET-007 | 修改密码入口 | 验证点击修改密码后拉起系统“生物识别和密码”页面 | 已有UT覆盖 | entry/src/test/tool-settings/viewmodel.test.ets；entry/src/test/tool-settings/system-settings-service.test.ets |

## 帮助与反馈

| 用例ID | 功能点 | 用例描述 | UT覆盖状态 | UT覆盖位置/不覆盖原因 |
| --- | --- | --- | --- | --- |
| HELP-001 | 页面展示 | 验证帮助与反馈页可正常打开 | 不补UT | 页面打开属于页面渲染/导航场景，不进入本轮 UT 补充范围。 |
| HELP-002 | 使用指南展示 | 验证使用指南内容展示完整 | 不补UT | 使用指南展示属于页面展示场景；文案结构已有基础 UT，不再补。 |
| HELP-003 | FAQ展开收起 | 验证 FAQ 可以展开和收起 | 不补UT | FAQ 展开收起属于页面交互场景，不进入本轮 UT 补充范围。 |
| HELP-004 | 联系方式展示 | 验证联系与反馈信息展示正确 | 不补UT | 联系方式展示属于页面展示场景；文案结构已有基础 UT，不再补。 |

## 全局导航与主题

| 用例ID | 功能点 | 用例描述 | UT覆盖状态 | UT覆盖位置/不覆盖原因 |
| --- | --- | --- | --- | --- |
| NAV-001 | 侧边栏导航 | 验证侧边栏可以进入所有主模块 | 不补UT | 导航、弹窗或菜单交互属于 UI/ohosTest 范围，不进入本轮 UT 补充范围。 |
| NAV-002 | 返回按钮 | 验证子页面返回按钮回到安全总览或上级页面 | 不补UT | 导航、弹窗或菜单交互属于 UI/ohosTest 范围，不进入本轮 UT 补充范围。 |
| NAV-003 | 主题菜单 | 验证右上角主题菜单可以打开和关闭 | 不补UT | 导航、弹窗或菜单交互属于 UI/ohosTest 范围，不进入本轮 UT 补充范围。 |
| NAV-004 | 深浅色切换 | 验证浅色模式切换生效 | 已有UT覆盖 | entry/src/test/theme/theme-manager.test.ets |
| NAV-005 | 深浅色切换 | 验证深色模式切换生效 | 已有UT覆盖 | entry/src/test/theme/theme-manager.test.ets |
| NAV-006 | 深浅色切换 | 验证跟随系统模式保存和回显 | 已有UT覆盖 | entry/src/test/theme/theme-manager.test.ets |
| NAV-007 | 关于弹窗 | 验证关于弹窗展示应用信息 | 不补UT | 导航、弹窗或菜单交互属于 UI/ohosTest 范围，不进入本轮 UT 补充范围。 |

## 系统集成基础

| 用例ID | 功能点 | 用例描述 | UT覆盖状态 | UT覆盖位置/不覆盖原因 |
| --- | --- | --- | --- | --- |
| SYS-005 | 导出文件能力 | 验证通用 CSV 导出能力正常 | 已有UT覆盖 | entry/src/test/common/csv-file-export-service.test.ets；entry/src/test/log-manage/export-service.test.ets |
| SYS-006 | 本地存储能力 | 验证设置类配置重启后可恢复 | 不补UT | 重启后恢复属于集成语义；存储读写已有基础 UT，不再补。 |
| SYS-007 | 应用恢复 | 验证应用前后台切换后当前页面状态正常 | 不补UT | 前后台切换属于应用生命周期集成场景，不进入本轮 UT 补充范围。 |

## 待补 UT 清单

当前无待补本地 UT。

## 不补 UT 的边界

- 页面渲染、导航、弹窗交互、菜单开关和空状态展示不纳入本轮 UT。
- 依赖鸿蒙运行时的 `application.getApplicationContext()`、真实 Preferences 落盘、页面弹窗刷新等链路不作为 Local UT 补充目标；如需验证，应进入 ohosTest 或设备侧集成测试范围。
- `LOG-002/003/017/018` 的真实系统触发步骤是给人工执行看的；UT 已覆盖事件映射和采集处理，不再补。
- `PER-025/026` 的 Select 显示回滚属于 `AsyncSelectRow` 组件本地交互状态，不再补 UT。

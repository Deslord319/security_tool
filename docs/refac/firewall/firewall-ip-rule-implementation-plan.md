# 防火墙 IP 规则实施计划

> 状态：Frozen  
> 日期：2026-04-20  
> 规格来源：`docs/refac/firewall/firewall-ip-rule-single-source-of-truth.md`  
> 适用范围：仅用于“防火墙管理 > 自定义模式 > 新增/编辑 IP 规则”的实施  
> 说明：本文档冻结后，后续代码修改必须以本文为准

## 0. 背景+目标

当前 IP 规则实现与已确认规格之间存在差异，主要体现在：

1. IP 规则没有按方向固定主字段语义
2. IP 输入无法覆盖 IP 段
3. 端口输入无法覆盖混写和范围
4. `ALL` 的展示、回显和保存语义不统一
5. 冲突检测口径仍偏向旧规则定义

本次实施目标是：

1. 让 UI 展示、输入、回显和冲突检测都遵循冻结后的 SSOT
2. 保持 MVVM 边界清晰
3. 保持最小修改，不改持久化结构，不改主保存/下发链路
4. 不把规则真相散落到 View 层

## 1. 修改边界

### 1.1 必改文件

本次只修改以下 4 个运行时代码文件：

1. `entry/src/main/ets/components/firewall/rules/AddRuleDialog.ets`
2. `entry/src/main/ets/services/firewall/FirewallRuleUtils.ets`
3. `entry/src/main/ets/views/firewall/rules/FirewallRulesPage.ets`
4. `entry/src/main/ets/constants/modules/FirewallStrings.ets`

测试同步修改：

1. `entry/src/test/firewall/strings.test.ets`
2. `entry/src/test/firewall/rule-utils.test.ets`
3. `entry/src/test/List.test.ets`

### 1.2 不修改文件

以下文件本次不修改：

- `entry/src/main/ets/services/firewall/FirewallService.ets`
- `entry/src/main/ets/viewmodels/firewall/rules/FirewallRulesViewModel.ets`
- `entry/src/main/ets/services/firewall/FirewallLocalRepository.ets`
- `entry/src/main/ets/services/firewall/FirewallSystemRepository.ets`
- `entry/src/main/ets/services/firewall/FirewallModels.ets`

说明：

- 本次不改数据模型结构
- 本次不改持久化结构
- 本次不改规则下发主流程

## 2. 新增函数清单

### 2.1 `entry/src/main/ets/services/firewall/FirewallRuleUtils.ets`

新增 2 个函数：

1. `static formatIpParamsForDisplay(params?: netFirewall.NetFirewallIpParams[]): string`
2. `static formatPortParamsForDisplay(params?: netFirewall.NetFirewallPortParams[]): string`

### 2.2 `entry/src/main/ets/components/firewall/rules/AddRuleDialog.ets`

新增 5 个辅助函数：

1. `private resolveIpAddressForDirection(rule: netFirewall.NetFirewallRule): string`
2. `private resolvePortForDirection(rule: netFirewall.NetFirewallRule): string`
3. `private getIpFieldLabel(): string`
4. `private parseIpInput(raw: string): DialogParseResult<netFirewall.NetFirewallIpParams[] | undefined>`
5. `private parsePortInput(raw: string, invalidMessage: string): DialogParseResult<netFirewall.NetFirewallPortParams[] | undefined>`

### 2.3 `entry/src/main/ets/views/firewall/rules/FirewallRulesPage.ets`

新增 2 个辅助函数：

1. `private getIpAddressLabel(rule: netFirewall.NetFirewallRule): string`
2. `private getPrimaryPortLabel(rule: netFirewall.NetFirewallRule): string`

## 3. 逐文件实施计划

### 3.1 `entry/src/main/ets/constants/modules/FirewallStrings.ets`

#### 修改前职责

- 提供现有表单标题、placeholder 和错误文案
- 只有旧的地址/端口展示文案

#### 修改后职责

- 补齐新规格所需的标题、placeholder 和错误提示
- 提供统一的 `ALL` 展示文案

#### 需要改的内容

- 新增 `LOCAL_ADDRESS`
- 更新 IP placeholder
- 更新端口 placeholder
- 新增错误提示：
  - `ERROR_INVALID_IP_RANGE`
  - `ERROR_INVALID_CIDR_MASK`
  - `ERROR_INVALID_PORT_TOKEN`
  - `ERROR_INVALID_PORT_RANGE`
  - `ERROR_PORT_ITEM_LIMIT`

#### 伪代码

```ts
LOCAL_ADDRESS = '本地地址'
IP_PLACEHOLDER = '例如 110.110.110.110、8.8.8.0/24 或 110.110.110.1-110.110.110.254'
PORT_PLACEHOLDER = '例如 80,443,1000-2000'

ERROR_INVALID_IP_RANGE = 'IP 段格式不正确'
ERROR_INVALID_CIDR_MASK = 'CIDR mask 范围必须为 0-32'
ERROR_INVALID_PORT_TOKEN = '端口格式不正确'
ERROR_INVALID_PORT_RANGE = '端口范围格式不正确'
ERROR_PORT_ITEM_LIMIT = '端口项数量超过上限'
```

### 3.2 `entry/src/main/ets/services/firewall/FirewallRuleUtils.ets`

#### 修改前职责

- 负责规则构造、归一化和冲突判断
- 现有逻辑对 IP 规则主要偏向单值地址和单端口

#### 修改后职责

- 继续作为规则算法中心
- 负责新规格下的展示格式化、规则标准化和冲突判断
- 不承担 View 层输入交互

#### 需要改的现有函数

1. `validateRuleIntentInput(input)`
2. `buildIntentInputFromRule(rule, targetUserIds)`
3. `cloneDisplayRuleFromIntent(intent, deployments)`
4. `normalizeIpRule(intent)`
5. `normalizePortRange(intent)`
6. `isSameIpRuleKey(left, right)`
7. `isIpRuleOverlap(left, right)`

#### 需要新增的函数

1. `formatIpParamsForDisplay(params?)`
2. `formatPortParamsForDisplay(params?)`

#### 修改点说明

##### `validateRuleIntentInput(input)`

修改前：

- IP 规则固定要求某个地址字段存在

修改后：

- IP 规则允许地址和端口为空
- 空值语义由 `ALL` 表示
- 只校验结构层是否可用，不在这里解析字符串语法

伪代码：

```ts
if input.type == RULE_IP:
  return success()
```

##### `buildIntentInputFromRule(rule, targetUserIds)`

修改前：

- 从展示规则中提取意图字段

修改后：

- 保留现有提取职责
- 确保不丢失：
  - 入站本地地址/端口
  - 出站远端地址/端口
  - IP 段
  - 多端口数组

伪代码：

```ts
return {
  name: rule.name,
  type: rule.type,
  direction: rule.direction,
  action: rule.action,
  protocol: rule.protocol,
  targetUserIds: normalize(targetUserIds),
  localIps: clone(rule.localIps),
  remoteIps: clone(rule.remoteIps),
  localPorts: clone(rule.localPorts),
  remotePorts: clone(rule.remotePorts),
  domains: clone(rule.domains),
  dns: clone(rule.dns),
}
```

##### `cloneDisplayRuleFromIntent(intent, deployments)`

修改前：

- 将 intent 转换成展示规则

修改后：

- 保持展示规则转换职责
- 让展示规则保留足够信息给页面回显和列表展示

伪代码：

```ts
displayRule = clone(intent)
displayRule.deployments = deployments
return displayRule
```

##### `normalizeIpRule(intent)`

修改前：

- 优先从远端地址字段取值

修改后：

- 按方向选择地址来源：
  - 入站：`localIps`
  - 出站：`remoteIps`

伪代码：

```ts
ipParams = intent.direction == RULE_IN ? intent.localIps?.[0] : intent.remoteIps?.[0]
```

##### `normalizePortRange(intent)`

修改前：

- 只关注单个端口项

修改后：

- 保持函数存在
- 方向化取值
- 为上层冲突判断提供基础值

伪代码：

```ts
ports = intent.direction == RULE_IN ? intent.localPorts : intent.remotePorts
first = ports?.[0]
if first is empty:
  return defaultRange
return normalize(first)
```

##### `isSameIpRuleKey(left, right)`

修改前：

- 基于单 IP 区间和单端口区间判断同键

修改后：

- 按方向比较主字段语义
- 端口按数组完全一致判断

伪代码：

```ts
if left.direction != right.direction:
  return false
if left.protocol != right.protocol:
  return false
if normalizeIpRule(left) != normalizeIpRule(right):
  return false
return portsExactlyEqual(directionBasedPorts(left), directionBasedPorts(right))
```

##### `isIpRuleOverlap(left, right)`

修改前：

- 基于单区间判断是否重叠

修改后：

- 比较方向对应的地址区间
- 比较端口数组任意项的交集

伪代码：

```ts
if protocol not overlap:
  return false
if ip ranges not overlap:
  return false
if either port list empty:
  return true
for each leftPort in leftPorts:
  for each rightPort in rightPorts:
    if rangeOverlap(leftPort, rightPort):
      return true
return false
```

##### `formatIpParamsForDisplay(params?)`

修改后职责：

- 将 IP 参数数组转成单字符串回显

伪代码：

```ts
if params empty:
  return ''
first = params[0]
if first is range:
  return `${startIp}-${endIp}`
if mask is 32 or missing:
  return address
return `${address}/${mask}`
```

##### `formatPortParamsForDisplay(params?)`

修改后职责：

- 将端口参数数组转成统一的逗号字符串回显

伪代码：

```ts
if params empty:
  return ''
return params.map(formatSinglePort).join(',')
```

### 3.3 `entry/src/main/ets/components/firewall/rules/AddRuleDialog.ets`

#### 修改前职责

- 负责新增/编辑规则弹窗
- 现有逻辑更偏旧的远端地址 + 单端口语义

#### 修改后职责

- 继续只做 View 层输入和展示
- 根据方向显示主字段
- 支持新规格输入
- 负责编辑态回显
- 负责提交前轻量校验

#### 需要改的现有函数

1. `applyInitialRule()`
2. `resolveRemoteAddress(rule)`
3. `resolvePort(ports)`
4. `validateForm()`
5. `applyRuleSpecificFields(rule, remoteAddress, localPort, remotePort)`

#### 需要新增的函数

1. `resolveIpAddressForDirection(rule)`
2. `resolvePortForDirection(rule)`
3. `getIpFieldLabel()`

#### 修改点说明

##### `applyInitialRule()`

修改前：

- 固定回填远端地址、本地端口、远端端口

修改后：

- IP 规则按方向回填主地址和主端口
- 回填值使用统一格式化结果

伪代码：

```ts
if rule.type == RULE_IP:
  addressValue = resolveIpAddressForDirection(rule)
  portValue = resolvePortForDirection(rule)
  if rule.direction == RULE_IN:
    localPort = portValue
    remotePort = ''
  else:
    remotePort = portValue
    localPort = ''
```

##### `resolveRemoteAddress(rule)`

修改前：

- 用于解析旧的远端地址展示

修改后：

- 仅保留给 `DOMAIN` / `DNS` 或兼容路径使用
- IP 规则不再依赖该函数表达唯一语义

##### `resolvePort(ports)`

修改前：

- 只回显第一个端口项

修改后：

- 改为回显完整端口字符串
- 最终调用 `FirewallRuleUtils.formatPortParamsForDisplay(...)`

##### `validateForm()`

修改前：

- 只接受旧的 IP 和单端口格式

修改后：

- 支持地址空值
- 支持 IP 段
- 支持端口混写
- 对输入字符串做轻量校验并返回精确错误

伪代码：

```ts
if ruleType == RULE_IP:
  checkAddressText()
  checkPortText()
  if invalid:
    return errorMessage
```

说明：

- 字符串语法校验留在本文件
- 不把字符串解析规则分散到多个文件

##### `applyRuleSpecificFields(...)`

修改前：

- 固定把 IP 规则写入远端地址和双端口字段

修改后：

- 按方向写入正确的主字段
- 地址和端口为空时对应字段不传

伪代码：

```ts
if ruleType == RULE_IP:
  if ruleDirection == RULE_IN:
    rule.localIps = parsedIps
    rule.localPorts = parsedPorts
    rule.remoteIps = undefined
    rule.remotePorts = undefined
  else:
    rule.remoteIps = parsedIps
    rule.remotePorts = parsedPorts
    rule.localIps = undefined
    rule.localPorts = undefined
```

### 3.4 `entry/src/main/ets/views/firewall/rules/FirewallRulesPage.ets`

#### 修改前职责

- 负责规则列表和详情展示
- 现有展示偏向旧地址/单端口语义

#### 修改后职责

- 继续只做展示
- 按方向显示 IP 规则主字段
- 使用统一格式化结果展示地址和端口

#### 需要改的现有函数

1. `getRuleAddress(rule)`
2. `getRuleLocalPort(rule)`
3. `getRuleRemotePort(rule)`
4. 详情区渲染逻辑

#### 需要新增的函数

1. `getIpAddressLabel(rule)`
2. `getPrimaryPortLabel(rule)`

#### 修改点说明

##### `getRuleAddress(rule)`

修改前：

- IP 规则固定展示远端地址

修改后：

- 入站展示本地地址
- 出站展示远端地址
- 空值展示 `ALL`

伪代码：

```ts
if rule.type == RULE_IP:
  ipParams = rule.direction == RULE_IN ? rule.localIps : rule.remoteIps
  return FirewallRuleUtils.formatIpParamsForDisplay(ipParams) || ALL
```

##### `getRuleLocalPort(rule)` / `getRuleRemotePort(rule)`

修改前：

- 只展示第一个端口项

修改后：

- 展示完整端口串
- 空值展示 `ALL`

伪代码：

```ts
return FirewallRuleUtils.formatPortParamsForDisplay(ports) || ALL
```

##### 详情区渲染逻辑

修改前：

- 固定展示远端地址、本地端口、远端端口

修改后：

- IP 规则按方向切换标题和值

伪代码：

```ts
if rule.type == RULE_IP:
  show(getIpAddressLabel(rule), getRuleAddress(rule))
  show(getPrimaryPortLabel(rule), rule.direction == RULE_IN ? getRuleLocalPort(rule) : getRuleRemotePort(rule))
```

## 4. 风险与不做项

### 4.1 风险

1. 端口混写和范围判断会影响冲突检测准确性，必须统一经过 Utils
2. 地址和端口都为空时允许直接保存，容易与默认策略含义混淆，需要保持展示一致
3. 编辑态回显如果没有统一格式化，会出现输入语义与展示语义不一致
4. 冲突判断如果仍沿用旧的远端地址口径，会造成列表与弹窗提示不一致

### 4.2 不做项

1. 不改 `FirewallRulesViewModel.ets`
2. 不改 `FirewallLocalRepository.ets`
3. 不改 `FirewallSystemRepository.ets`
4. 不改 `FirewallModels.ets`
5. 不做持久化结构迁移
6. 不做 `DOMAIN` / `DNS` 规则重构
7. 不做端口区间自动合并
8. 不做高级字段预留

## 5. 验收信号

完成后应满足：

1. 入站 IP 规则显示本地地址 + 本地端口
2. 出站 IP 规则显示远端地址 + 远端端口
3. IP 输入支持单 IP、CIDR 和 IP 段
4. 端口输入支持单端口、范围和混写
5. 空值统一展示为 `ALL`
6. 编辑态回显与列表展示一致
7. 冲突检测按新字段语义生效
8. 代码中不出现新的持久化结构变更

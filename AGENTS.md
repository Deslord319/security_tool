# AGENTS.md - AI Coder 开发指南

本文档为 AI 编码助手（如 Qoder、Cursor、Copilot 等）提供本项目的关键开发规范和操作指南。

## 项目概述

- **项目名称**：SecurityTool（HarmonyOS 安全管理中心）
- **包名**：`com.huawei.securitytool`（不含下划线）
- **入口页面**：`pages/MainPage`（非 pages/Index）
- **目标设备**：2in1
- **语言**：ArkTS (ETS)

## 构建与签名流程（必读）

### 构建

构建产物位于：
```
entry/build/default/outputs/default/entry-default-unsigned.hap
```

本地执行 `build_hap.bat`、`hvigorw assembleHap` 或测试链路中需要调用 `hvigorw` 时，查找规则固定如下：

1. 优先使用环境变量 `DEVECOSTUDIO_HOME`
2. 若未设置，则优先检查 `C:\Program Files\Huawei\DevEco Studio`
3. 定位到 IDE 根目录后，统一从 `tools\hvigor\bin\hvigorw.bat` 获取 `hvigorw`
4. `JAVA_HOME` 仅作为兜底，不应再在脚本或测试命令中写死本机绝对路径

测试、构建或子 agent 验证时，如果出现“找不到 `hvigorw`”，默认先按以上顺序排查，不要直接假设系统全局 `PATH` 已配置。

### 签名（重要）

签名工具位于项目根目录 `hapsigner/` 下。完整签名流程如下：

#### 步骤 1：拷贝 unsigned HAP

将构建产物拷贝到签名目录：
```bash
cp entry/build/default/outputs/default/entry-default-unsigned.hap hapsigner/entry-default-unsigned.hap
```

#### 步骤 2：生成签名描述文件（p7b）

**仅在修改了 `hapsigner/UnsgnedDebugProfileTemplate.json` 后需要执行此步骤。**

修改场景包括：更改包名、新增/删除权限。

```bash
cd hapsigner && ./1-debug-p7b.bat
```

或使用 Java 命令：
```bash
cd hapsigner
java -jar hap-sign-tool.jar sign-profile \
  -mode "localSign" \
  -keyAlias "OpenHarmony Application Profile Debug" \
  -keyPwd "123456" \
  -inFile "UnsgnedDebugProfileTemplate.json" \
  -outFile "ohos_provision_debug.p7b" \
  -keystoreFile "OpenHarmony.p12" \
  -keystorePwd "123456" \
  -signAlg "SHA256withECDSA" \
  -profileCertFile "OpenHarmonyProfileDebug.pem"
```

#### 步骤 3：签名 HAP

```bash
cd hapsigner && ./2-debug-sign.bat
```

或使用 Java 命令：
```bash
cd hapsigner
java -jar hap-sign-tool.jar sign-app \
  -keyAlias "openharmony application release" \
  -signAlg "SHA256withECDSA" \
  -mode "localSign" \
  -appCertFile "OpenHarmonyApplication.pem" \
  -profileFile "ohos_provision_debug.p7b" \
  -inFile "entry-default-unsigned.hap" \
  -keystoreFile "OpenHarmony.p12" \
  -outFile "signApp.hap" \
  -keyPwd "123456" \
  -keystorePwd "123456"
```

#### 步骤 4：安装到设备

```bash
hdc install hapsigner/signApp.hap
```

#### 步骤 5：激活企业管理员（MDM 功能必需）

```bash
hdc shell edm enable-admin -n com.huawei.securitytool -a EnterpriseAdminAbility -t super
```

## 关键一致性规则

以下三个位置的包名和权限必须保持一致，修改任一处时必须同步其余两处：

| 文件 | 字段 |
|------|------|
| `AppScope/app.json5` | `bundleName` |
| `entry/src/main/module.json5` | `requestPermissions` |
| `hapsigner/UnsgnedDebugProfileTemplate.json` | `bundle-name`、`acls.allowed-acls`、`permissions.restricted-permissions` |

**修改 `UnsgnedDebugProfileTemplate.json` 后，必须重新执行步骤 2（生成 p7b），再执行步骤 3（签名）。**

## 日志约定

- 主线业务代码统一通过 `entry/src/main/ets/utils/LogUtils.ets` 输出日志，不要在业务文件中直接引入或调用 `hilog`
- 每个文件只定义一个 `TAG`，`domain` 由 `LogUtils` 统一封装；不要再在业务文件里声明独立 `DOMAIN`
- 新增日志优先保留错误、告警和关键流程结论，避免重复的 start/success/info 噪音日志
- 如果后续需要对测试日志做统一封装，沿用同样思路，不要继续扩散裸 `hilog`

## 编码约定

- 含中文的代码、测试、文档文件必须按 UTF-8 处理；修改后必须回读验证，禁止提交乱码、`?`、`�`、异常转码文本
- 在 Windows / PowerShell 环境中，禁止使用默认编码不明确的批量文本链路改写含中文文件，例如裸 `Get-Content` / `Set-Content`、`Out-File`、重定向 `>` / `>>`、管道拼接整文件内容
- 需要批量修改含中文文件时，必须显式指定 UTF-8 读写，且先抽样校验再全量执行；如果链路不能证明编码安全，优先改用 `apply_patch` 或放弃批量改写

## 签名密钥别名速查

| 用途 | Key Alias |
|------|-----------|
| 签名描述文件 (p7b) | `OpenHarmony Application Profile Debug` |
| 签名应用 (HAP) | `openharmony application release` |
| 密钥库/密钥密码 | `123456` |

## 当前权限列表

```
ohos.permission.MANAGE_NET_FIREWALL
ohos.permission.GET_NET_FIREWALL
ohos.permission.ENTERPRISE_MANAGE_NETWORK
ohos.permission.ENTERPRISE_MANAGE_USB
ohos.permission.ENTERPRISE_MANAGE_RESTRICTIONS
ohos.permission.ENTERPRISE_MANAGE_BLUETOOTH
ohos.permission.ENTERPRISE_GET_DEVICE_INFO
ohos.permission.ENTERPRISE_MANAGE_WIFI
ohos.permission.ENTERPRISE_ADMIN_MANAGE
ohos.permission.ENTERPRISE_MANAGE_SECURITY
ohos.permission.ENTERPRISE_SET_ACCOUNT_POLICY
```

新增权限时，需要同时在 `module.json5` 的 `requestPermissions` 和 `UnsgnedDebugProfileTemplate.json` 的 `acls.allowed-acls` + `permissions.restricted-permissions` 中添加。

## 页面路由

| 路由 ID | 页面 | 说明 |
|---------|------|------|
| `dashboard` | DashboardPage | 安全总览 |
| `firewall` | FirewallPage | 防火墙管理 |
| `firewall-rules` | FirewallRulesPage | 防火墙规则详情 |
| `log-manage` | PlaceholderPage | 日志管理（待开发） |
| `peripheral-manage` | PeripheralPage | 外设管理（已完成） |
| `identity` | IdentityPage | 身份鉴别（已完成） |
| `tool-settings` | ToolSettingsPage | 工具设置（已完成） |

## 常见问题

1. **页面空白**：检查 `EntryAbility.ets` 中 `windowStage.loadContent` 的参数是否为 `'pages/MainPage'`。
2. **安装失败（签名错误）**：确认 `UnsgnedDebugProfileTemplate.json` 中 `bundle-name` 与 `app.json5` 中 `bundleName` 一致，并重新执行 p7b 生成 + 签名。
3. **权限不足**：确认权限同时声明在 `module.json5` 和签名模板的 `acls` + `permissions` 中。
4. **MDM 操作失败（错误码 9200001）**：表示应用未激活为企业管理员，执行 `edm enable-admin -n com.huawei.securitytool -a EnterpriseAdminAbility -t super` 后重试。
5. **构建路径错误**：MCP `build_app` 工具路径参数注意大小写，使用 `D:\project\ai\security_tool`。

---

## CI/CD 自动化流程

### GitHub Actions 工作流

项目已配置完整的 CI/CD 流水线，自动化流程如下：

#### 触发条件

| 事件 | 分支/标签 | 执行流程 |
|------|----------|---------|
| Push | `develop` | 构建 + 测试 |
| Push | `main` | 构建 + 测试 + 签名 |
| Tag | `v*` | 构建 + 测试 + 签名 + GitHub Release |
| Pull Request | `main` | 构建 + 测试 |

#### 工作流说明

**Job 1: Build** - 构建验证
- 安装 HarmonyOS SDK 6.0.2
- 执行 `hvigorw assembleHap` 构建
- 生成未签名 HAP 包
- 上传为 Artifact（保留 7 天）

**Job 2: Test** - 组件测试
- 执行 `hvigorw :entry:test`
- 生成测试报告
- 测试报告上传为 Artifact

**Job 3: Sign** - 自动签名（仅 main/标签）
- 从 GitHub Secrets 读取签名密钥
- 执行 Java 签名命令
- 生成已签名 HAP 包
- 上传为 Artifact（保留 30 天）

**Job 4: Release** - 发布（仅标签）
- 创建 GitHub Release
- 自动上传已签名 HAP
- 生成发布说明

#### Secrets 配置

在 GitHub 仓库 Settings → Secrets and variables → Actions 配置以下密钥：

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `SIGNING_KEYSTORE` | base64 编码的 `.p12` 文件 | 密钥库 |
| `SIGNING_KEYSTORE_PASSWORD` | `123456` | 密钥库密码 |
| `SIGNING_KEY_ALIAS` | `openharmony application release` | 密钥别名 |
| `SIGNING_KEY_PASSWORD` | `123456` | 密钥密码 |

配置指南详见：`.github/SECRETS_SETUP.md`

#### 本地调试 CI

```bash
# 1. 使用 act 工具在本地运行 GitHub Actions
npm install -g @act-js/cli

# 2. 运行构建作业
act push

# 3. 运行测试作业
act -j test
```

#### 状态徽章

添加到 README.md：

```markdown
[![CI/CD](https://github.com/Deslord319/security_tool/actions/workflows/ci.yml/badge.svg)](https://github.com/Deslord319/security_tool/actions/workflows/ci.yml)
```

---

## 附录：自动化脚本

### 一键构建 + 签名 + 安装（本地）

```bash
# Windows (PowerShell)
hvigorw assembleHap --mode module -p product=default -p module=entry && \
cp entry/build/default/outputs/default/entry-default-unsigned.hap hapsigner/ && \
cd hapsigner && .\2-debug-sign.bat && hdc install signApp.hap

# Linux/Mac
./hvigorw assembleHap --mode module -p product=default -p module=entry && \
cp entry/build/default/outputs/default/entry-default-unsigned.hap hapsigner/ && \
cd hapsigner && \
java -jar hap-sign-tool.jar sign-app \
  -keyAlias "openharmony application release" \
  -signAlg "SHA256withECDSA" \
  -mode "localSign" \
  -appCertFile "OpenHarmonyApplication.pem" \
  -profileFile "ohos_provision_debug.p7b" \
  -inFile "entry-default-unsigned.hap" \
  -keystoreFile "OpenHarmony.p12" \
  -outFile "signApp.hap" \
  -keyPwd "123456" \
  -keystorePwd "123456" && \
hdc install signApp.hap
```

## 官方文档来源约定

- 以后查询 **OpenHarmony / HarmonyOS 官方文档** 时，默认优先使用：`https://gitee.com/openharmony/docs/tree/master`
- 默认以该仓库的 `master` 分支内容作为官方文档参考基线。
- 本规则**仅适用于官方文档检索**，不影响代码仓库、Issue、README、社区帖子、博客或其他第三方资料的查找。
- 如果用户在当前任务中明确指定了其他文档来源、其他分支或其他站点，则以用户指令为准。

*最后更新：2026-03-18 - 新增鸿蒙官方文档默认来源约定*

---

## Codex Subagents

本项目已在仓库内落地 Codex 项目级子 agent 配置，位置如下：

- `.codex/config.toml`
- `.codex/agents/SE.toml`
- `.codex/agents/Analysis.toml`
- `.codex/agents/BugFix.toml`
- `.codex/agents/CTest.toml`
- `.codex/agents/Reviewer.toml`
- `.codex/agents/PermissionChecker.toml`

角色分工约定如下：

- 主 agent：负责目标理解、任务拆分、关键判断、结果整合和最终输出，定位为 `Tech Lead + Orchestrator`
- `SE`：负责需求分析、方案拆解、影响面评估、文件职责说明和文件级改动建议，默认只读，建议使用 `gpt-5.4`，输出应尽量形成可直接交给 `BugFix` 的结构化实施方案
- `Analysis`：负责日志、运行证据、首个阻塞点和根因分析
- `BugFix`：负责定点实现和缺陷修复，默认按 `SE` 方案执行，并在实际实现偏离方案时回报差异
- `CTest`：负责构建、安装、启动和既定轻量冒烟回归；当其紧跟在 `BugFix` 之后且改动影响 HAP 时，必须先重新构建、重新签名并重新安装，再执行回归
- `Reviewer`：负责代码审查，重点关注回归、乱码、中文 `\uXXXX` 转义、必要注释、关键日志和敏感信息泄露
- `PermissionChecker`：负责权限、签名、包名、MDM 一致性专项检查，仅在专项问题中按需调用

使用规则：

- 子 agent 功能默认可用，但不会自动派生，必须在 prompt 中显式要求调用
- 小任务默认由主 agent 直接处理，不强制拆分子 agent
- `SE` 负责回答“改什么、为什么改、影响什么”，`Analysis` 负责回答“为什么坏、卡在哪”
- `SE` 输出应尽量包含 `Implementation Scope`、`Out of Scope`、`Acceptance Signals`，作为 `BugFix` 的默认交接格式
- 除非主 agent 明确覆盖，否则 BugFix 应将 SE 输出的方案视为默认执行契约
- 当 CTest 处于 BugFix -> CTest 的修复后验证链路，且 BugFix 改动影响运行时代码或打包输入时，CTest 必须按 fresh deploy 模式执行：重新构建、重新签名、重新安装后才能给出验证结论
- 非修复后验证链路下，CTest 可按弱约束复用当前已安装包，但必须在结果中明确说明是否使用了 freshly deployed build
- 页面链路分析不再单独保留专门角色，需要时由主 agent 或 `BugFix` 直接承担
- Git 提交流程不作为默认常驻子 agent，仍按独立流程处理
- `agent-observer/recorder/recorder.py` 及其 `start-run`、`write-step`、`write-event`、`add-artifact`、`write-review`、`finish-run`、`rebuild-index`、`migrate-legacy-runs` 命令只允许主 agent 使用；子 agent 不得直接调用 recorder，也不得自行写入 `agent-observer/data/`
- 子 agent 可以读取 `agent-observer/data/` 作为上下文，但只能把阶段性结果、证据路径和结论回传给主 agent，由主 agent 决定是否写入 observer
- 所有子 agent 的最终输出必须包含一份稳定的 handoff JSON；主 agent 只接受该 handoff 作为 observer 写入输入，不接受子 agent 直接落盘

### Agent Observer Handoff 契约

所有子 agent 交回主 agent 的最终 handoff 必须满足以下约束：

- 最终消息末尾必须包含一个 fenced `json` 代码块，且其后不得再追加解释性文本
- JSON 顶层字段固定为：`handoffVersion`、`sourceAgent`、`stepTitle`、`status`、`input`、`output`、`artifacts`
- 可选字段：`sourceAgentTaskId`
- `status` 统一使用：`completed`、`blocked`、`partial`、`failed`
- `input.summary`、`output.summary` 必填且必须为非空字符串
- `output.keyPoints` 必须为字符串数组
- `input.details`、`output.details` 必须为对象
- `artifacts` 必须为数组；没有证据时返回空数组

### Agent Observer 编码与落盘规则

- observer 相关临时 JSON（如 handoff、artifacts、review payload）默认按 UTF-8 处理；主 agent 不得依赖 PowerShell/控制台默认编码推断
- 在 Windows / PowerShell 环境中，禁止通过 `echo`、管道、here-string、`>`、`>>`、`Out-File`、`Set-Content` 默认编码等“原始文本链路”传递包含中文的完整 JSON
- 需要中转 observer JSON 时，优先使用显式 UTF-8 文件写入；如果当前链路无法保证 Unicode 安全，则必须改用 ASCII-safe 方式中转（例如将非 ASCII 字符转为 `\uXXXX` 后再落盘/传递）
- 子 agent 返回 handoff 后，主 agent 在写入 `agent.output` 前必须先落临时 payload 文件，再按 UTF-8 回读并校验；若发现 `?`、`�`、`????` 等明显乱码痕迹，不得写入正式 observer 事件
- `write-event` 成功后，主 agent 应重新读取刚写入的 event，确认 `event.payload` 仍是完整 handoff JSON，且关键字段（`stepTitle`、`input.summary`、`output.summary`、artifact 标题/说明）未在写入过程中损坏
- 一旦中文在临时文件中已被替换为字面量 `?`，视为信息已丢失；不得继续沿用该 payload，必须从原始 handoff 重新生成
- 编码校验失败的尝试可以写 review 标记为 `invalid`，但不得把乱码 payload 当作最终有效的 `agent.output`

参考结构如下：

```json
{
  "handoffVersion": "1.0",
  "sourceAgent": "SE",
  "sourceAgentTaskId": "optional-task-id",
  "stepTitle": "短标题",
  "status": "completed",
  "input": {
    "summary": "主 agent 分派给当前子 agent 的阶段目标",
    "details": {}
  },
  "output": {
    "summary": "当前阶段最重要的结论",
    "keyPoints": [
      "要点 1",
      "要点 2"
    ],
    "details": {}
  },
  "artifacts": [
    {
      "kind": "screenshot",
      "title": "证据标题",
      "path": "可选，本地文件路径或相对路径",
      "description": "可选，证据说明"
    }
  ]
}
```

常用协作链路：

- 新功能开发：主 agent -> `SE` -> `BugFix` -> `CTest` -> `Reviewer`
- 一般缺陷修复：主 agent -> `SE` -> `BugFix` -> `CTest` -> `Reviewer`
- 疑难故障：主 agent -> `CTest` -> `Analysis` -> `SE` -> `BugFix` -> `CTest`
- 权限或签名问题：主 agent -> `PermissionChecker` -> `SE` -> `CTest`
- 日常审查：主 agent -> `Reviewer`

详细使用方式见：

- `docs/01-总体设计/Codex子Agent使用手册.md`

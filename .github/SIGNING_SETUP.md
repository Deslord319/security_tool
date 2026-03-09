# GitHub Actions 签名配置指南

本文档指导你如何在 GitHub Actions CI 中配置自动签名，实现完整的 **构建 → 测试 → 签名 → 发布** 流水线。

---

## 📋 当前状态

### ✅ 本地签名已就绪
项目中已包含完整的签名工具链：
- ✅ `hapsigner/hap-sign-tool.jar` - 签名工具（12MB）
- ✅ `hapsigner/OpenHarmony.p12` - 密钥库文件
- ✅ `hapsigner/OpenHarmonyApplication.pem` - 应用证书
- ✅ `hapsigner/UnsgnedDebugProfileTemplate.json` - 签名配置模板
- ✅ `hapsigner/2-debug-sign.bat` - 本地签名脚本
- ✅ `hapsigner/signApp.hap` - 已签名的 HAP 包

### ⚠️ CI 签名需要配置
GitHub Actions **无法访问**本地签名文件（安全原因），需要通过 GitHub Secrets 配置。

---

## 🔐 配置 GitHub Secrets

### 步骤 1: 准备签名密钥文件

在本地执行以下命令生成 base64 编码：

#### Windows (PowerShell):
```powershell
# 生成密钥库的 base64 编码
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("hapsigner\OpenHarmony.p12"))
$base64 | clip
Write-Host "✅ 已复制到剪贴板"
```

#### macOS/Linux:
```bash
# 生成密钥库的 base64 编码
base64 -i hapsigner/OpenHarmony.p12 | pbcopy  # macOS
# 或
base64 -w 0 hapsigner/OpenHarmony.p12  # Linux
```

### 步骤 2: 添加到 GitHub Secrets

1. 打开 GitHub 仓库页面
2. 进入 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**
4. 依次添加以下 4 个 Secrets：

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `SIGNING_KEYSTORE` | 上面生成的 base64 字符串 | 密钥库文件（OpenHarmony.p12） |
| `SIGNING_KEYSTORE_PASSWORD` | `123456` | 密钥库密码 |
| `SIGNING_KEY_ALIAS` | `openharmony application release` | 密钥别名（用于签名 HAP） |
| `SIGNING_KEY_PASSWORD` | `123456` | 密钥密码 |

### 步骤 3: 验证配置

添加完成后，Secrets 列表应显示：
```
✅ SIGNING_KEYSTORE
✅ SIGNING_KEYSTORE_PASSWORD
✅ SIGNING_KEY_ALIAS
✅ SIGNING_KEY_PASSWORD
```

---

## 🚀 CI/CD 流水线说明

### 触发条件

| 事件 | 分支/标签 | 执行流程 |
|------|----------|---------|
| Push | `develop` | 构建 + 测试 |
| Push | `main` / `master` | 构建 + 测试 + 签名 |
| Tag | `v*` | 构建 + 测试 + 签名 + Release |
| Pull Request | `main` / `master` | 构建 + 测试 |

### 流水线 Jobs

#### Job 1: Build - 构建验证
- ✅ 安装 HarmonyOS SDK 6.0.2
- ✅ 执行 `hvigorw assembleHap` 构建
- ✅ 生成未签名 HAP 包
- ✅ 上传为 Artifact（保留 7 天）

#### Job 2: Test - 组件测试
- ✅ 执行所有单元测试（`entry/src/test/`）
- ✅ 执行所有 UI 测试（`entry/src/ohosTest/`）
- ✅ 生成测试报告
- ✅ 上传测试报告（保留 7 天）

#### Job 3: Sign - 自动签名（仅 main/master/标签）
- ✅ 检查是否配置了 Secrets
- ✅ **如果配置了 Secrets**: 自动签名 HAP
- ✅ **如果未配置 Secrets**: 使用预签名 HAP 或创建说明文件
- ✅ 上传已签名 HAP（保留 30 天）

#### Job 4: Release - 发布（仅标签）
- ✅ 创建 GitHub Release
- ✅ 自动上传已签名 HAP
- ✅ 生成发布说明

---

## 📦 构建产物位置

### CI 生成

| 类型 | 下载位置 | 保留期 |
|------|---------|--------|
| 未签名 HAP | Actions → Artifacts → `unsigned-hap` | 7 天 |
| 测试报告 | Actions → Artifacts → `test-reports` | 7 天 |
| 已签名 HAP | Actions → Artifacts → `signed-hap` | 30 天 |
| Release HAP | Releases → 对应版本 | 永久 |

### 本地生成

```bash
# 1. 构建
./build_hap.bat

# 2. 签名
cd hapsigner
copy ..\entry\build\default\outputs\default\entry-default-unsigned.hap .
./2-debug-sign.bat

# 3. 产物位置
hapsigner/signApp.hap  # 已签名 HAP
```

---

## 🔧 常见问题

### Q1: 为什么 CI 签名失败了？

**A**: 检查以下几点：
1. 是否正确配置了 4 个 Secrets
2. base64 编码是否正确（尝试重新生成）
3. 密码是否正确（默认：123456）
4. 查看 CI 日志中的详细错误信息

### Q2: 不配置 Secrets 可以吗？

**A**: 可以！CI 会：
- 自动检测 Secrets 是否存在
- 如果不存在，会使用预签名 HAP（如果存在）
- 或者创建说明文件，指导你本地签名

**推荐**: 开发阶段可以不配置，正式发布前配置。

### Q3: 如何测试 CI 签名？

**A**: 
1. 配置 Secrets
2. 推送到 `master` 分支
3. 查看 Actions 标签页
4. 检查 "Sign HAP" Job 的输出

### Q4: 签名密钥安全吗？

**A**: 非常安全！
- GitHub Secrets 是加密存储的
- 只有 CI 运行时才能访问
- 不会出现在日志中
- 不会被下载到本地

---

## 📖 相关文档

- [AGENTS.md](AGENTS.md) - 完整开发指南
- [README.md](README.md) - 项目说明
- [DEVLOG.md](DEVLOG.md) - 版本记录
- [.github/workflows/ci.yml](../.github/workflows/ci.yml) - CI 配置文件

---

## 🎯 快速验证

配置完 Secrets 后，推送代码验证：

```bash
git add .
git commit -m "ci: 测试自动签名"
git push origin master
```

然后访问：https://github.com/Deslord319/security_tool/actions

查看最新的 CI 运行状态，检查 "Sign HAP" Job 是否成功。

---

*最后更新：2026-03-09*

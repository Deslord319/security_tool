# CI/CD 快速参考

## 🚀 一键部署 CI

### 步骤 1: 配置 GitHub Secrets

```bash
# Windows PowerShell - 生成密钥 base64 编码
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("hapsigner\OpenHarmony.p12"))
$base64 | clip
Write-Host "✅ 已复制到剪贴板，请粘贴到 GitHub Secrets"
```

然后在 GitHub 仓库 Settings → Secrets and variables → Actions 添加：
- `SIGNING_KEYSTORE`: 上面生成的 base64 字符串
- `SIGNING_KEYSTORE_PASSWORD`: `123456`
- `SIGNING_KEY_ALIAS`: `openharmony application release`
- `SIGNING_KEY_PASSWORD`: `123456`

### 步骤 2: 推送代码触发 CI

```bash
git add .
git commit -m "ci: 添加 CI/CD 配置"
git push origin develop  # 触发构建 + 测试
# 或
git push origin main    # 触发构建 + 测试 + 签名
```

### 步骤 3: 查看构建状态

访问：https://github.com/Deslord319/security_tool/actions

---

## 📋 CI 触发矩阵

| 操作 | 分支 | 构建 | 测试 | 签名 | 发布 |
|------|------|------|------|------|------|
| Push | `develop` | ✅ | ✅ | ❌ | ❌ |
| Push | `main` | ✅ | ✅ | ✅ | ❌ |
| Tag | `v*` | ✅ | ✅ | ✅ | ✅ |
| PR | `main` | ✅ | ✅ | ❌ | ❌ |

---

## 🔧 本地调试

### 使用 act 运行 GitHub Actions

```bash
# 安装 act
npm install -g @act-js/cli

# 列出所有作业
act -l

# 运行完整流程
act push

# 仅运行构建作业
act -j build

# 仅运行测试作业
act -j test

# 使用 dry-run 模式检查
act -n
```

### 本地构建 + 签名测试

```bash
# 完整流程
cd security_tool

# 1. 构建
./hvigorw assembleHap --mode module -p product=default -p module=entry

# 2. 拷贝到签名目录
cp entry/build/default/outputs/default/entry-default-unsigned.hap hapsigner/

# 3. 签名
cd hapsigner
./2-debug-sign.bat  # Windows
# 或
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

# 4. 验证
ls -lh signApp.hap
```

---

## 📊 构建产物位置

### CI 生成

| 类型 | 路径 | 保留期 |
|------|------|--------|
| 未签名 HAP | Actions → Artifacts → `unsigned-hap` | 7 天 |
| 测试报告 | Actions → Artifacts → `test-reports` | 7 天 |
| 已签名 HAP | Actions → Artifacts → `signed-hap` | 30 天 |
| Release HAP | Releases → 对应版本 | 永久 |

### 本地生成

```
entry/build/default/outputs/default/entry-default-unsigned.hap  # 未签名
hapsigner/signApp.hap                                           # 已签名
entry/.test/default/outputs/ohosTest/reports/                   # 测试报告
```

---

## ⚠️ 常见问题

### 1. 签名失败

**症状**: `Sign HAP` 作业失败

**解决**:
```bash
# 检查 Secrets 是否正确配置
# 确认 OpenHarmony.p12 文件存在且未损坏
# 验证密钥密码：123456
```

### 2. 测试不通过

**症状**: `Test` 作业失败

**解决**:
```bash
# 本地运行测试查看详细信息
./hvigorw :entry:test --mode module -p product=default

# 检查测试报告
open entry/.test/default/outputs/ohosTest/reports/index.html
```

### 3. SDK 安装失败

**症状**: `Setup HarmonyOS SDK` 步骤失败

**解决**:
- 检查 `harmonyos-dev/setup-harmonyos-sdk@v1` action 是否可用
- 考虑使用 Docker 镜像或华为云 DevCloud

---

## 📖 相关文档

- [AGENTS.md](AGENTS.md) - 完整开发指南
- [.github/SECRETS_SETUP.md](.github/SECRETS_SETUP.md) - Secrets 配置详解
- [DEVLOG.md](DEVLOG.md) - 版本记录

---

*最后更新：2026-03-09*

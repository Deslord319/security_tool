# GitHub Secrets 配置指南

本文档指导你如何在 GitHub 仓库中配置 CI/CD 所需的密钥。

## 前置准备

### 1. 准备签名密钥文件

确保以下文件存在于 `hapsigner/` 目录：
- `OpenHarmony.p12` - 密钥库文件
- `UnsgnsedDebugProfileTemplate.json` - 签名配置模板

### 2. 生成 Base64 编码

#### Windows (PowerShell):
```powershell
# 生成密钥库的 base64 编码
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("hapsigner\OpenHarmony.p12"))
$base64 | clip
echo "✅ 已复制到剪贴板"

# 生成签名模板的 base64 编码（可选，如果模板不包含敏感信息可直接使用）
$base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("hapsigner\UnsgnsedDebugProfileTemplate.json"))
$base64 | clip
```

#### macOS/Linux:
```bash
# 生成密钥库的 base64 编码
base64 -i hapsigner/OpenHarmony.p12 | pbcopy  # macOS
# 或
base64 -w 0 hapsigner/OpenHarmony.p12  # Linux

# 生成签名模板的 base64 编码
base64 -i hapsigner/UnsgnsedDebugProfileTemplate.json | pbcopy  # macOS
```

## 配置 GitHub Secrets

### 步骤 1: 进入 Secrets 设置页面

1. 打开 GitHub 仓库页面
2. 点击 **Settings** 标签
3. 左侧菜单选择 **Secrets and variables** → **Actions**
4. 点击 **New repository secret** 按钮

### 步骤 2: 添加 Secrets

依次添加以下 5 个 Secrets：

| Secret 名称 | 值 | 说明 |
|------------|-----|------|
| `SIGNING_KEYSTORE` | 第 2 步生成的 base64 字符串 | 密钥库文件（OpenHarmony.p12） |
| `SIGNING_KEYSTORE_PASSWORD` | `123456` | 密钥库密码 |
| `SIGNING_KEY_ALIAS` | `openharmony application release` | 密钥别名（用于签名 HAP） |
| `SIGNING_KEY_PASSWORD` | `123456` | 密钥密码 |
| `SIGNING_PROFILE_CERT` | `OpenHarmonyApplication.pem` 的内容 | 应用证书文件内容 |
| `SIGNING_PROFILE_KEY` | `OpenHarmonyProfileDebug.pem` 的内容 | 配置证书文件内容 |

### 步骤 3: 验证配置

添加完成后，Secrets 列表应显示：
```
✅ SIGNING_KEYSTORE
✅ SIGNING_KEYSTORE_PASSWORD
✅ SIGNING_KEY_ALIAS
✅ SIGNING_KEY_PASSWORD
✅ SIGNING_PROFILE_CERT
✅ SIGNING_PROFILE_KEY
```

## 安全注意事项

⚠️ **重要**：
- 永远不要将 `.p12`、`.pem` 文件提交到代码库
- 永远不要将密码硬编码到代码或工作流文件中
- 定期检查 Secrets 的访问权限
- 如怀疑密钥泄露，立即在 GitHub 删除并重新生成

## 本地测试签名

配置完 Secrets 后，可以在本地测试签名流程：

```bash
cd security_tool/hapsigner

# 1. 生成 p7b 配置文件
java -jar hap-sign-tool.jar sign-profile \
  -mode "localSign" \
  -keyAlias "OpenHarmony Application Profile Debug" \
  -keyPwd "123456" \
  -inFile "UnsgnsedDebugProfileTemplate.json" \
  -outFile "ohos_provision_debug.p7b" \
  -keystoreFile "OpenHarmony.p12" \
  -keystorePwd "123456" \
  -signAlg "SHA256withECDSA"

# 2. 签名 HAP
java -jar hap-sign-tool.jar sign-app \
  -keyAlias "openharmony application release" \
  -signAlg "SHA256withECDSA" \
  -mode "localSign" \
  -appCertFile "OpenHarmonyApplication.pem" \
  -profileFile "ohos_provision_debug.p7b" \
  -inFile "../entry/build/default/outputs/default/entry-default-unsigned.hap" \
  -keystoreFile "OpenHarmony.p12" \
  -outFile "signApp.hap" \
  -keyPwd "123456" \
  -keystorePwd "123456"
```

## 下一步

配置完 Secrets 后，CI 工作流将自动使用这些密钥进行签名。

参考文档：
- [GitHub Secrets 官方文档](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [AGENTS.md](../AGENTS.md) - 详细签名流程说明

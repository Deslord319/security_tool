# HarmonyOS 应用构建、签名、安装完整指南

本文档提供了在 Windows + WSL 环境下，使用 DevEco Studio 构建 HarmonyOS 应用的完整流程。

## 📋 目录

- [环境要求](#环境要求)
- [环境变量配置](#环境变量配置)
- [构建流程](#构建流程)
- [签名流程](#签名流程)
- [安装与运行](#安装与运行)
- [常见问题](#常见问题)
- [完整脚本示例](#完整脚本示例)

---

## 环境要求

### 必需软件

| 软件 | 版本 | 用途 |
|------|------|------|
| DevEco Studio | >= 4.0 | HarmonyOS 开发 IDE，包含构建工具 |
| Node.js | - | DevEco Studio 内置 |
| HarmonyOS 设备 | - | 真机或模拟器 |
| hdc | - | HarmonyOS 命令行工具 |

### 目录结构

```
project/
├── entry/                    # 应用入口模块
│   ├── src/main/ets/         # ArkTS 源文件
│   └── build/default/outputs/default/
│       └── entry-default-unsigned.hap  # 构建产物
├── hapsigner/                # 签名工具目录
│   ├── hap-sign-tool.jar     # 签名工具
│   ├── OpenHarmony.p12          # 密钥库
│   ├── OpenHarmonyApplication.pem # 应用证书
│   ├── OpenHarmonyProfileDebug.pem # 配置文件
│   ├── ohos_provision_debug.p7b  # 签名描述文件
│   └── signApp.hap             # 签名后的 HAP
```

---

## 环境变量配置

### 1. 查找 DevEco Studio 路径

```bash
# DevEco Studio 默认安装路径
# Windows:
D:\develop\DevEco Studio

# 检查 JBR (Java 运行时）路径
D:\develop\DevEco Studio\jbr
```

### 2. 设置环境变量

#### Windows 命令行

```bash
# 设置 Java 环境
set JAVA_HOME=D:\develop\DevEco Studio\jbr
set DEVECO_SDK_HOME=D:\develop\DevEco Studio

# 添加到 PATH（注意顺序）
set PATH=D:\develop\DevEco Studio\jbr\bin:%PATH%
set PATH=D:\develop\DevEco Studio\tools\hvigor\w.js:%PATH%
set PATH=D:\develop\nodejs:%PATH%
```

#### Git Bash（推荐）

```bash
# 添加到 ~/.bashrc
export JAVA_HOME="/d/develop/DevEco Studio/jbr"
export DEVECO_SDK_HOME="/d/develop/DevEco Studio"
export PATH="$PATH:/d/develop/DevEco Studio/jbr/bin:/d/develop/DevEco Studio/tools/hvigorw.js.d:/d/develop/nodejs:$PATH"

# 使配置生效
source ~/.bashrc
```

### 3. 验证环境

```bash
# 验证 Java
java -version
# 应显示: openjdk version "21.0.8" 2025-07-15

# 验证 Node.js
node --version

# 验证 hvigorw
hvigorw --version
```

---

## 构建流程

### 方法一：使用 hvigorw.js（推荐）

#### 基本命令

```bash
# 进入项目目录
cd /d/project/ai/security_tool

# 设置环境变量
export JAVA_HOME="/d/develop/DevEco Studio/jbr"
export DEVECO_SDK_HOME="/d/develop/DevEco Studio"
export PATH="/d/develop/DevEco Studio/jbr/bin:/d/develop/DevEco Studio/tools/hvigorw.js.d:/d/develop/nodejs:$PATH"

# 执行构建
/d/develop/nodejs/node.exe /d/develop/DevEco Studio/tools/hvigor/bin/hvigorw.js assembleApp
```

#### 参数说明

- `assembleApp`: 打包应用任务
- `--mode module`: 模块模式
- `-p entry`: 指定 entry 模块
- `-m default`: 指定产品类型

#### 构建产物

构建成功后，unsigned HAP 位于：
```
entry/build/default/outputs/default/entry-default-unsigned.hap
```

### 方法二：使用 DevEco Studio IDE

1. 打开 DevEco Studio
2. 打开项目：`D:\project\ai\security_tool`
3. 点击菜单：Build > Build Hap(s)/App(s)
4. 选择签名配置：Debug
5. 点击 Build

---

## 签名流程

### 1. 拷贝 unsigned HAP

```bash
# 拷贝到签名目录
cp entry/build/default/outputs/default/entry-default-unsigned.hap hapsigner/entry-default-unsigned.hap
```

### 2. 签名命令

#### Windows 命令行

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

#### 参数说明

| 参数 | 值 | 说明 |
|------|---|------|
| `-keyAlias` | openharmony application release | 密钥别名 |
| `-signAlg` | SHA256withECDSA | 签名算法 |
| `-mode` | localSign | 本地签名模式 |
| `-appCertFile` | OpenHarmonyApplication.pem | 应用证书 |
| `-profileFile` | ohos_provision_debug.p7b | 配置文件 |
| `-inFile` | entry-default-unsigned.hap | � unsigned 输入文件 |
| `-keystoreFile` | OpenHarmony.p12 | 密钥库文件 |
| `-outFile` | signApp.hap | 输出文件名 |
| `-keyPwd` | 123456 | 密钥密码 |
| `-keystorePwd` | 123456 | 密钥库密码 |

#### 签名产物

签名成功后，HAP 位于：
```
hapsigner/signApp.hap
```

---

## 安装与运行

### 方法一：使用 harmonyos-mcp 工具（推荐）

#### 1. 列出设备

```bash
hdc list targets
```

输出示例：
```
3XB0124805000101
```

#### 2. 安装 HAP

```bash
hdc install hapsigner/signApp.hap
```

#### 3. 运行应用

```bash
# 方式一：使用包名
hdc shell aaa start com.huawei.securitytool

# 方式二：使用 ability 名称
hdc shell aaa start -a EntryAbility -b entry
```

### 方法二：使用 hdc 命令

```bash
# 安装
hdc install hapsigner/signApp.hap

# 运行
hdc shell aaa start com.huawei.securitytool
```

---

## 常见问题

### 问题 1：java 命令找不到

**错误信息**：
```
'java' is not recognized as an internal or external command
```

**解决方案**：
```bash
# 设置完整 PATH
export JAVA_HOME="/d/develop/DevEco Studio/jbr"
export PATH="$JAVA_HOME/bin:$PATH"

# 或使用完整路径
/d/develop/DevEco Studio/jbr/bin/java.exe
```

### 问题 2：DEVECO_SDK_HOME 未设置

**错误信息**：
```
Error Message: Invalid value of 'DEVECO_SDK_HOME' in system environment path.
```

**解决方案**：
```bash
export DEVECO_SDK_HOME="/d/develop/DevEco Studio"
```

### 问题 3：hvigorw.js 找行错误

**错误信息**：
```
Error: Unknown mode 'default' is specified
```

**解决方案**：
- 不需要 `-m default` 参数
- 使用：`hvigorw.js assembleApp`

### 问题 4：签名失败

**错误信息**：
```
Error Message: spawn java ENOENT
```

**解决方案**：
```bash
# 确保 Java 环境变量已设置
export JAVA_HOME="/d/develop/DevEco Studio/jbr"
export DEVECO_SDK_HOME="/d/develop/DevEco Studio"
export PATH="$JAVA_HOME/bin:$PATH"
```

### 问题 5：设备未连接

**错误信息**：
```
hdc: no devices found
```

**解决方案**：
1. 检查 USB 连接
2. 检查 hdc 服务：`hdc start`
3. 重启设备

### 问题 6：安装失败

**错误消息**：
```
[INSTALL_FAILED] install failed
```

**解决方案**：
1. 卸载旧版本：`hdc install -r hapsigner/signApp.hap`
2. 检查设备存储空间
3. 检查应用签名是否匹配

---

## 完整脚本示例

### Windows 批处理脚本

```batch
@echo off
REM ========================================
REM HarmonyOS 应用构建、签名、安装脚本
REM ========================================

set PROJECT_DIR=D:\project\ai\security_tool
set DEV_STUDIO=D:\develop\DevEco Studio
set JAVA_HOME=%DEV_STUDIO%\jbr
set DEVECO_SDK_HOME=%DEV_STUDIO%
set NODEJS=D:\develop\nodejs
set HVIGOR=%DEV_STUDIO%\tools\hvigorw.js

echo.
echo [1/6] 设置环境变量...
echo.

set JAVA_HOME=%JAVA_HOME%
set DEVECO_SDK_HOME=%DEVECO_SDK_HOME%
set PATH=%JAVA_HOME%\bin;%HVIGORWJS%;%NODEJS%

echo.
echo [2/6] 验证环境...
echo.

java -version
if %errorlevel% neq 0 (
    echo [ERROR] Java 未找到或版本不兼容
    exit /b 1
)

echo.
echo [3/6] 清理旧构建产物...
echo.

if exist "%PROJECT_DIR%\entry\build\default\outputs\default\entry-default-unsigned.hap" (
    del "%PROJECT_DIR%\entry\build\default\outputs\default\entry-default-unsigned.hap"
)

echo.
echo [4/6] 开始构建...
echo.

cd /d "%PROJECT_DIR%"
%NODEJS% "%HVIGORWJS%" assembleApp

if %errorlevel% neq 0 (
    echo [ERROR] 构建失败
    exit /b 1
)

echo.
echo [5/6] 拷贝 unsigned HAP...
echo.

if exist "%PROJECT_DIR%\entry\build\default\outputs\default\entry-default-unsigned.hap" (
    copy /Y "%PROJECT_DIR%\entry\build\default\outputs\default\entry-default-unsigned.hap" "%PROJECT_DIR%\hapsigner\entry-default-unsigned.hap"
    echo [SUCCESS] 已拷贝 unsigned HAP
) else (
    echo [ERROR] 未找到 unsigned HAP 文件
    exit /b 1
)

echo.
echo [6/6] 签名 HAP...
echo.

cd "%PROJECT_DIR%\hapsigner"
java -jar hap-sign-tool.jar sign-app ^
  -keyAlias "openharmony application release" ^
  -signAlg "SHA256withECDSA" ^
  -mode "localSign" ^
  -appCertFile "OpenHarmonyApplication.pem" ^
  -profileFile "ohos_provision_debug.p7b" ^
  -inFile "entry-default-unsigned.hap" ^
  -keystoreFile "OpenHarmony.p12" ^
  -outFile "signApp.hap" ^
  -keyPwd "123456" ^
  -keystorePwd "123456"

if %errorlevel% neq 0 (
    echo [ERROR] 签名失败
    exit /b 1
) else (
    echo [SUCCESS] 已签名: signApp.hap
)

echo.
echo [7/6] 检查设备...
echo.

hdc list targets

echo.
echo [8/6] 安装应用...
echo.

hdc install "%PROJECT_DIR%\hapsigner\signApp.hap"

if %errorlevel% neq 0 (
    echo [ERROR] 安装失败
    exit /b 1
) else (
    echo [SUCCESS] 已安装
)

echo.
echo [9/6] 运行应用...
echo.

hdc shell aaa start com.huawei.securitytool

echo.
echo ========================================
echo 所有步骤完成！
echo ========================================
pause
```

### Git Bash 一键脚本

```bash
#!/bin/bash

# ========================================
# HarmonyOS 应用构建、签名、安装脚本
# ========================================

PROJECT_DIR="/d/project/ai/security_tool"
DEV_STUDIO="/d/develop/DevEco Studio"
SIGNER_DIR="$PROJECT_DIR/hapsigner"

# 设置环境变量
export JAVA_HOME="$DEV_STUDIO/jbr"
export DEVECO_SDK_HOME="$DEV_STUDIO"
export PATH="$JAVA_HOME/bin:$DEV_STUDIO/tools/hvigorw.js.d:/d/develop/nodejs:$PATH"

echo "========================================"
echo "[1/6] 设置环境变量..."
echo "========================================"

# 验证环境
echo ""
echo "[2/6] 验证环境..."
echo "========================================"
java -version
node --version

# 清理旧构建产物
echo ""
echo "[3/6] 清理旧构建产物..."
echo "========================================"
rm -f "$PROJECT_DIR/entry/build/default/outputs/default/entry-default-unsigned.hap" 2>/dev/null

# 开始构建
echo ""
echo "[4/6] 开始构建..."
echo "========================================"
cd "$PROJECT_DIR"
/d/develop/nodejs/node.exe "$DEV_STUDIO/tools/hvigor/bin/hvigorw.js" assembleApp

if [ $? -ne 0 ]; then
    echo "[ERROR] 构建失败"
    exit 1
fi

# 拷贝 unsigned HAP
echo ""
echo "[5/6] 拷贝 unsigned HAP..."
echo "========================================"
if [ -f "$PROJECT_DIR/entry/build/default/outputs/default/entry-default-unsigned.hap" ]; then
    cp "$PROJECT_DIR/entry/build/default/outputs/default/entry-default-unsigned.hap" "$SIGNER_DIR/entry-default-unsigned.hap"
    echo "[SUCCESS] 已拷贝 unsigned HAP"
else
    echo "[ERROR] 未找到 unsigned HAP 文件"
    exit 1
fi

# 签名 HAP
echo ""
echo "[6/6] 签名 HAP..."
echo "========================================"
cd "$SIGNER_DIR"
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

if [ $? -ne 0 ]; then
    echo "[ERROR] 签名失败"
    exit 1
else
    echo "[SUCCESS] 已签名: signApp.hap"
fi

# 检查设备
echo ""
echo "[7/6] 检查设备..."
echo "========================================"
hdc list targets

# 安装应用
echo ""
echo "[8/6] 安装应用..."
echo "========================================"
hdc install "$SIGNER_DIR/signApp.hap"

if [ $? -ne 0 ]; then
    echo "[ERROR] 安装失败"
    exit 1
else
    echo "[SUCCESS] 已安装"
fi

# 运行应用
echo ""
echo "[9/6] 运行应用..."
echo "========================================"
hdc shell aaa start com.huawei.securitytool

echo ""
echo "========================================"
echo "所有步骤完成！"
echo "========================================"
```

---

## 使用 harmonyos-mcp 工具

如果你已配置了 harmonyos-mcp MCP 服务器，可以使用以下工具：

### 1. 构建应用

```typescript
// 在 OpenCode 中使用
harmonyos_build_app({
  project_path: "D:\\project\\ai\\security_tool",
  build_mode: "debug"
})
```

### 2. 安装应用

```typescript
harmonyos_install_app({
  hap_path: "D:\\project\\ai\\security_tool\\hapsigner\\signApp.hap",
  device_id: "your_device_id"
})
```

### 3. 运行应用

```typescript
harmonyos_run_app({
  bundle_name: "com.huawei.securitytool",
  device_id: "your_device_id"
})
```

### 4. 截图

```typescript
harmonyos_screenshot({
  device_id: "your_device_id",
  local_path: "D:\\project\\ai\\security_tool\\screenshots\\screenshot.png"
})
```

---

## 快速参考

### 仅构建

```bash
export JAVA_HOME="/d/develop/DevEco Studio/jbr"
export DEVECO_SDK_HOME="/d/develop/DevEco Studio"
export PATH="/d/develop/DevEco Studio/jbr/bin:/d/develop/DevEco Studio/tools/hvigorw.js.d:/d/develop/nodejs:$PATH"
cd /d/project/ai/security_tool && /d/develop/nodejs/node.exe /d/develop/DevEco Studio/tools/hvigor/bin/hvigorw.js assembleApp
```

### 仅签名

```bash
cd /d/project/ai/security_tool/hapsigner
java -jar hap-sign-tool.jar sign-app -keyAlias "openharmony application release" -signAlg "SHA256withECDSA" -mode "localSign" -appCertFile "OpenHarmonyApplication.pem" -profileFile "ohos_provision_debug.p7b" -inFile "entry-default-unsigned.hap" -keystoreFile "OpenHarmony.p12" -outFile "signApp.hap" -keyPwd "123456" -keystorePwd "123456"
```

### 仅安装运行

```bash
hdc install /d/project/ai/security_tool/hapsigner/signApp.hap
hdc shell aaa start com.huawei.securitytool
```

---

## 版本号管理

当前应用版本信息位于：
```
entry/src/main/ets/constants/AppConstants.ets

export class AppInfo {
  static readonly APP_NAME: string = '安全管理中心'
  static readonly APP_VERSION: string = 'v14'
  static readonly BUNDLE_NAME: string = 'com.huawei.securitytool'
}
```

更新版本号时，需要同步修改：
1. `AppInfo.APP_VERSION`
2. Git tag（推荐使用 commit hash）

---

## 相关文档

- [HarmonyOS 官方开发文档](https://developer.harmonyos.com/cn/docs/)
- [DevEco Studio 用户指南](https://developer.harmonyos.com/cn/docs/ide/)
- [签名工具文档](https://developer.harmonyos.com/cn/docs/signing/guide-hap-sign-tool-overview.md)

---

## 联系方式

- [HarmonyOS 官方社区](https://developer.harmonyos.com/cn/)
- [DevEco Studio 支持](https://developer.harmonyos.com/cn/ide/issue)
- [AI 编码助手社区](https://opencode.ai/docs/)

---

**文档版本**：v1.0
**最后更新**：2025-02-27
**适用环境**：Windows + DevEco Studio + WSL


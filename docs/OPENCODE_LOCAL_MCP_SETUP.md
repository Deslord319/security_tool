# OpenCode HarmonyOS MCP 本地配置指南

本文档指导你如何在 OpenCode 中配置和使用本地安装的 HarmonyOS MCP Server。

---

## 📋 前提条件

- ✅ 已安装 HarmonyOS MCP whl 包
- ✅ 已安装 Python（推荐 3.8+）
- ✅ 已安装 DevEco Studio（包含 HDC 工具）
- ✅ OpenCode 已安装

---

## 🔧 配置步骤

### 步骤 1: 确认 MCP 已安装

```bash
# 检查 MCP 包是否已安装
pip show mcp-ho-dev

# 或
pip list | grep mcp
```

**预期输出**:
```
Name: mcp-ho-dev
Version: 0.1.0
Location: C:\Users\mu\AppData\Local\Programs\Python\Python311\Lib\site-packages
```

---

### 步骤 2: 找到 MCP 启动命令

```bash
# 查看 MCP 包的入口点
python -m mcp_ho_dev --help

# 或查找可执行文件
where mcp-ho-dev
```

**常见启动方式**:
```bash
# 方式 1: 使用 python -m
python -m mcp_ho_dev

# 方式 2: 使用可执行文件
mcp-ho-dev

# 方式 3: 直接运行脚本
python C:\path\to\mcp_ho_dev\main.py
```

---

### 步骤 3: 创建 OpenCode MCP 配置文件

**Windows 配置文件路径**:
```
%APPDATA%\OpenCode\mcp-servers.json
```

或
```
C:\Users\mu\AppData\Roaming\OpenCode\mcp-servers.json
```

**创建配置文件**:

```json
{
  "mcpServers": {
    "harmonyos": {
      "command": "python",
      "args": ["-m", "mcp_ho_dev"],
      "cwd": "C:\\Users\\mu\\Desktop\\code\\security_tool",
      "env": {
        "HDC_PATH": "C:\\Huawei\\Sdk\\toolchains\\hdc.exe",
        "PROJECT_PATH": "C:\\Users\\mu\\Desktop\\code\\security_tool",
        "PYTHONPATH": "C:\\Users\\mu\\AppData\\Local\\Programs\\Python\\Python311\\Lib\\site-packages"
      },
      "disabled": false,
      "autoApprove": [
        "build_app",
        "install_app", 
        "run_app",
        "list_devices"
      ]
    }
  }
}
```

---

### 步骤 4: 验证 Python 路径

```bash
# 查看 Python 路径
where python

# 查看 Python 版本
python --version

# 查看已安装的包
pip list | findstr mcp
```

**更新配置中的 Python 路径**:

如果 `where python` 返回的路径不是 `python`，使用完整路径：

```json
{
  "mcpServers": {
    "harmonyos": {
      "command": "C:\\Users\\mu\\AppData\\Local\\Programs\\Python\\Python311\\python.exe",
      "args": ["-m", "mcp_ho_dev"],
      ...
    }
  }
}
```

---

### 步骤 5: 重启 OpenCode

保存配置文件后，完全退出并重新启动 OpenCode。

---

## 🚀 测试连接

### 在 OpenCode 中测试

1. **打开 OpenCode**

2. **发送测试消息**:
   ```
   列出当前连接的设备
   ```

3. **或使用 MCP 工具**:
   ```
   使用 harmonyos MCP 列出设备
   ```

---

## 🔍 故障排查

### 问题 1: MCP Server 未启动

**症状**: OpenCode 无法连接到 MCP

**解决方案**:
```bash
# 手动测试 MCP Server
python -m mcp_ho_dev

# 查看是否有错误输出
```

**检查配置文件**:
```json
{
  "command": "python",  // 确保 Python 路径正确
  "args": ["-m", "mcp_ho_dev"],  // 确保模块名正确
  "cwd": "..."  // 确保工作目录存在
}
```

---

### 问题 2: 找不到 HDC 工具

**症状**: `Error: hdc not found`

**解决方案**:
1. 在配置中添加 HDC_PATH:
   ```json
   "env": {
     "HDC_PATH": "C:\\Huawei\\Sdk\\toolchains\\hdc.exe"
   }
   ```

2. 或将 HDC 添加到系统 PATH

---

### 问题 3: MCP 包未找到

**症状**: `ModuleNotFoundError: No module named 'mcp_ho_dev'`

**解决方案**:
```bash
# 重新安装 MCP 包
pip install path/to/mcp_ho_dev-0.1.0-py3-none-any.whl

# 验证安装
python -c "import mcp_ho_dev; print('OK')"
```

---

### 问题 4: OpenCode 不识别 MCP

**症状**: MCP 工具不可用

**解决方案**:
1. 检查配置文件语法（JSON 格式）
2. 确认配置文件路径正确
3. 重启 OpenCode
4. 查看 OpenCode 日志

**查看 OpenCode 日志**:
```
%APPDATA%\OpenCode\logs\
```

---

## 📝 完整配置示例

### 配置文件：`%APPDATA%\OpenCode\mcp-servers.json`

```json
{
  "mcpServers": {
    "harmonyos": {
      "command": "C:\\Users\\mu\\AppData\\Local\\Programs\\Python\\Python311\\python.exe",
      "args": [
        "-m",
        "mcp_ho_dev",
        "--project",
        "C:\\Users\\mu\\Desktop\\code\\security_tool"
      ],
      "cwd": "C:\\Users\\mu\\Desktop\\code\\security_tool",
      "env": {
        "HDC_PATH": "C:\\Huawei\\Sdk\\toolchains\\hdc.exe",
        "PROJECT_PATH": "C:\\Users\\mu\\Desktop\\code\\security_tool",
        "PYTHONPATH": "C:\\Users\\mu\\AppData\\Local\\Programs\\Python\\Python311\\Lib\\site-packages",
        "PYTHONUNBUFFERED": "1"
      },
      "disabled": false,
      "autoApprove": [
        "build_app",
        "install_app",
        "run_app",
        "list_devices",
        "get_logs"
      ],
      "timeout": 300
    }
  },
  "version": "1.0.0"
}
```

---

## 🛠️ 使用方法

### 在 OpenCode 中调用 MCP 工具

#### 1. 列出设备

```
请列出当前连接的 HarmonyOS 设备
```

**预期返回**:
```
已连接到以下设备:
- 3XB0124805000101 (USB, online)
```

---

#### 2. 构建应用

```
构建 security_tool 项目
```

**预期返回**:
```
✅ 构建成功
输出路径：entry/build/default/outputs/default/entry-default-unsigned.hap
构建时间：2.3s
```

---

#### 3. 安装应用

```
安装应用到设备
```

**预期返回**:
```
✅ 安装成功
设备：3XB0124805000101
安装时间：3.5s
```

---

#### 4. 运行应用

```
启动 HarmonyShield 应用
```

**预期返回**:
```
✅ 应用已启动
包名：com.huawei.securitytool
```

---

## 🔧 高级配置

### 添加多个 MCP Server

```json
{
  "mcpServers": {
    "harmonyos-debug": {
      "command": "python",
      "args": ["-m", "mcp_ho_dev", "--debug"],
      "env": {
        "LOG_LEVEL": "debug"
      }
    },
    "harmonyos-release": {
      "command": "python",
      "args": ["-m", "mcp_ho_dev", "--release"],
      "env": {
        "LOG_LEVEL": "info"
      }
    }
  }
}
```

---

### 配置自动批准

避免每次调用都确认：

```json
{
  "mcpServers": {
    "harmonyos": {
      "autoApprove": [
        "build_app",
        "install_app",
        "run_app",
        "list_devices",
        "get_logs",
        "uninstall_app"
      ]
    }
  }
}
```

---

### 配置超时

```json
{
  "mcpServers": {
    "harmonyos": {
      "timeout": 300,
      "startupTimeout": 30
    }
  }
}
```

---

## 📖 相关资源

- [OpenCode MCP 文档](https://github.com/OpenCodeDev/mcp-docs)
- [HarmonyOS MCP 项目](https://github.com/Deslord319/mcp_ho_dev)
- [DevEco Studio 下载](https://developer.huawei.com/consumer/cn/deveco-studio/)

---

## ✅ 验证清单

配置完成后，检查以下项目：

- [ ] MCP whl 包已安装
- [ ] Python 可以导入 mcp_ho_dev
- [ ] 配置文件已创建
- [ ] 配置文件路径正确
- [ ] Python 路径正确
- [ ] 项目路径正确
- [ ] HDC 路径正确
- [ ] OpenCode 已重启
- [ ] MCP 工具可用

---

*最后更新：2026-03-09*

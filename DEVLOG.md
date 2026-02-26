# HarmonyShield 开发日志

本文件记录 Qoder AI 辅助开发过程中的版本迭代、踩坑经验和优化内容。

---

## 版本记录

### v13 - 2026-02-26

**功能更新：**
- 启动认证功能：EntryAbility 集成启动校验，支持 PIN/指纹/人脸认证拦截
- AuthService 增强：新增 `checkAuthMethodAvailability` 可用性检查、`getAuthMethodLabel` 标签获取
- 认证流程优化：challenge 生成改为 8 字节随机数，错误日志改用 BusinessError 类型
- ToolSettingsPage 保存逻辑重构：增加变更检测、认证可用性前置检查、密码验证前置
- 重置默认增加确认弹窗、测试认证增加可用性前置检查
- 新增 `ACCESS_BIOMETRIC` 权限用于生物认证
- 提取 `PREF_STORE_NAME_TOOL` 常量，消除 Preferences store name 硬编码
- 新增测试框架：仪表测试（ohosTest）和单元测试（test）目录结构
- 新增签名测试包 signTestApp.hap
- 新增文档：测试架构、测试设计、测试实施、测试报告、日志管理架构

**文件变更：**
- `entryability/EntryAbility.ets`: 新增启动认证检查和认证执行逻辑
- `services/AuthService.ets`: 新增可用性检查、标签获取、challenge 优化
- `views/ToolSettingsPage.ets`: 保存逻辑重构、变更检测、确认弹窗
- `models/DataModels.ets`: 新增 `PREF_STORE_NAME_TOOL` 常量
- `module.json5`: 新增 `ACCESS_BIOMETRIC` 权限
- `hapsigner/UnsgnedDebugProfileTemplate.json`: 签名模板新增权限
- 测试目录：新增 common/dashboard/firewall/navigation/peripheral 测试模块

**踩坑记录：**
- userAuth challenge 必须至少 8 字节，传入 `new Uint8Array([0])` 会导致认证失败
- `widgetParam.navigationButtonText` 属性在某些设备上不支持，移除后认证弹窗更稳定
- Preferences store name 硬编码在多处使用会导致 EntryAbility 和 ToolSettingsPage 读写不同 store，必须提取为常量
- 认证结果 `result.result` 的值 12500000 对应 `UserAuthResultCode.SUCCESS`，不要直接用 0 判断

---

### v11 - 2026-02-25

**功能更新：**
- 新增工具设置页面（ToolSettingsPage）：启动认证开关、认证方式选择、密码修改
- 新增 AuthService 服务：封装 userAuth 和 Asset Store Kit 认证逻辑
- 新增 SecureStorageService 服务：敏感数据安全存储
- 主题系统扩展：新增 Teal 色系标签配色（深色/浅色模式）
- 数据模型扩展：新增工具设置相关枚举、接口和常量
- README 重构：加入项目介绍、工具包位置、项目优势和快速入门指南
- 添加应用截图到 docs/images/

**文件变更：**
- `views/ToolSettingsPage.ets`: 新增工具设置页面
- `services/AuthService.ets`: 新增认证服务
- `services/SecureStorageService.ets`: 新增安全存储服务
- `pages/MainPage.ets`: 路由集成 ToolSettingsPage 替换 PlaceholderPage
- `models/DataModels.ets`: 新增 AuthMethod 枚举、ToolSettingsConfig 接口等
- `theme/ThemeColors.ets`: 新增 TAG_TEAL_BG/TAG_TEAL_TEXT 颜色
- `README.md`: 重写项目文档

**踩坑记录：**
- 工具设置页面需要同时依赖 userAuth 和 Asset Store Kit，注意两者的权限声明不能遗漏
- ThemeColorSet 接口新增字段后，深色和浅色两套配置必须同步更新，否则编译报错

---

### v10 - 2026-02-13

**功能更新：**
- 隐藏系统标题栏（窗口装饰栏），实现自定义 Title Bar
- 外设管理模块重构：设备管控数据从 MDM API 实时加载
- 设备管控策略变更支持实际调用 MDM Kit 接口
- 添加 USB/蓝牙设备 ID 解析工具函数

**文件变更：**
- `EntryAbility.ets`: 调用 `setWindowDecorVisible(false)` 隐藏系统装饰栏
- `MainPage.ets`: 调整 padding 避免与系统三键区冲突
- `PeripheralPage.ets`: 重构设备管控逻辑，接入真实 MDM API
- `DataModels.ets`: 新增 `parseUsbDeviceId`、`formatUsbDeviceId`、`parseBluetoothMac` 等工具函数

---

### v9 - 2026-02-12

**功能更新：**
- 实现深色模式主题系统
- 身份鉴别模块开发

---

### v8 - 2026-02-11

**功能更新：**
- 优化多页面 UI 布局及弹窗样式
- 修复 Scroll 组件顶部空白问题

---

### v7 - 2026-02-10

**功能更新：**
- 实现外设管理模块（接口管控、白名单、黑名单）

---

### v6 - 2026-02-09

**功能更新：**
- 添加 UX 设计原型和 README UX 文档

---

### v5 - 初始版本

**功能更新：**
- 初始化项目结构
- 实现安全管理中心完整功能（总览+防火墙模块）
- 添加签名工具、README 和 AGENTS.md

---

## 踩坑经验与优化记录

### 1. 窗口装饰栏隐藏问题

**问题描述：**
HarmonyOS 2in1 设备默认显示系统标题栏（窗口装饰栏），导致应用无法实现自定义 Title Bar。

**解决方案：**
```typescript
windowStage.getMainWindow().then((mainWindow: window.Window) => {
  mainWindow.setWindowDecorVisible(false);
  mainWindow.setWindowDecorHeight(56);
});
```

**注意事项：**
- `setWindowDecorVisible(false)` 隐藏装饰栏但保留三键区（最小化/最大化/关闭）和窗口拖拽能力
- `setWindowDecorHeight(56)` 设置装饰栏高度，确保三键区可见
- 需要调整页面 padding 避免内容与三键区重叠（右侧预留约 140px）

---

### 2. USB 设备 ID 解析

**问题描述：**
设备管控记录中的 `deviceId` 格式为 `"VID:XXXX PID:XXXX"`，需要解析为 MDM Kit 所需的 `vendorId` 和 `productId`。

**解决方案：**
```typescript
function parseUsbDeviceId(deviceId: string): ParsedUsbId | null {
  let match = deviceId.match(/VID:\s*([0-9A-Fa-f]{4})\s+PID:\s*([0-9A-Fa-f]{4})/i)
  if (!match) return null
  return {
    vendorId: parseInt(match[1], 16),
    productId: parseInt(match[2], 16)
  }
}
```

---

### 3. 签名配置一致性

**问题描述：**
修改权限或包名后安装失败。

**根因：**
三处配置不一致：
- `AppScope/app.json5` 的 `bundleName`
- `entry/src/main/module.json5` 的 `requestPermissions`
- `hapsigner/UnsgnedDebugProfileTemplate.json` 的 `bundle-name`、`acls`、`permissions`

**解决方案：**
1. 确保三处配置一致
2. 修改 `UnsgnedDebugProfileTemplate.json` 后必须重新生成 p7b
3. 执行签名流程：`1-debug-p7b.bat` → `2-debug-sign.bat`

---

### 4. 入口页面路径问题

**问题描述：**
应用启动后页面空白。

**根因：**
`EntryAbility.ets` 中 `windowStage.loadContent` 的路径参数错误。

**解决方案：**
```typescript
windowStage.loadContent('pages/MainPage', ...)
```
注意：路径不带前缀斜杠，且必须与 `entry/src/main/ets/pages/` 目录下的文件对应。

---

### 5. Scroll 组件顶部空白

**问题描述：**
使用 Scroll 组件时，内容区顶部出现意外空白。

**解决方案：**
检查 Scroll 内部 Column/Row 的 `padding` 和 `margin` 设置，确保没有重复声明。

---

### 6. 弹窗样式问题

**问题描述：**
自定义弹窗（CustomDialog）在深色模式下背景颜色不正确。

**解决方案：**
在 CustomDialog 的根 Column 中显式设置背景色：
```typescript
Column() { ... }
.backgroundColor(AppColors.getColors(this.currentTheme).BG_SECONDARY)
```

---

### 7. MDM Kit USB/蓝牙 API 调用

**问题描述：**
调用 `usbManager.addAllowedUsbDevices` 等 API 时返回失败。

**可能原因：**
1. 缺少对应权限声明
2. 签名配置中未包含 ACL
3. 设备未激活 MDM 模式

**排查步骤：**
1. 检查 `module.json5` 权限声明
2. 检查 `UnsgnedDebugProfileTemplate.json` 的 `acls.allowed-acls`
3. 确认设备是否支持 MDM 功能（仅企业版设备支持）

---

## 开发规范

### Commit 规范

- 使用中文描述
- 包含版本号（如 v10、v11）
- 格式：`v{版本号}: {类型}: {描述}`
- 类型：`feat`(新功能)、`fix`(修复)、`refactor`(重构)、`docs`(文档)、`style`(样式)

示例：
```
v10: feat: 隐藏系统标题栏并重构外设管理模块
```

### 构建流程

1. 修改代码
2. 构建 HAP：`build_hap.bat` 或 DevEco Studio
3. 签名：`hapsigner/2-debug-sign.bat`
4. 安装：`hdc install hapsigner/signApp.hap`

---

*最后更新：2026-02-26*

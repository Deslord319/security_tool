# CI/CD 状态说明

## ⚠️ 重要提示

**当前 GitHub Actions CI 仅用于代码质量检查，无法执行实际构建和测试。**

---

## 为什么 CI 无法运行构建？

### 技术限制

HarmonyOS 应用构建需要以下组件，这些在 GitHub Actions 中**不可用**：

1. **HarmonyOS SDK** 
   - 官方 SDK 仅支持 Windows/macOS
   - 没有官方 Linux 版本
   - 社区 Action (`harmonyos-dev/setup-harmonyos-sdk`) 不稳定且功能有限

2. **DevEco Studio**
   - 官方 IDE，仅支持 Windows/macOS
   - 无命令行构建工具独立分发

3. **hvigorw (构建包装脚本)**
   - 项目缺少 hvigorw 包装脚本
   - 需要 DevEco Studio 生成

4. **测试运行器**
   - 需要 HarmonyOS 模拟器或真机
   - GitHub Actions 无法运行模拟器

---

## 当前 CI 能做什么？

### ✅ 可用功能

| 功能 | 状态 | 说明 |
|------|------|------|
| 代码检出 | ✅ | 从 GitHub 拉取代码 |
| 环境检查 | ✅ | 验证 Node.js、Java 版本 |
| 文档生成 | ✅ | 可以生成文档 |
| 代码扫描 | ✅ | 可以运行静态分析 |
| 签名（有 Secrets） | ⚠️ | 如果有预签名 HAP，可以上传 |

### ❌ 不可用功能

| 功能 | 原因 | 替代方案 |
|------|------|---------|
| HAP 构建 | 缺少 HarmonyOS SDK | 本地构建 |
| 单元测试 | 需要 SDK 和模拟器 | 本地测试 |
| UI 测试 | 需要模拟器 | 本地测试 |
| 自动签名 | 需要 SDK 工具链 | 本地签名 |
| 设备部署 | 无法连接设备 | 本地部署 |

---

## 推荐的开发流程

### 本地开发 → 推送到 GitHub

```bash
# 1. 本地构建和测试
hvigorw assembleHap --mode module -p product=default -p module=entry

# 2. 本地签名
cd hapsigner
copy ..\entry\build\default\outputs\default\entry-default-unsigned.hap .
.\2-debug-sign.bat

# 3. 本地测试
hdc install signApp.hap

# 4. 确认无误后推送
git add .
git commit -m "feat: 新功能"
git push origin master
```

### GitHub 作用

- ✅ 代码备份
- ✅ 版本管理
- ✅ Issue 追踪
- ✅ Release 发布
- ⚠️ CI 状态检查（非功能性）

---

## 企业级 CI/CD 建议

### 方案 1: 华为云 DevCloud（推荐）

**优点**：
- ✅ 官方支持 HarmonyOS
- ✅ 完整构建和测试能力
- ✅ 真机云测服务
- ✅ 企业级安全

**配置**：
1. 注册华为云 DevCloud
2. 创建 HarmonyOS 构建流水线
3. 配置代码源（GitHub）
4. 设置自动化触发

### 方案 2: 本地 Jenkins + 真机

**优点**：
- ✅ 完全控制
- ✅ 可使用真机测试
- ✅ 数据不出内网

**配置**：
1. 部署 Jenkins 服务器（Windows）
2. 安装 DevEco Studio
3. 连接测试设备
4. 配置 Jenkins Pipeline

### 方案 3: GitHub Actions + 自托管 Runner

**优点**：
- ✅ 使用 GitHub 界面
- ✅ 完整构建能力

**配置**：
1. 准备 Windows 服务器
2. 安装 DevEco Studio
3. 配置 GitHub Actions Runner
4. 设置自托管 Runner 标签

---

## 当前 CI 配置说明

### 构建 Job（跳过）

```yaml
- name: Build unsigned HAP (skip if no SDK)
  run: |
    echo "⚠️ Build skipped - HarmonyOS SDK not available"
    exit 0
```

**说明**: 由于缺少 SDK，构建步骤被跳过，仅创建占位文件。

### 测试 Job（跳过）

```yaml
- name: Run component tests (skip)
  run: |
    echo "⚠️ Tests skipped - requires HarmonyOS SDK"
    exit 0
```

**说明**: 测试需要 SDK 和模拟器，在 GitHub Actions 中不可用。

### 签名 Job（条件执行）

```yaml
- name: Check for signing secrets
  run: |
    if [ -n "${{ secrets.SIGNING_KEYSTORE }}" ]; then
      echo "✅ Signing secrets configured"
    else
      echo "⚠️ No signing secrets - using pre-signed HAP"
    fi
```

**说明**: 如果配置了 Secrets，可以尝试签名；否则使用预签名 HAP。

---

## 质量保证建议

### 在本地确保代码质量

```bash
# 1. 构建验证
hvigorw assembleHap --mode module -p product=default -p module=entry

# 2. 运行所有测试
hvigorw :entry:test

# 3. 代码检查
# DevEco Studio → Code → Inspect Code

# 4. 确认测试覆盖率
# 查看 entry/.test/default/outputs/ohosTest/reports/

# 5. 手动测试
hdc install signApp.hap
# 在设备上验证所有功能
```

### 推送前检查清单

- [ ] 本地构建成功
- [ ] 所有测试通过
- [ ] 代码覆盖率 > 80%
- [ ] 手动验证核心功能
- [ ] 更新版本号（如需要）
- [ ] 更新 DEVLOG.md
- [ ] Commit 信息规范

---

## 未来改进计划

### 短期（1-2 个月）

1. **添加 hvigorw 包装脚本**
   - 通过 DevEco Studio 生成
   - 提交到 Git

2. **完善本地测试文档**
   - 测试执行指南
   - 测试报告解读

3. **添加代码扫描**
   - ESLint 配置
   - TypeScript 检查

### 中期（3-6 个月）

1. **评估华为云 DevCloud**
   - 成本分析
   - 功能验证

2. **搭建自托管 Runner**
   - Windows 服务器
   - 自动化部署

### 长期（6 个月+）

1. **完整 CI/CD 流水线**
   - 自动化构建
   - 自动化测试
   - 自动化发布

2. **质量门禁**
   - 覆盖率要求
   - 性能基准
   - 安全扫描

---

## 相关资源

- [华为云 DevCloud](https://www.huaweicloud.com/product/devcloud.html)
- [HarmonyOS 开发者社区](https://developer.huawei.com/consumer/cn/forum/)
- [DevEco Studio 下载](https://developer.huawei.com/consumer/cn/deveco-studio/)
- [GitHub Actions 文档](https://docs.github.com/en/actions)

---

## 联系与支持

如有问题，请：
1. 查看 [AGENTS.md](../AGENTS.md) 开发指南
2. 查看 [DEVLOG.md](../DEVLOG.md) 版本记录
3. 提交 Issue 到 GitHub

---

*最后更新：2026-03-09*

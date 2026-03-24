# PeripheralPage MVVM 重构指南

## 当前状态

### 已完成
1. ✅ 创建了 `PeripheralViewModel.ets`（148 行）
   - 包含所有状态属性（usbDisabled, btDisabled 等）
   - 包含数据加载方法（reloadInterfaceState, reloadWhitelistBlacklist, reloadDeviceRecords）
   - 包含业务方法（toggleInterface, setUsbStoragePolicy）
2. ✅ PeripheralPage 导入了 ViewModel
3. ✅ PeripheralPage 实例化了 ViewModel
4. ✅ aboutToAppear 调用了 viewModel.initialize()
5. ✅ aboutToDisappear 调用了 viewModel.destroy()
6. ✅ 创建了 15+ 测试用例
7. ✅ 编译成功，安装成功

### 未完成
- ❌ PeripheralPage 中的业务逻辑未迁移到 ViewModel
- ❌ PeripheralPage 仍为 2368 行
- ❌ ViewModel 的方法未被实际调用

## 后续工作（按优先级）

### Phase 1: 核心业务逻辑迁移（2-4 小时）

**目标**：将接口管控逻辑迁移到 ViewModel

**步骤**：
1. 在 ViewModel 中添加 `ensureAdminReady()` 方法
2. 在 ViewModel 中添加 `showOperationFailure()` 方法（或简化为 errorMessage）
3. 修改 PeripheralPage 的 `handleInterfaceToggle()` 方法，委托给 ViewModel：
   ```typescript
   async handleInterfaceToggle(feature: string, disallow: boolean): Promise<void> {
     const success = await this.viewModel.toggleInterface(feature, disallow)
     if (!success) {
       this.showResultDialog('failure', this.viewModel.errorMessage || '操作失败')
     }
   }
   ```
4. 修改 `handleUsbStoragePolicyChange()` 方法，委托给 ViewModel
5. 编译验证
6. 手动测试接口管控功能

**预期结果**：
- PeripheralPage: ~2300 行（减少 68 行）
- PeripheralViewModel: ~200 行（增加 52 行）

### Phase 2: 黑白名单逻辑迁移（4-6 小时）

**目标**：将黑白名单操作迁移到 ViewModel

**步骤**：
1. 在 ViewModel 中添加以下方法：
   - `addToUsbWhitelist(vendorId, productId)`
   - `removeFromUsbWhitelist(device)`
   - `addToBluetoothWhitelist(mac)`
   - `removeFromBluetoothWhitelist(mac)`
   - `addToUsbBlacklist(baseClass, subClass, protocol)`
   - `removeFromUsbBlacklist(deviceType)`
2. 更新 PeripheralPage 中的处理方法，委托给 ViewModel
3. 迁移数据刷新逻辑
4. 编译验证
5. 手动测试黑白名单功能

**预期结果**：
- PeripheralPage: ~2100 行（减少 200 行）
- PeripheralViewModel: ~350 行（增加 150 行）

### Phase 3: 状态同步（4-6 小时）

**目标**：将 Page 中的@State 变量同步到 ViewModel

**步骤**：
1. 在 ViewModel 中使用 `@Observed` 装饰器（如果需要响应式）
2. 修改 PeripheralPage，从 ViewModel 读取状态而不是本地@State
3. 移除 Page 中已迁移的状态变量
4. 更新所有状态引用
5. 编译验证
6. 手动测试状态同步

**预期结果**：
- PeripheralPage: ~1800 行（减少 300 行）
- PeripheralViewModel: ~450 行（增加 100 行）

### Phase 4: 辅助方法迁移（4-6 小时）

**目标**：将所有辅助方法迁移到 ViewModel

**步骤**：
1. 迁移以下方法到 ViewModel：
   - `buildUsbDisplayName()`
   - `getUsbWhitelistCandidates()`
   - `getBluetoothWhitelistCandidates()`
   - `getUsbBlacklistTemplates()`
   - `ensureAdminReady()`
   - 所有 `reload*` 方法
2. 更新 Page 中的引用
3. 移除重复代码
4. 编译验证

**预期结果**：
- PeripheralPage: ~1500 行（减少 300 行）
- PeripheralViewModel: ~700 行（增加 250 行）

### Phase 5: 清理和优化（4-6 小时）

**目标**：将 PeripheralPage 简化到<500 行

**步骤**：
1. 移除所有已迁移的方法
2. 移除所有已迁移的状态变量
3. 只保留 UI 相关的@Builder 方法
4. 只保留纯 UI 逻辑
5. 优化代码结构
6. 添加文档注释
7. 编译验证
8. 完整功能测试

**预期结果**：
- PeripheralPage: **~450-480 行** ✅
- PeripheralViewModel: **~1200 行** ✅

## 迁移原则

### 什么应该留在 Page 中
- UI 组件声明（@Builder 方法）
- 纯 UI 逻辑（颜色、样式、布局）
- 对话框控制器
- 手势处理
- Tab 切换逻辑

### 什么应该迁移到 ViewModel
- 所有业务逻辑
- 所有状态管理
- 所有数据加载
- 所有服务调用
- 所有数据处理和转换

## 测试要求

### 单元测试（ViewModel）
- 所有状态属性有默认值测试
- 所有数据加载方法有成功/失败测试
- 所有业务方法有集成测试
- 所有辅助方法有输入/输出验证测试
- **最低 85% 代码覆盖率**

### 集成测试（Page + ViewModel）
- ViewModel 初始化触发数据加载
- 事件处理程序正确更新 UI 状态
- 对话框流程端到端工作
- 导出操作成功完成
- 状态变化传播到 UI

### 功能验证
- 所有现有功能正常工作
- UI 行为无回归
- 加载状态正确显示
- 错误消息适当显示
- Tab 导航工作
- 对话框交互正常
- 导出操作成功

## 验证清单

- [ ] PeripheralPage.ets ≤ 500 行
- [ ] 所有业务逻辑在 PeripheralViewModel 中
- [ ] 零功能回归
- [ ] ≥85% 测试覆盖率
- [ ] 清晰的关注点分离
- [ ] 改进的代码可维护性
- [ ] 更好的可测试性

## 当前进度

| Phase | 状态 | 预计工时 | 实际工时 |
|-------|------|----------|----------|
| Phase 0: 创建 ViewModel | ✅ 完成 | 1h | 1h |
| Phase 1: 核心业务逻辑迁移 | ❌ 未开始 | 2-4h | 0h |
| Phase 2: 黑白名单逻辑迁移 | ❌ 未开始 | 4-6h | 0h |
| Phase 3: 状态同步 | ❌ 未开始 | 4-6h | 0h |
| Phase 4: 辅助方法迁移 | ❌ 未开始 | 4-6h | 0h |
| Phase 5: 清理和优化 | ❌ 未开始 | 4-6h | 0h |
| **总计** | **~17% 完成** | **18-24h** | **1h** |

## 下一步

**立即执行**：Phase 1 - 核心业务逻辑迁移

1. 修改 `handleInterfaceToggle()` 委托给 ViewModel
2. 修改 `handleUsbStoragePolicyChange()` 委托给 ViewModel
3. 编译验证
4. 手动测试

**预计完成时间**：2-4 小时

---

**文档状态**：草稿  
**最后更新**：2026-03-24  
**维护者**：AI Agent (Sisyphus)

/**
 * InterfaceControlViewModel 单元测试
 */
import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { InterfaceControlViewModel } from '../../viewmodels/peripheral/InterfaceControlViewModel'
import { usbManager } from '@kit.MDMKit'

describe('InterfaceControlViewModel', () => {
  let viewModel: InterfaceControlViewModel
  beforeEach(() => { viewModel = new InterfaceControlViewModel() })

  describe('状态初始化', () => {
    it('应初始化所有接口状态为 false', 0, () => { expect(viewModel.usbDisabled).assertFalse(); expect(viewModel.btDisabled).assertFalse() })
    it('应初始化 USB 存储策略索引为 0', 0, () => { expect(viewModel.usbStoragePolicyIndex).assertEqual(0) })
    it('应初始化同步令牌为 0', 0, () => { expect(viewModel.syncToken).assertEqual(0) })
    it('应初始化加载状态为 false', 0, () => { expect(viewModel.isLoading).assertFalse() })
  })

  describe('mapUsbStoragePolicyToIndex', () => {
    it('应将 READ_ONLY 映射为索引 0', 0, () => { expect(viewModel.mapUsbStoragePolicyToIndex(usbManager.UsbPolicy.READ_ONLY)).assertEqual(0) })
    it('应将 READ_WRITE 映射为索引 1', 0, () => { expect(viewModel.mapUsbStoragePolicyToIndex(usbManager.UsbPolicy.READ_WRITE)).assertEqual(1) })
    it('应将 DENY 映射为索引 2', 0, () => { expect(viewModel.mapUsbStoragePolicyToIndex(usbManager.UsbPolicy.DENY)).assertEqual(2) })
  })

  describe('mapIndexToUsbStoragePolicy', () => {
    it('应将索引 0 映射为 READ_ONLY', 0, () => { expect(viewModel.mapIndexToUsbStoragePolicy(0)).assertEqual(usbManager.UsbPolicy.READ_ONLY) })
    it('应将索引 1 映射为 READ_WRITE', 0, () => { expect(viewModel.mapIndexToUsbStoragePolicy(1)).assertEqual(usbManager.UsbPolicy.READ_WRITE) })
    it('应将索引 2 映射为 DENY', 0, () => { expect(viewModel.mapIndexToUsbStoragePolicy(2)).assertEqual(usbManager.UsbPolicy.DENY) })
  })

  describe('getUsbStoragePolicyLogValue', () => {
    it('应返回索引 0 的日志值', 0, () => { expect(viewModel.getUsbStoragePolicyLogValue(0)).assertEquals('只读') })
    it('应返回索引 1 的日志值', 0, () => { expect(viewModel.getUsbStoragePolicyLogValue(1)).assertEquals('读写') })
    it('应返回索引 2 的日志值', 0, () => { expect(viewModel.getUsbStoragePolicyLogValue(2)).assertEquals('禁用') })
  })

  describe('ensureAdminReady', () => {
    it('当管理员未激活时应返回 false', 0, () => { viewModel._adminState.activated = false; expect(viewModel.ensureAdminReady('测试')).assertFalse() })
    it('当管理员已激活时应返回 true', 0, () => { viewModel._adminState.activated = true; expect(viewModel.ensureAdminReady('测试')).assertTrue() })
  })
})

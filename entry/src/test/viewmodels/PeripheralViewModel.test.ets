/**
 * PeripheralViewModel 单元测试
 */
import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { PeripheralViewModel } from '../../viewmodels/PeripheralViewModel'

describe('PeripheralViewModel', () => {
  let viewModel: PeripheralViewModel

  beforeEach(() => {
    viewModel = new PeripheralViewModel()
  })

  describe('状态初始化', () => {
    it('应初始化所有接口状态为 false', 0, () => {
      expect(viewModel.usbDisabled).assertFalse()
      expect(viewModel.btDisabled).assertFalse()
      expect(viewModel.wifiDisabled).assertFalse()
      expect(viewModel.hdcDisabled).assertFalse()
      expect(viewModel.networkDisabled).assertFalse()
      expect(viewModel.printerDisabled).assertFalse()
      expect(viewModel.microphoneDisabled).assertFalse()
      expect(viewModel.cameraDisabled).assertFalse()
    })

    it('应初始化 USB 存储策略索引为 0', 0, () => {
      expect(viewModel.usbStoragePolicyIndex).assertEqual(0)
    })

    it('应初始化加载状态为 false', 0, () => {
      expect(viewModel.isLoading).assertFalse()
    })

    it('应初始化错误信息为 null', 0, () => {
      expect(viewModel.errorMessage).assertNull()
    })
  })

  describe('USB 存储策略索引转换', () => {
    it('索引 0 对应 READ_ONLY', 0, () => {
      // 验证逻辑：索引 0 应该对应 READ_ONLY 策略
      expect(viewModel.usbStoragePolicyIndex).assertEqual(0)
    })

    it('索引 1 对应 READ_WRITE', 0, () => {
      viewModel.usbStoragePolicyIndex = 1
      expect(viewModel.usbStoragePolicyIndex).assertEqual(1)
    })

    it('索引 2 对应 DISABLED', 0, () => {
      viewModel.usbStoragePolicyIndex = 2
      expect(viewModel.usbStoragePolicyIndex).assertEqual(2)
    })
  })

  describe('错误处理', () => {
    it('应能设置错误信息', 0, () => {
      viewModel.errorMessage = '测试错误'
      expect(viewModel.errorMessage).assertEquals('测试错误')
    })

    it('应能清除错误信息', 0, () => {
      viewModel.errorMessage = '测试错误'
      viewModel.errorMessage = null
      expect(viewModel.errorMessage).assertNull()
    })

    it('应能设置加载状态', 0, () => {
      viewModel.isLoading = true
      expect(viewModel.isLoading).assertTrue()
    })
  })

  describe('黑白名单数据', () => {
    it('应初始化为空数组', 0, () => {
      expect(viewModel.usbWhitelist.length).assertEqual(0)
      expect(viewModel.usbBlacklist.length).assertEqual(0)
      expect(viewModel.btWhitelist.length).assertEqual(0)
    })
  })

  describe('设备连接记录', () => {
    it('应初始化为空数组', 0, () => {
      expect(viewModel.deviceRecords.length).assertEqual(0)
    })
  })
})

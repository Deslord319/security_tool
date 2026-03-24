/**
 * DeviceRecordsViewModel 单元测试
 */
import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { DeviceRecordsViewModel } from '../../viewmodels/peripheral/DeviceRecordsViewModel'
import { PeripheralConnectionRecord, PeripheralType, PeripheralRecordAction } from '../../models/DataModels'

describe('DeviceRecordsViewModel', () => {
  let viewModel: DeviceRecordsViewModel
  beforeEach(() => { viewModel = new DeviceRecordsViewModel() })

  describe('状态初始化', () => {
    it('应初始化空设备记录列表', 0, () => { expect(viewModel.deviceRecords.length).assertEqual(0) })
    it('应初始化选中记录为 null', 0, () => { expect(viewModel.selectedRecord).assertNull() })
    it('应初始化详情对话框为关闭', 0, () => { expect(viewModel.isDetailVisible).assertFalse() })
    it('应初始化导出状态为 false', 0, () => { expect(viewModel.isExporting).assertFalse() })
  })

  describe('reloadRecords', () => {
    it('应加载设备记录', 0, () => { viewModel.reloadRecords(); expect(viewModel.deviceRecords).assertTrue() })
  })

  describe('openConnectionDetailDialog', () => {
    it('应打开详情对话框', 0, () => {
      const mockRecord: PeripheralConnectionRecord = { id: '1', deviceType: PeripheralType.USB_STORAGE, deviceId: 'VID_PID', action: PeripheralRecordAction.CONNECT, source: 'manual', policyHit: 'whitelist', result: 'success', timestamp: Date.now() }
      viewModel.openConnectionDetailDialog(mockRecord)
      expect(viewModel.selectedRecord).assertEqual(mockRecord); expect(viewModel.isDetailVisible).assertTrue()
    })
  })

  describe('closeConnectionDetailDialog', () => {
    it('应关闭详情对话框', 0, () => {
      viewModel.selectedRecord = {} as PeripheralConnectionRecord; viewModel.isDetailVisible = true
      viewModel.closeConnectionDetailDialog()
      expect(viewModel.selectedRecord).assertNull(); expect(viewModel.isDetailVisible).assertFalse()
    })
  })

  describe('getConnectionHistoryItems', () => {
    it('当记录为 null 时应返回空数组', 0, () => { expect(viewModel.getConnectionHistoryItems(null).length).assertEqual(0) })
    it('应返回历史记录项', 0, () => {
      const mockRecord: PeripheralConnectionRecord = { id: '1', deviceType: PeripheralType.USB_STORAGE, deviceId: 'VID_PID', action: PeripheralRecordAction.CONNECT, source: 'manual', policyHit: 'whitelist', result: 'success', timestamp: Date.now() }
      const items = viewModel.getConnectionHistoryItems(mockRecord)
      expect(items.length).assertEqual(1)
    })
  })

  describe('normalizeConnectionDetailValue', () => {
    it('当值为 null 时应返回 未知', 0, () => { expect(viewModel.normalizeConnectionDetailValue(null)).assertEquals('未知') })
    it('当值为空字符串时应返回 未知', 0, () => { expect(viewModel.normalizeConnectionDetailValue('')).assertEquals('未知') })
    it('应返回正常值', 0, () => { expect(viewModel.normalizeConnectionDetailValue('测试值')).assertEquals('测试值') })
  })
})

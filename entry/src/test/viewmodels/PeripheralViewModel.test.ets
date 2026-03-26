/**
 * PeripheralViewModel unit tests.
 */
import { beforeEach, describe, expect, it } from '@ohos/hypium'
import {
  LogEventResult,
  PeripheralConnectionRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import { PeripheralViewModel } from '../../main/ets/viewmodels/PeripheralViewModel'

describe('PeripheralViewModel', () => {
  let viewModel: PeripheralViewModel

  beforeEach(() => {
    viewModel = new PeripheralViewModel()
  })

  describe('initial state', () => {
    it('should initialize admin state as not activated', 0, () => {
      expect(viewModel.adminState.activated).assertFalse()
    })

    it('should initialize interface state with expected defaults', 0, () => {
      expect(viewModel.interfaceState.usbDisabled).assertFalse()
      expect(viewModel.interfaceState.btDisabled).assertFalse()
      expect(viewModel.interfaceState.wifiDisabled).assertFalse()
      expect(viewModel.interfaceState.hdcDisabled).assertFalse()
      expect(viewModel.interfaceState.networkDisabled).assertFalse()
      expect(viewModel.interfaceState.printerDisabled).assertFalse()
      expect(viewModel.interfaceState.microphoneDisabled).assertFalse()
      expect(viewModel.interfaceState.cameraDisabled).assertFalse()
      expect(viewModel.interfaceState.usbStoragePolicyIndex).assertEqual(1)
    })

    it('should initialize whitelist and blacklist state as empty', 0, () => {
      expect(viewModel.whitelistBlacklistState.usbWhitelist.length).assertEqual(0)
      expect(viewModel.whitelistBlacklistState.usbBlacklist.length).assertEqual(0)
      expect(viewModel.whitelistBlacklistState.btWhitelist.length).assertEqual(0)
    })

    it('should initialize records and policy lists as empty', 0, () => {
      expect(viewModel.deviceRecords.length).assertEqual(0)
      expect(viewModel.peripheralPolicyRecords.length).assertEqual(0)
    })

    it('should initialize dialog state as hidden', 0, () => {
      expect(viewModel.connectionDetailDialog.visible).assertFalse()
      expect(viewModel.connectionDetailDialog.record).assertNull()
      expect(viewModel.connectionDetailDialog.historyItems.length).assertEqual(0)
    })
  })

  describe('tab switching', () => {
    it('should switch to tab 1', 0, () => {
      viewModel.switchToTab(1)
      expect(viewModel.currentTab).assertEqual(1)
    })

    it('should switch to tab 2', 0, () => {
      viewModel.switchToTab(2)
      expect(viewModel.currentTab).assertEqual(2)
    })

    it('should ignore invalid indices and repeated switch', 0, () => {
      viewModel.switchToTab(0)
      expect(viewModel.currentTab).assertEqual(0)

      viewModel.switchToTab(-1)
      expect(viewModel.currentTab).assertEqual(0)

      viewModel.switchToTab(3)
      expect(viewModel.currentTab).assertEqual(0)
    })
  })

  describe('policy update state', () => {
    it('should track updating device ids', 0, () => {
      const deviceId = 'VID:1234 PID:5678'
      viewModel.startPeripheralPolicyUpdate(deviceId)
      expect(viewModel.isPeripheralPolicyUpdating(deviceId)).assertTrue()
      expect(viewModel.isPeripheralPolicyUpdating(deviceId.toLowerCase())).assertTrue()

      viewModel.endPeripheralPolicyUpdate(deviceId)
      expect(viewModel.isPeripheralPolicyUpdating(deviceId)).assertFalse()
    })
  })

  describe('connection detail dialog', () => {
    it('should open dialog with selected record and generated history', 0, () => {
      const baseTimestamp = Date.now()
      const firstRecord: PeripheralConnectionRecord = {
        id: 'test-1',
        timestamp: baseTimestamp,
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'Test Device',
        deviceType: PeripheralType.USB_STORAGE,
        source: 'runtime_event',
        action: 'connect',
        result: LogEventResult.SUCCESS,
        policyHit: 'allow',
        summary: 'device connected'
      }
      const secondRecord: PeripheralConnectionRecord = {
        id: 'test-2',
        timestamp: baseTimestamp + 1000,
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'Test Device',
        deviceType: PeripheralType.USB_STORAGE,
        source: 'audit_event',
        action: 'disconnect',
        result: LogEventResult.FAILED,
        policyHit: 'deny',
        summary: 'device disconnected'
      }
      viewModel.deviceRecords = [firstRecord, secondRecord]

      viewModel.openConnectionDetailDialog(firstRecord)

      expect(viewModel.connectionDetailDialog.visible).assertTrue()
      expect(viewModel.connectionDetailDialog.record).assertEquals(firstRecord)
      expect(viewModel.connectionDetailDialog.historyItems.length).assertEqual(2)
    })

    it('should deduplicate identical history items', 0, () => {
      const timestamp = Date.now()
      const record: PeripheralConnectionRecord = {
        id: 'test-1',
        timestamp: timestamp,
        deviceId: 'VID:1234 PID:5678',
        deviceName: 'Test Device',
        deviceType: PeripheralType.USB_STORAGE,
        source: 'runtime_event',
        action: 'connect',
        result: LogEventResult.SUCCESS,
        policyHit: 'allow',
        summary: 'device connected'
      }
      viewModel.deviceRecords = [record, { ...record, id: 'test-2' }]

      viewModel.openConnectionDetailDialog(record)

      expect(viewModel.connectionDetailDialog.historyItems.length).assertEqual(1)
    })

    it('should close dialog and reset state', 0, () => {
      viewModel.connectionDetailDialog.visible = true
      viewModel.closeConnectionDetailDialog()
      expect(viewModel.connectionDetailDialog.visible).assertFalse()
      expect(viewModel.connectionDetailDialog.record).assertNull()
      expect(viewModel.connectionDetailDialog.historyItems.length).assertEqual(0)
    })
  })

  describe('admin guard and export guards', () => {
    it('should return false when admin is not activated', 0, () => {
      const result = viewModel.ensureAdminReady('测试操作')
      expect(result).assertFalse()
      expect(viewModel.errorMessage).assertEqual('测试操作未完成，请先激活企业管理员')
    })

    it('should reject exporting connection history when there are no records', 0, async (done: Function) => {
      const result = await viewModel.exportConnectionHistory()
      expect(result).assertFalse()
      expect(viewModel.errorMessage).assertEqual('没有可导出的设备连接记录')
      done()
    })

    it('should reject exporting policy records when there are no records', 0, async (done: Function) => {
      const result = await viewModel.exportPeripheralPolicyRecords()
      expect(result).assertFalse()
      expect(viewModel.errorMessage).assertEqual('暂无可导出的设备策略记录')
      done()
    })
  })

  describe('safe public methods', () => {
    it('safe public methods should be callable', 0, async (done: Function) => {
      expect(() => viewModel.reloadDeviceRecords()).not.toThrow()
      await viewModel.reloadAllData()
      expect(() => viewModel.destroy()).not.toThrow()
      done()
    })
  })
}

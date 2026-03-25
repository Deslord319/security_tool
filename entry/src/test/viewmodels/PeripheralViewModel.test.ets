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

    it('should initialize ui state as expected', 0, () => {
      expect(viewModel.isLoading).assertFalse()
      expect(viewModel.errorMessage).assertNull()
      expect(viewModel.interfaceControlProcessingKey).assertEqual('')
      expect(viewModel.policyUpdatingKeys.length).assertEqual(0)
      expect(viewModel.peripheralPolicyRenderVersion).assertEqual(0)
      expect(viewModel.currentTab).assertEqual(0)
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

    it('should ignore invalid negative tab index', 0, () => {
      viewModel.switchToTab(-1)
      expect(viewModel.currentTab).assertEqual(0)
    })

    it('should ignore invalid large tab index', 0, () => {
      viewModel.switchToTab(3)
      expect(viewModel.currentTab).assertEqual(0)
    })

    it('should ignore switching to the same tab', 0, () => {
      viewModel.currentTab = 1
      viewModel.switchToTab(1)
      expect(viewModel.currentTab).assertEqual(1)
    })
  })

  describe('policy update state', () => {
    it('should track updating device ids', 0, () => {
      const deviceId = 'VID:1234 PID:5678'
      viewModel.startPeripheralPolicyUpdate(deviceId)

      expect(viewModel.isPeripheralPolicyUpdating(deviceId)).assertTrue()
    })

    it('should remove device id from updating state', 0, () => {
      const deviceId = 'VID:1234 PID:5678'
      viewModel.startPeripheralPolicyUpdate(deviceId)
      viewModel.endPeripheralPolicyUpdate(deviceId)

      expect(viewModel.isPeripheralPolicyUpdating(deviceId)).assertFalse()
    })

    it('should track multiple updating device ids independently', 0, () => {
      const deviceId1 = 'VID:1234 PID:5678'
      const deviceId2 = 'VID:ABCD PID:EF01'

      viewModel.startPeripheralPolicyUpdate(deviceId1)
      viewModel.startPeripheralPolicyUpdate(deviceId2)
      viewModel.endPeripheralPolicyUpdate(deviceId1)

      expect(viewModel.isPeripheralPolicyUpdating(deviceId1)).assertFalse()
      expect(viewModel.isPeripheralPolicyUpdating(deviceId2)).assertTrue()
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

    it('should close dialog and reset dialog state', 0, () => {
      viewModel.connectionDetailDialog.visible = true
      viewModel.closeConnectionDetailDialog()

      expect(viewModel.connectionDetailDialog.visible).assertFalse()
      expect(viewModel.connectionDetailDialog.record).assertNull()
      expect(viewModel.connectionDetailDialog.historyItems.length).assertEqual(0)
    })
  })

  describe('error and loading state', () => {
    it('should allow setting and clearing error message', 0, () => {
      viewModel.errorMessage = 'test error'
      expect(viewModel.errorMessage).assertEqual('test error')

      viewModel.errorMessage = null
      expect(viewModel.errorMessage).assertNull()
    })

    it('should allow setting loading state', 0, () => {
      viewModel.isLoading = true
      expect(viewModel.isLoading).assertTrue()
    })
  })

  describe('admin guard', () => {
    it('should return false when admin is not activated', 0, () => {
      const result = viewModel.ensureAdminReady('测试操作')
      expect(result).assertFalse()
      expect(viewModel.errorMessage !== null).assertTrue()
    })
  })

  describe('usb display name builder', () => {
    it('should use manufacturer and product name together', 0, () => {
      const name = viewModel.buildUsbDisplayName('Kingston', 'DataTraveler', 0x0951, 0x1666)
      expect(name).assertEqual('Kingston DataTraveler')
    })

    it('should use manufacturer only when product is empty', 0, () => {
      const name = viewModel.buildUsbDisplayName('Kingston', '', 0x0951, 0x1666)
      expect(name).assertEqual('Kingston')
    })

    it('should use product only when manufacturer is empty', 0, () => {
      const name = viewModel.buildUsbDisplayName('', 'DataTraveler', 0x0951, 0x1666)
      expect(name).assertEqual('DataTraveler')
    })

    it('should fall back to vid pid label when names are missing', 0, () => {
      const name = viewModel.buildUsbDisplayName('', '', 0x0951, 0x1666)
      expect(name).assertEqual('USB 设备 (0951:1666)')
    })

    it('should use default label when all info is missing', 0, () => {
      const name = viewModel.buildUsbDisplayName(undefined, undefined, undefined, undefined)
      expect(name).assertEqual('USB Device')
    })
  })

  describe('safe public methods', () => {
    it('reloadDeviceRecords should be callable', 0, () => {
      expect(() => viewModel.reloadDeviceRecords()).not.toThrow()
    })

    it('reloadAllData should be callable', 0, () => {
      expect(() => viewModel.reloadAllData()).not.toThrow()
    })

    it('destroy should be callable', 0, () => {
      expect(() => viewModel.destroy()).not.toThrow()
    })
  })
})

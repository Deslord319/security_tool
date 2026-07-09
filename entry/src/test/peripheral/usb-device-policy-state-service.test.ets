import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  PeripheralType,
  UsbDevicePolicyStateRecord
} from '../../main/ets/models/PeripheralModels'
import {
  PeripheralDevicePolicyDispatchService,
  PeripheralPolicyDispatchRequest,
  PeripheralPolicyDispatchResult
} from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyDispatchService'
import { UsbDevicePolicyStateRepository } from '../../main/ets/services/peripheral/device-policy/UsbDevicePolicyStateRepository'
import { UsbDevicePolicyStateService } from '../../main/ets/services/peripheral/device-policy/UsbDevicePolicyStateService'

function cloneUsbState(record: UsbDevicePolicyStateRecord): UsbDevicePolicyStateRecord {
  return {
    fingerprintKey: record.fingerprintKey,
    fingerprintType: record.fingerprintType,
    serialNumber: record.serialNumber,
    vendorId: record.vendorId,
    productId: record.productId,
    description: record.description,
    baseClass: record.baseClass,
    deviceName: record.deviceName,
    desiredPolicy: record.desiredPolicy,
    present: record.present,
    activePolicy: record.activePolicy,
    lastSeenAt: record.lastSeenAt,
    updatedAt: record.updatedAt
  }
}

function createUsbState(
  fingerprintKey: string,
  baseClass: number,
  desiredPolicy: 'allow' | 'deny',
  activePolicy: 'none' | 'deny',
  present: boolean
): UsbDevicePolicyStateRecord {
  return {
    fingerprintKey: fingerprintKey,
    fingerprintType: 'weak',
    vendorId: 0x1234,
    productId: 0x5678,
    description: 'storage',
    baseClass: baseClass,
    deviceName: 'USB Device',
    desiredPolicy: desiredPolicy,
    present: present,
    activePolicy: activePolicy,
    lastSeenAt: 300,
    updatedAt: 301
  }
}

function createDispatchResult(success: boolean, reason?: string): PeripheralPolicyDispatchResult {
  let result: PeripheralPolicyDispatchResult = {
    success: success
  }
  if (reason !== undefined) {
    result.reason = reason as never
  }
  return result
}

export default function usbDevicePolicyStateServiceTest() {
  describe('UsbDevicePolicyStateService', () => {
    let mockKit: MockKit
    let states: UsbDevicePolicyStateRecord[]
    let savedStates: UsbDevicePolicyStateRecord[]
    let dispatchRequests: PeripheralPolicyDispatchRequest[]
    let dispatchResult: PeripheralPolicyDispatchResult
    let saveCalls: number

    beforeEach(async () => {
      mockKit = new MockKit()
      states = []
      savedStates = []
      dispatchRequests = []
      dispatchResult = createDispatchResult(true)
      saveCalls = 0

      let listMock = mockKit.mockFunc(UsbDevicePolicyStateRepository, UsbDevicePolicyStateRepository.listAll)
      let upsertAllMock = mockKit.mockFunc(UsbDevicePolicyStateRepository, UsbDevicePolicyStateRepository.upsertAll)
      let dispatchMock = mockKit.mockFunc(PeripheralDevicePolicyDispatchService, PeripheralDevicePolicyDispatchService.dispatch)

      when(listMock)().afterAction(() => Promise.resolve(
        states.map((item: UsbDevicePolicyStateRecord) => cloneUsbState(item))
      ))
      when(upsertAllMock)(ArgumentMatchers.any).afterAction((records: UsbDevicePolicyStateRecord[]) => {
        saveCalls += 1
        savedStates = records.map((item: UsbDevicePolicyStateRecord) => cloneUsbState(item))
        return Promise.resolve(true)
      })
      when(dispatchMock)(ArgumentMatchers.any).afterAction((request: PeripheralPolicyDispatchRequest) => {
        dispatchRequests.push(request)
        return Promise.resolve(dispatchResult)
      })
    })

    afterEach(async () => {
      mockKit.clearAll()
    })

    it('should restore usb policy states to default allow without deleting cards', 0, async () => {
      states = [
        createUsbState('USB-WEAK:1234:5678:AAAA0001', 0x08, 'deny', 'deny', true),
        createUsbState('USB-WEAK:1234:5678:BBBB0002', 0x03, 'deny', 'none', false)
      ]

      const success = await UsbDevicePolicyStateService.clearAllPolicies()

      expect(success).assertTrue()
      expect(dispatchRequests.length).assertEqual(1)
      expect(dispatchRequests[0].deviceId).assertEqual('USB-WEAK:1234:5678:AAAA0001')
      expect(dispatchRequests[0].deviceType).assertEqual(PeripheralType.USB_STORAGE)
      expect(dispatchRequests[0].policy).assertEqual('allow')
      expect(saveCalls).assertEqual(1)
      expect(savedStates.length).assertEqual(2)
      expect(savedStates[0].fingerprintKey).assertEqual('USB-WEAK:1234:5678:AAAA0001')
      expect(savedStates[0].desiredPolicy).assertEqual('allow')
      expect(savedStates[0].activePolicy).assertEqual('none')
      expect(savedStates[1].fingerprintKey).assertEqual('USB-WEAK:1234:5678:BBBB0002')
      expect(savedStates[1].desiredPolicy).assertEqual('allow')
      expect(savedStates[1].activePolicy).assertEqual('none')
      expect(savedStates[1].present).assertFalse()
    })

    it('should not persist default allow when active deny restore dispatch fails', 0, async () => {
      states = [
        createUsbState('USB-WEAK:1234:5678:AAAA0001', 0x08, 'deny', 'deny', true)
      ]
      dispatchResult = createDispatchResult(false, 'usb_dispatch_failed')

      const success = await UsbDevicePolicyStateService.clearAllPolicies()

      expect(success).assertFalse()
      expect(dispatchRequests.length).assertEqual(1)
      expect(saveCalls).assertEqual(0)
      expect(savedStates.length).assertEqual(0)
    })
  })
}

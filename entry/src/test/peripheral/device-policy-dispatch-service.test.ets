import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import restrictions from '@ohos.enterprise.restrictions'
import { bluetoothManager, usbManager } from '@kit.MDMKit'
import { PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralDevicePolicyDispatchService } from '../../main/ets/services/peripheral/device-policy/peripheral_device_policy_dispatch_service'

interface MutableRestrictionsApi {
  getDisallowedPolicy: (want: Object, policyName: string) => boolean
}

interface MutableUsbManagerApi {
  getDisallowedUsbDevices: (want: Object) => usbManager.UsbDeviceType[]
  removeDisallowedUsbDevices: (want: Object, deviceTypes: usbManager.UsbDeviceType[]) => void
  addDisallowedUsbDevices: (want: Object, deviceTypes: usbManager.UsbDeviceType[]) => void
  getUsbStorageDeviceAccessPolicy: (want: Object) => usbManager.UsbPolicy
}

interface MutableBluetoothManagerApi {
  getDisallowedBluetoothDevices: (want: Object) => string[]
  removeDisallowedBluetoothDevices: (want: Object, deviceIds: string[]) => void
  addDisallowedBluetoothDevices: (want: Object, deviceIds: string[]) => void
}

function buildUsbDeviceType(baseClass: number): usbManager.UsbDeviceType {
  return {
    baseClass: baseClass,
    subClass: 0,
    protocol: 0,
    descriptor: usbManager.Descriptor.INTERFACE
  } as usbManager.UsbDeviceType
}

function isSameUsbDeviceType(left: usbManager.UsbDeviceType, right: usbManager.UsbDeviceType): boolean {
  return left.baseClass === right.baseClass &&
    left.subClass === right.subClass &&
    left.protocol === right.protocol &&
    left.descriptor === right.descriptor
}

export default function peripheralDevicePolicyDispatchServiceTest() {
  describe('PeripheralDevicePolicyDispatchService', () => {
    const restrictionsApi = restrictions as Object as MutableRestrictionsApi
    const usbApi = usbManager as Object as MutableUsbManagerApi
    const bluetoothApi = bluetoothManager as Object as MutableBluetoothManagerApi
    const originalGetDisallowedPolicy = restrictionsApi.getDisallowedPolicy
    const originalGetDisallowedUsbDevices = usbApi.getDisallowedUsbDevices
    const originalRemoveDisallowedUsbDevices = usbApi.removeDisallowedUsbDevices
    const originalAddDisallowedUsbDevices = usbApi.addDisallowedUsbDevices
    const originalGetUsbStoragePolicy = usbApi.getUsbStorageDeviceAccessPolicy
    const originalGetDisallowedBluetoothDevices = bluetoothApi.getDisallowedBluetoothDevices
    const originalRemoveDisallowedBluetoothDevices = bluetoothApi.removeDisallowedBluetoothDevices
    const originalAddDisallowedBluetoothDevices = bluetoothApi.addDisallowedBluetoothDevices

    let usbDisabled: boolean
    let bluetoothDisabled: boolean
    let usbStoragePolicy: usbManager.UsbPolicy
    let usbDisallowed: usbManager.UsbDeviceType[]
    let bluetoothDisallowed: string[]
    let usbRemoveCalls: number
    let usbAddCalls: number
    let bluetoothRemoveCalls: number
    let bluetoothAddCalls: number

    beforeEach(() => {
      usbDisabled = false
      bluetoothDisabled = false
      usbStoragePolicy = usbManager.UsbPolicy.READ_WRITE
      usbDisallowed = []
      bluetoothDisallowed = []
      usbRemoveCalls = 0
      usbAddCalls = 0
      bluetoothRemoveCalls = 0
      bluetoothAddCalls = 0

      restrictionsApi.getDisallowedPolicy = (_want: Object, policyName: string): boolean => {
        return policyName === 'usb' ? usbDisabled : bluetoothDisabled
      }
      usbApi.getUsbStorageDeviceAccessPolicy = (_want: Object): usbManager.UsbPolicy => {
        return usbStoragePolicy
      }
      usbApi.getDisallowedUsbDevices = (_want: Object): usbManager.UsbDeviceType[] => {
        return usbDisallowed.slice()
      }
      usbApi.removeDisallowedUsbDevices = (_want: Object, deviceTypes: usbManager.UsbDeviceType[]): void => {
        usbRemoveCalls += 1
        usbDisallowed = usbDisallowed.filter((item: usbManager.UsbDeviceType) => {
          return !deviceTypes.some((target: usbManager.UsbDeviceType) => isSameUsbDeviceType(item, target))
        })
      }
      usbApi.addDisallowedUsbDevices = (_want: Object, deviceTypes: usbManager.UsbDeviceType[]): void => {
        usbAddCalls += 1
        deviceTypes.forEach((deviceType: usbManager.UsbDeviceType) => {
          if (!usbDisallowed.some((item: usbManager.UsbDeviceType) => isSameUsbDeviceType(item, deviceType))) {
            usbDisallowed.push(deviceType)
          }
        })
      }
      bluetoothApi.getDisallowedBluetoothDevices = (_want: Object): string[] => {
        return bluetoothDisallowed.slice()
      }
      bluetoothApi.removeDisallowedBluetoothDevices = (_want: Object, deviceIds: string[]): void => {
        bluetoothRemoveCalls += 1
        bluetoothDisallowed = bluetoothDisallowed.filter((item: string) => !deviceIds.includes(item))
      }
      bluetoothApi.addDisallowedBluetoothDevices = (_want: Object, deviceIds: string[]): void => {
        bluetoothAddCalls += 1
        deviceIds.forEach((deviceId: string) => {
          if (!bluetoothDisallowed.includes(deviceId)) {
            bluetoothDisallowed.push(deviceId)
          }
        })
      }
    })

    afterEach(() => {
      restrictionsApi.getDisallowedPolicy = originalGetDisallowedPolicy
      usbApi.getDisallowedUsbDevices = originalGetDisallowedUsbDevices
      usbApi.removeDisallowedUsbDevices = originalRemoveDisallowedUsbDevices
      usbApi.addDisallowedUsbDevices = originalAddDisallowedUsbDevices
      usbApi.getUsbStorageDeviceAccessPolicy = originalGetUsbStoragePolicy
      bluetoothApi.getDisallowedBluetoothDevices = originalGetDisallowedBluetoothDevices
      bluetoothApi.removeDisallowedBluetoothDevices = originalRemoveDisallowedBluetoothDevices
      bluetoothApi.addDisallowedBluetoothDevices = originalAddDisallowedBluetoothDevices
    })

    it('should remove usb deny and return to default allow for usb allow policy', 0, async () => {
      usbDisallowed = [buildUsbDeviceType(0x08)]

      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'VID:1234 PID:5678',
        deviceType: PeripheralType.USB_STORAGE,
        policy: 'allow'
      })

      expect(result.success).assertTrue()
      expect(usbDisallowed.length).assertEqual(0)
      expect(usbRemoveCalls).assertEqual(1)
      expect(usbAddCalls).assertEqual(0)
    })

    it('should leave usb deny list unchanged when usb allow target is already default allow', 0, async () => {
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'VID:1234 PID:5678',
        deviceType: PeripheralType.USB_STORAGE,
        policy: 'allow'
      })

      expect(result.success).assertTrue()
      expect(usbDisallowed.length).assertEqual(0)
      expect(usbRemoveCalls).assertEqual(0)
      expect(usbAddCalls).assertEqual(0)
    })

    it('should add usb deny for usb deny policy', 0, async () => {
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'VID:1234 PID:5678',
        deviceType: PeripheralType.USB_STORAGE,
        policy: 'deny'
      })

      expect(result.success).assertTrue()
      expect(usbDisallowed.length).assertEqual(1)
      expect(usbDisallowed[0].baseClass).assertEqual(0x08)
      expect(usbAddCalls).assertEqual(1)
      expect(usbRemoveCalls).assertEqual(0)
    })

    it('should remove bluetooth deny and return to default allow for bluetooth allow policy', 0, async () => {
      bluetoothDisallowed = ['AA:BB:CC:DD:EE:FF']

      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
        deviceType: PeripheralType.BLUETOOTH,
        policy: 'allow'
      })

      expect(result.success).assertTrue()
      expect(bluetoothDisallowed.length).assertEqual(0)
      expect(bluetoothRemoveCalls).assertEqual(1)
      expect(bluetoothAddCalls).assertEqual(0)
    })

    it('should leave bluetooth deny list unchanged when bluetooth allow target is already default allow', 0, async () => {
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'aa-bb-cc-dd-ee-ff',
        deviceType: PeripheralType.BLUETOOTH,
        policy: 'allow'
      })

      expect(result.success).assertTrue()
      expect(bluetoothDisallowed.length).assertEqual(0)
      expect(bluetoothRemoveCalls).assertEqual(0)
      expect(bluetoothAddCalls).assertEqual(0)
    })

    it('should add bluetooth deny for bluetooth deny policy', 0, async () => {
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
        deviceType: PeripheralType.BLUETOOTH,
        policy: 'deny'
      })

      expect(result.success).assertTrue()
      expect(bluetoothDisallowed.length).assertEqual(1)
      expect(bluetoothDisallowed[0]).assertEqual('AA:BB:CC:DD:EE:FF')
      expect(bluetoothAddCalls).assertEqual(1)
      expect(bluetoothRemoveCalls).assertEqual(0)
    })

    it('should reject usb allow when usb storage policy is disabled', 0, async () => {
      usbStoragePolicy = usbManager.UsbPolicy.DISABLED

      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'VID:1234 PID:5678',
        deviceType: PeripheralType.USB_STORAGE,
        policy: 'allow'
      })

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('usb_conflict_account_storage')
      expect(usbRemoveCalls).assertEqual(0)
      expect(usbAddCalls).assertEqual(0)
    })

    it('should reject bluetooth allow when bluetooth is globally disabled', 0, async () => {
      bluetoothDisabled = true

      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: 'MAC: AA:BB:CC:DD:EE:FF',
        deviceType: PeripheralType.BLUETOOTH,
        policy: 'allow'
      })

      expect(result.success).assertFalse()
      expect(result.reason).assertEqual('bluetooth_conflict_global_disabled')
      expect(bluetoothRemoveCalls).assertEqual(0)
      expect(bluetoothAddCalls).assertEqual(0)
    })
  })
}

import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  PeripheralDevicePolicyRecord,
  PeripheralType
} from '../../main/ets/models/PeripheralModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'

class FakePreferencesAccessor {
  private storedRecords: PeripheralDevicePolicyRecord[]
  private usbDefaultPolicy: string

  constructor(storedRecords: PeripheralDevicePolicyRecord[], usbDefaultPolicy: string = 'allow') {
    this.storedRecords = storedRecords
    this.usbDefaultPolicy = usbDefaultPolicy
  }

  async getJsonArray<T>(_key: string, defaultValue: T[]): Promise<T[]> {
    return this.storedRecords.length > 0 ? this.storedRecords as T[] : defaultValue
  }

  async getString(key: string, defaultValue: string): Promise<string> {
    return key === 'usb_default_policy' ? this.usbDefaultPolicy : defaultValue
  }

  async setJson(_key: string, value: PeripheralDevicePolicyRecord[], _flush: boolean = true): Promise<boolean> {
    this.storedRecords.splice(0, this.storedRecords.length, ...value)
    return true
  }

  async setValue(key: string, value: string | number | boolean, _flush: boolean = true): Promise<boolean> {
    if (key === 'usb_default_policy' && typeof value === 'string') {
      this.usbDefaultPolicy = value
    }
    return true
  }
}

function createRecord(deviceId: string, policy: 'allow' | 'deny' = 'allow'): PeripheralDevicePolicyRecord {
  return {
    deviceId: deviceId,
    policy: policy,
    updatedAt: Date.now(),
    deviceName: `Device-${deviceId}`,
    deviceType: PeripheralType.USB_STORAGE
  }
}

export default function peripheralDevicePolicyRepositoryTest() {
  describe('PeripheralDevicePolicyRepository', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext
    let storedRecords: PeripheralDevicePolicyRecord[]

    beforeEach(() => {
      PeripheralDevicePolicyRepository.resetForTest()
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
      storedRecords = []

      let prefMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(prefMock)(ArgumentMatchers.any).afterReturn(new FakePreferencesAccessor(storedRecords) as never as PreferencesAccessor)
    })

    afterEach(() => {
      mockKit.clearAll()
      storedRecords = []
      PeripheralDevicePolicyRepository.resetForTest()
    })

    it('should initialize successfully', 0, async () => {
      let result = await PeripheralDevicePolicyRepository.init(context)

      expect(result).assertTrue()
    })

    it('should return empty array when no records', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      let records = PeripheralDevicePolicyRepository.getAll()

      expect(records.length).assertEqual(0)
    })

    it('should set and get record', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      let record = createRecord('device-001', 'allow')
      let setResult = await PeripheralDevicePolicyRepository.set(record)

      expect(setResult).assertTrue()
      let records = PeripheralDevicePolicyRepository.getAll()
      expect(records.length).assertEqual(1)
      expect(records[0].deviceId).assertEqual('DEVICE-001')
      expect(records[0].policy).assertEqual('allow')
    })

    it('should normalize device id on set', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      let record = createRecord('DEVICE-001', 'deny')
      await PeripheralDevicePolicyRepository.set(record)

      let records = PeripheralDevicePolicyRepository.getAll()
      expect(records.length).assertEqual(1)
      expect(records[0].deviceId).assertEqual('DEVICE-001')
    })

    it('should update existing record', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      await PeripheralDevicePolicyRepository.set(createRecord('device-001', 'allow'))
      await PeripheralDevicePolicyRepository.set(createRecord('device-001', 'deny'))

      let records = PeripheralDevicePolicyRepository.getAll()
      expect(records.length).assertEqual(1)
      expect(records[0].policy).assertEqual('deny')
    })

    it('should remove record', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      await PeripheralDevicePolicyRepository.set(createRecord('device-001'))
      let removeResult = await PeripheralDevicePolicyRepository.remove('device-001')

      expect(removeResult).assertTrue()

      let found = PeripheralDevicePolicyRepository.get('device-001')
      expect(found === null || found === undefined).assertTrue()
    })

    it('should clear all records', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      await PeripheralDevicePolicyRepository.set(createRecord('device-001'))
      await PeripheralDevicePolicyRepository.set(createRecord('device-002'))
      let clearResult = await PeripheralDevicePolicyRepository.clearAll()

      expect(clearResult).assertTrue()

      let records = PeripheralDevicePolicyRepository.getAll()
      expect(records.length).assertEqual(0)
    })

    it('should add change listener', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      let eventCount = 0
      let listenerId = PeripheralDevicePolicyRepository.addChangeListener(() => {
        eventCount++
      })

      await PeripheralDevicePolicyRepository.set(createRecord('device-001'))

      expect(eventCount > 0).assertTrue()

      PeripheralDevicePolicyRepository.removeChangeListener(listenerId)
    })

    it('should remove change listener', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      let eventCount = 0
      let listenerId = PeripheralDevicePolicyRepository.addChangeListener(() => {
        eventCount++
      })

      PeripheralDevicePolicyRepository.removeChangeListener(listenerId)
      await PeripheralDevicePolicyRepository.set(createRecord('device-001'))

      expect(eventCount).assertEqual(0)
    })

    it('should return cloned records', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      await PeripheralDevicePolicyRepository.set(createRecord('device-001'))

      let records1 = PeripheralDevicePolicyRepository.getAll()
      let records2 = PeripheralDevicePolicyRepository.getAll()
      records1[0].policy = 'deny'

      expect(records1 !== records2).assertTrue()
      expect(records2[0].policy).assertEqual('allow')
    })

    it('should handle re-initialization', 0, async () => {
      let firstInit = await PeripheralDevicePolicyRepository.init(context)
      let secondInit = await PeripheralDevicePolicyRepository.init(context)

      expect(firstInit).assertTrue()
      expect(secondInit).assertTrue()
    })

    it('should return null for non-existent device', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      let found = PeripheralDevicePolicyRepository.get('non-existent')

      expect(found === null || found === undefined).assertTrue()
    })

    it('should default policy to allow when invalid', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      let record = createRecord('device-001', 'allow')
      record.policy = 'invalid' as 'allow' | 'deny'
      await PeripheralDevicePolicyRepository.set(record)

      let records = PeripheralDevicePolicyRepository.getAll()
      expect(records.length).assertEqual(1)
      expect(records[0].policy).assertEqual('allow')
    })

    it('should default usb default policy to allow when no value exists', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      expect(PeripheralDevicePolicyRepository.getUsbDefaultPolicy()).assertEqual('allow')
    })

    it('should set usb default policy to deny and allow', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      let denyResult = await PeripheralDevicePolicyRepository.setUsbDefaultPolicy('deny')
      expect(denyResult ? 'success' : 'failed').assertEqual('success')
      expect(PeripheralDevicePolicyRepository.getUsbDefaultPolicy()).assertEqual('deny')

      let allowResult = await PeripheralDevicePolicyRepository.setUsbDefaultPolicy('allow')
      expect(allowResult ? 'success' : 'failed').assertEqual('success')
      expect(PeripheralDevicePolicyRepository.getUsbDefaultPolicy()).assertEqual('allow')
    })

    it('should normalize invalid usb default policy to allow', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      let result = await PeripheralDevicePolicyRepository.setUsbDefaultPolicy('invalid' as 'allow' | 'deny')

      expect(result).assertTrue()
      expect(PeripheralDevicePolicyRepository.getUsbDefaultPolicy()).assertEqual('allow')
    })
  })
}

import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { PeripheralDevicePolicyRecord, PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'

class FakePreferencesAccessor {
  private storedRecords: PeripheralDevicePolicyRecord[]

  constructor(storedRecords: PeripheralDevicePolicyRecord[]) {
    this.storedRecords = storedRecords
  }

  async getJsonArray<T>(_key: string, defaultValue: T[]): Promise<T[]> {
    return this.storedRecords.length > 0 ? this.storedRecords as T[] : defaultValue
  }

  async setJson(_key: string, value: PeripheralDevicePolicyRecord[], _flush: boolean = true): Promise<boolean> {
    this.storedRecords.splice(0, this.storedRecords.length, ...value)
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
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
      storedRecords = []

      let prefMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(prefMock)(ArgumentMatchers.any).afterReturn(new FakePreferencesAccessor(storedRecords) as never as PreferencesAccessor)
    })

    afterEach(() => {
      mockKit.clearAll()
      storedRecords = []
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
      let found = PeripheralDevicePolicyRepository.get('device-001')
      expect(found !== null).assertTrue()
      expect(found?.deviceId).assertEqual('device-001')
      expect(found?.policy).assertEqual('allow')
    })

    it('should normalize device id on set', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      let record = createRecord('DEVICE-001', 'deny')
      await PeripheralDevicePolicyRepository.set(record)

      let found = PeripheralDevicePolicyRepository.get('device-001')
      expect(found !== null).assertTrue()
    })

    it('should update existing record', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)

      await PeripheralDevicePolicyRepository.set(createRecord('device-001', 'allow'))
      await PeripheralDevicePolicyRepository.set(createRecord('device-001', 'deny'))

      let found = PeripheralDevicePolicyRepository.get('device-001')
      expect(found !== null).assertTrue()
      expect(found?.policy).assertEqual('deny')
      expect(PeripheralDevicePolicyRepository.getAll().length).assertEqual(1)
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

      let found = PeripheralDevicePolicyRepository.get('device-001')
      expect(found !== null).assertTrue()
      expect(found?.policy).assertEqual('allow')
    })
  })
}

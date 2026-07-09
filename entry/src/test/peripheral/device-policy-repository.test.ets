import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { PeripheralDevicePolicyRepository } from '../../main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'

class FakePreferencesAccessor {
  private usbDefaultPolicy: string
  private failSetValue: boolean

  constructor(usbDefaultPolicy: string = 'allow', failSetValue: boolean = false) {
    this.usbDefaultPolicy = usbDefaultPolicy
    this.failSetValue = failSetValue
  }

  async getString(key: string, defaultValue: string): Promise<string> {
    return key === 'usb_default_policy' ? this.usbDefaultPolicy : defaultValue
  }

  async setValue(key: string, value: string | number | boolean, _flush: boolean = true): Promise<boolean> {
    if (this.failSetValue) {
      return false
    }
    if (key === 'usb_default_policy' && typeof value === 'string') {
      this.usbDefaultPolicy = value
    }
    return true
  }
}

export default function peripheralDevicePolicyRepositoryTest() {
  describe('PeripheralDevicePolicyRepository', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext
    let fakePref: FakePreferencesAccessor

    beforeEach(() => {
      PeripheralDevicePolicyRepository.resetForTest()
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
      fakePref = new FakePreferencesAccessor()

      let prefMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(prefMock)(ArgumentMatchers.any).afterAction(() => fakePref as never as PreferencesAccessor)
    })

    afterEach(() => {
      mockKit.clearAll()
      PeripheralDevicePolicyRepository.resetForTest()
    })

    it('should initialize usb default policy as allow by default', 0, async () => {
      let result = await PeripheralDevicePolicyRepository.init(context)

      expect(result).assertTrue()
      expect(PeripheralDevicePolicyRepository.getUsbDefaultPolicy()).assertEqual('allow')
    })

    it('should read persisted usb default deny policy', 0, async () => {
      fakePref = new FakePreferencesAccessor('deny')

      let result = await PeripheralDevicePolicyRepository.init(context)

      expect(result).assertTrue()
      expect(PeripheralDevicePolicyRepository.getUsbDefaultPolicy()).assertEqual('deny')
    })

    it('should normalize invalid persisted usb default policy to allow', 0, async () => {
      fakePref = new FakePreferencesAccessor('invalid')

      await PeripheralDevicePolicyRepository.init(context)

      expect(PeripheralDevicePolicyRepository.getUsbDefaultPolicy()).assertEqual('allow')
    })

    it('should set usb default policy and notify listener', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)
      let eventCount = 0
      let listenerId = PeripheralDevicePolicyRepository.addChangeListener(() => {
        eventCount++
      })

      let denyResult = await PeripheralDevicePolicyRepository.setUsbDefaultPolicy('deny')
      let allowResult = await PeripheralDevicePolicyRepository.setUsbDefaultPolicy('allow')

      expect(denyResult).assertTrue()
      expect(allowResult).assertTrue()
      expect(PeripheralDevicePolicyRepository.getUsbDefaultPolicy()).assertEqual('allow')
      expect(eventCount).assertEqual(2)
      PeripheralDevicePolicyRepository.removeChangeListener(listenerId)
    })

    it('should not notify removed listener', 0, async () => {
      await PeripheralDevicePolicyRepository.init(context)
      let eventCount = 0
      let listenerId = PeripheralDevicePolicyRepository.addChangeListener(() => {
        eventCount++
      })
      PeripheralDevicePolicyRepository.removeChangeListener(listenerId)

      await PeripheralDevicePolicyRepository.setUsbDefaultPolicy('deny')

      expect(eventCount).assertEqual(0)
    })

    it('should return false when saving usb default policy fails', 0, async () => {
      fakePref = new FakePreferencesAccessor('allow', true)
      await PeripheralDevicePolicyRepository.init(context)

      let result = await PeripheralDevicePolicyRepository.setUsbDefaultPolicy('deny')

      expect(result).assertFalse()
      expect(PeripheralDevicePolicyRepository.getUsbDefaultPolicy()).assertEqual('allow')
    })
  })
}

import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { PeripheralDevicePolicy } from '../../../models/PeripheralModels'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'

const TAG = 'PeripheralDevicePolicyRepo'
const PREF_STORE_NAME = 'peripheral_device_policy'
const PREF_KEY_USB_DEFAULT_POLICY = 'usb_default_policy'

interface DevicePolicyChangeEvent {
  totalCount: number
  timestamp: number
}

type DevicePolicyChangeListener = (event: DevicePolicyChangeEvent) => void

export class PeripheralDevicePolicyRepository {
  private static context: common.UIAbilityContext | null = null
  private static initPromise: Promise<boolean> | null = null
  private static initialized: boolean = false
  private static usbDefaultPolicy: PeripheralDevicePolicy = 'allow'
  private static nextListenerId: number = 1
  private static listeners: Map<number, DevicePolicyChangeListener> = new Map()
  private static nowProvider: () => number = () => Date.now()

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    PeripheralDevicePolicyRepository.context = context
    if (PeripheralDevicePolicyRepository.initialized) {
      return true
    }
    if (PeripheralDevicePolicyRepository.initPromise) {
      return PeripheralDevicePolicyRepository.initPromise
    }
    PeripheralDevicePolicyRepository.initPromise = PeripheralDevicePolicyRepository.doInit()
    const ok = await PeripheralDevicePolicyRepository.initPromise
    PeripheralDevicePolicyRepository.initPromise = null
    return ok
  }

  static resetForTest(): void {
    PeripheralDevicePolicyRepository.context = null
    PeripheralDevicePolicyRepository.initPromise = null
    PeripheralDevicePolicyRepository.initialized = false
    PeripheralDevicePolicyRepository.usbDefaultPolicy = 'allow'
    PeripheralDevicePolicyRepository.nextListenerId = 1
    PeripheralDevicePolicyRepository.listeners.clear()
  }

  static addChangeListener(listener: DevicePolicyChangeListener): number {
    const id = PeripheralDevicePolicyRepository.nextListenerId++
    PeripheralDevicePolicyRepository.listeners.set(id, listener)
    return id
  }

  static removeChangeListener(listenerId: number): void {
    PeripheralDevicePolicyRepository.listeners.delete(listenerId)
  }

  static getUsbDefaultPolicy(): PeripheralDevicePolicy {
    return PeripheralDevicePolicyRepository.usbDefaultPolicy
  }

  static isUsbDefaultDeny(): boolean {
    return PeripheralDevicePolicyRepository.usbDefaultPolicy === 'deny'
  }

  static async setUsbDefaultPolicy(policy: PeripheralDevicePolicy): Promise<boolean> {
    try {
      const normalized = PeripheralDevicePolicyRepository.normalizeUsbDefaultPolicy(policy)
      const saved = await PeripheralDevicePolicyRepository.saveUsbDefaultPolicy(normalized)
      if (!saved) {
        return false
      }
      PeripheralDevicePolicyRepository.usbDefaultPolicy = normalized
      PeripheralDevicePolicyRepository.notifyChanged()
      return true
    } catch (err) {
      LogUtils.error(TAG, `setUsbDefaultPolicy failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static async doInit(): Promise<boolean> {
    if (!PeripheralDevicePolicyRepository.context) {
      return false
    }
    try {
      let pref = PreferencesAccessor.of(PeripheralDevicePolicyRepository.context, PREF_STORE_NAME)
      const usbDefaultPolicy = await pref.getString(PREF_KEY_USB_DEFAULT_POLICY, 'allow')
      PeripheralDevicePolicyRepository.usbDefaultPolicy =
        PeripheralDevicePolicyRepository.normalizeUsbDefaultPolicy(usbDefaultPolicy)
      PeripheralDevicePolicyRepository.initialized = true
      return true
    } catch (err) {
      PeripheralDevicePolicyRepository.usbDefaultPolicy = 'allow'
      PeripheralDevicePolicyRepository.initialized = false
      LogUtils.error(TAG, `init failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static async saveUsbDefaultPolicy(policy: PeripheralDevicePolicy): Promise<boolean> {
    if (!PeripheralDevicePolicyRepository.context) {
      return false
    }
    try {
      let pref = PreferencesAccessor.of(PeripheralDevicePolicyRepository.context, PREF_STORE_NAME)
      return await pref.setValue(PREF_KEY_USB_DEFAULT_POLICY, policy)
    } catch (err) {
      LogUtils.error(TAG, `saveUsbDefaultPolicy failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static normalizeUsbDefaultPolicy(policy: string | PeripheralDevicePolicy): PeripheralDevicePolicy {
    return policy === 'deny' ? 'deny' : 'allow'
  }

  private static notifyChanged(): void {
    if (PeripheralDevicePolicyRepository.listeners.size <= 0) {
      return
    }
    const event: DevicePolicyChangeEvent = {
      totalCount: 0,
      timestamp: PeripheralDevicePolicyRepository.nowProvider()
    }
    PeripheralDevicePolicyRepository.listeners.forEach((listener: DevicePolicyChangeListener) => {
      try {
        listener(event)
      } catch (err) {
        LogUtils.warn(TAG, `listener failed: ${JSON.stringify(err)}`)
      }
    })
  }
}

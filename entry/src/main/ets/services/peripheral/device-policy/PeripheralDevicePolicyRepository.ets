import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import {
  normalizeDeviceId,
  PeripheralDevicePolicyRecord
} from '../../../models/PeripheralModels'
import { PreferencesAccessor } from '../../../storage/preferences/PreferencesAccessor'

const TAG = 'PeripheralDevicePolicyRepo'
const PREF_STORE_NAME = 'peripheral_device_policy'
const PREF_KEY_DEVICE_POLICIES = 'device_policies'
const PREF_KEY_USB_DEFAULT_POLICY = 'usb_default_policy'

export type PeripheralUsbDefaultPolicy = 'allow' | 'deny'

interface DevicePolicyChangeEvent {
  totalCount: number
  timestamp: number
}

type DevicePolicyChangeListener = (event: DevicePolicyChangeEvent) => void

export class PeripheralDevicePolicyRepository {
  private static context: common.UIAbilityContext | null = null
  private static initPromise: Promise<boolean> | null = null
  private static initialized: boolean = false
  private static records: PeripheralDevicePolicyRecord[] = []
  private static usbDefaultPolicy: PeripheralUsbDefaultPolicy = 'allow'
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
    PeripheralDevicePolicyRepository.records = []
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

  static getAll(): PeripheralDevicePolicyRecord[] {
    return PeripheralDevicePolicyRepository.records.map((item: PeripheralDevicePolicyRecord) => {
      return PeripheralDevicePolicyRepository.cloneRecord(item)
    })
  }

  static get(deviceId: string): PeripheralDevicePolicyRecord | null {
    const normalized = normalizeDeviceId(deviceId)
    const found = PeripheralDevicePolicyRepository.records.find((item: PeripheralDevicePolicyRecord) => {
      return normalizeDeviceId(item.deviceId) === normalized
    })
    return found ? PeripheralDevicePolicyRepository.cloneRecord(found) : null
  }

  static getUsbDefaultPolicy(): PeripheralUsbDefaultPolicy {
    return PeripheralDevicePolicyRepository.usbDefaultPolicy
  }

  static isUsbDefaultDeny(): boolean {
    return PeripheralDevicePolicyRepository.usbDefaultPolicy === 'deny'
  }

  static async setUsbDefaultPolicy(policy: PeripheralUsbDefaultPolicy): Promise<boolean> {
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

  static async set(record: PeripheralDevicePolicyRecord): Promise<boolean> {
    try {
      const normalized = PeripheralDevicePolicyRepository.normalizeRecord(record)
      const index = PeripheralDevicePolicyRepository.records.findIndex((item: PeripheralDevicePolicyRecord) => {
        return normalizeDeviceId(item.deviceId) === normalized.deviceId
      })
      if (index >= 0) {
        PeripheralDevicePolicyRepository.records[index] = normalized
      } else {
        PeripheralDevicePolicyRepository.records = [normalized, ...PeripheralDevicePolicyRepository.records]
      }
      await PeripheralDevicePolicyRepository.saveRecords()
      PeripheralDevicePolicyRepository.notifyChanged()
      return true
    } catch (err) {
      LogUtils.error(TAG, `set failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async remove(deviceId: string): Promise<boolean> {
    try {
      const normalized = normalizeDeviceId(deviceId)
      PeripheralDevicePolicyRepository.records = PeripheralDevicePolicyRepository.records.filter(
        (item: PeripheralDevicePolicyRecord) => normalizeDeviceId(item.deviceId) !== normalized
      )
      await PeripheralDevicePolicyRepository.saveRecords()
      PeripheralDevicePolicyRepository.notifyChanged()
      return true
    } catch (err) {
      LogUtils.error(TAG, `remove failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async clearAll(): Promise<boolean> {
    try {
      PeripheralDevicePolicyRepository.records = []
      await PeripheralDevicePolicyRepository.saveRecords()
      PeripheralDevicePolicyRepository.notifyChanged()
      return true
    } catch (err) {
      LogUtils.error(TAG, `clearAll failed: ${JSON.stringify(err)}`)
      return false
    }
  }
  private static async doInit(): Promise<boolean> {
    if (!PeripheralDevicePolicyRepository.context) {
      return false
    }
    try {
      let pref = PreferencesAccessor.of(PeripheralDevicePolicyRepository.context, PREF_STORE_NAME)
      const parsed = await pref.getJsonArray<PeripheralDevicePolicyRecord>(PREF_KEY_DEVICE_POLICIES, [])
      const usbDefaultPolicy = await pref.getString(PREF_KEY_USB_DEFAULT_POLICY, 'allow')
      PeripheralDevicePolicyRepository.records = Array.isArray(parsed)
        ? parsed.map((item: PeripheralDevicePolicyRecord) => PeripheralDevicePolicyRepository.normalizeRecord(item))
        : []
      PeripheralDevicePolicyRepository.usbDefaultPolicy =
        PeripheralDevicePolicyRepository.normalizeUsbDefaultPolicy(usbDefaultPolicy)
      PeripheralDevicePolicyRepository.initialized = true
      return true
    } catch (err) {
      PeripheralDevicePolicyRepository.records = []
      PeripheralDevicePolicyRepository.usbDefaultPolicy = 'allow'
      PeripheralDevicePolicyRepository.initialized = false
      LogUtils.error(TAG, `init failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static async saveRecords(): Promise<void> {
    if (!PeripheralDevicePolicyRepository.context) {
      return
    }
    try {
      let pref = PreferencesAccessor.of(PeripheralDevicePolicyRepository.context, PREF_STORE_NAME)
      await pref.setJson(PREF_KEY_DEVICE_POLICIES, PeripheralDevicePolicyRepository.records)
    } catch (err) {
      LogUtils.error(TAG, `saveRecords failed: ${JSON.stringify(err)}`)
    }
  }

  private static async saveUsbDefaultPolicy(policy: PeripheralUsbDefaultPolicy): Promise<boolean> {
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

  private static normalizeRecord(record: PeripheralDevicePolicyRecord): PeripheralDevicePolicyRecord {
    return {
      deviceId: normalizeDeviceId(record.deviceId),
      policy: record.policy === 'deny' ? 'deny' : 'allow',
      updatedAt: Number.isFinite(record.updatedAt) && record.updatedAt > 0
        ? Math.floor(record.updatedAt)
        : PeripheralDevicePolicyRepository.nowProvider(),
      deviceName: record.deviceName,
      deviceType: record.deviceType
    }
  }

  private static normalizeUsbDefaultPolicy(policy: string | PeripheralUsbDefaultPolicy): PeripheralUsbDefaultPolicy {
    return policy === 'deny' ? 'deny' : 'allow'
  }

  private static cloneRecord(record: PeripheralDevicePolicyRecord): PeripheralDevicePolicyRecord {
    return {
      deviceId: record.deviceId,
      policy: record.policy,
      updatedAt: record.updatedAt,
      deviceName: record.deviceName,
      deviceType: record.deviceType
    }
  }

  private static notifyChanged(): void {
    if (PeripheralDevicePolicyRepository.listeners.size <= 0) {
      return
    }
    const event: DevicePolicyChangeEvent = {
      totalCount: PeripheralDevicePolicyRepository.records.length,
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

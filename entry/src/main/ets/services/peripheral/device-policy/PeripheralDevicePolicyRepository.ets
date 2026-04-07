import { LogUtils } from '../../../utils/LogUtils'
import { preferences } from '@kit.ArkData'
import { common } from '@kit.AbilityKit'

import { PeripheralDevicePolicyRecord } from '../../../models/DataModels'

const TAG = 'PeripheralDevicePolicyRepo'
const PREF_STORE_NAME = 'peripheral_device_policy'
const PREF_KEY_DEVICE_POLICIES = 'device_policies'

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
    const normalized = PeripheralDevicePolicyRepository.normalizeDeviceId(deviceId)
    const found = PeripheralDevicePolicyRepository.records.find((item: PeripheralDevicePolicyRecord) => {
      return item.deviceId === normalized
    })
    return found ? PeripheralDevicePolicyRepository.cloneRecord(found) : null
  }

  static async set(record: PeripheralDevicePolicyRecord): Promise<boolean> {
    try {
      const normalized = PeripheralDevicePolicyRepository.normalizeRecord(record)
      const index = PeripheralDevicePolicyRepository.records.findIndex((item: PeripheralDevicePolicyRecord) => {
        return item.deviceId === normalized.deviceId
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
      const normalized = PeripheralDevicePolicyRepository.normalizeDeviceId(deviceId)
      PeripheralDevicePolicyRepository.records = PeripheralDevicePolicyRepository.records.filter(
        (item: PeripheralDevicePolicyRecord) => item.deviceId !== normalized
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

  static resetForTest(): void {
    PeripheralDevicePolicyRepository.context = null
    PeripheralDevicePolicyRepository.initPromise = null
    PeripheralDevicePolicyRepository.initialized = false
    PeripheralDevicePolicyRepository.records = []
    PeripheralDevicePolicyRepository.listeners = new Map()
    PeripheralDevicePolicyRepository.nextListenerId = 1
    PeripheralDevicePolicyRepository.nowProvider = () => Date.now()
  }

  static setRecordsForTest(records: PeripheralDevicePolicyRecord[]): void {
    PeripheralDevicePolicyRepository.records = records.map((item: PeripheralDevicePolicyRecord) => {
      return PeripheralDevicePolicyRepository.normalizeRecord(item)
    })
  }

  private static async doInit(): Promise<boolean> {
    if (!PeripheralDevicePolicyRepository.context) {
      return false
    }
    try {
      const store = await preferences.getPreferences(PeripheralDevicePolicyRepository.context, PREF_STORE_NAME)
      const raw = await store.get(PREF_KEY_DEVICE_POLICIES, '[]') as string
      const parsed = JSON.parse(raw) as PeripheralDevicePolicyRecord[]
      PeripheralDevicePolicyRepository.records = Array.isArray(parsed)
        ? parsed.map((item: PeripheralDevicePolicyRecord) => PeripheralDevicePolicyRepository.normalizeRecord(item))
        : []
      PeripheralDevicePolicyRepository.initialized = true
      return true
    } catch (err) {
      PeripheralDevicePolicyRepository.records = []
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
      const store = await preferences.getPreferences(PeripheralDevicePolicyRepository.context, PREF_STORE_NAME)
      await store.put(PREF_KEY_DEVICE_POLICIES, JSON.stringify(PeripheralDevicePolicyRepository.records))
      await store.flush()
    } catch (err) {
      LogUtils.error(TAG, `saveRecords failed: ${JSON.stringify(err)}`)
    }
  }

  private static normalizeRecord(record: PeripheralDevicePolicyRecord): PeripheralDevicePolicyRecord {
    return {
      deviceId: PeripheralDevicePolicyRepository.normalizeDeviceId(record.deviceId),
      policy: record.policy === 'deny' ? 'deny' : 'allow',
      updatedAt: Number.isFinite(record.updatedAt) && record.updatedAt > 0
        ? Math.floor(record.updatedAt)
        : PeripheralDevicePolicyRepository.nowProvider(),
      deviceName: record.deviceName,
      deviceType: record.deviceType
    }
  }

  private static normalizeDeviceId(deviceId: string): string {
    const value = (deviceId || '').trim().toUpperCase()
    return value.replace(/\s+/g, ' ')
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

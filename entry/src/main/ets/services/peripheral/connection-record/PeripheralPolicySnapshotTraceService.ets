import { usbManager } from '@kit.BasicServicesKit'
import { SecurityEventResult } from '../../../models/CommonModels'
import {
  PeripheralDevicePolicy,
  PeripheralDevicePolicySnapshotRequest,
  PeripheralTraceRecord,
  PeripheralType,
  UsbStoragePolicy,
  formatUsbDeviceId,
  inferPeripheralTypeFromBaseClass,
  parseUsbDeviceId
} from '../../../models/PeripheralModels'
import {
  PeripheralConnectionRecordStrings,
  PeripheralMatchedPolicyStrings
} from '../../../constants/modules/PeripheralStrings'
import { StatusText } from '../../../constants/StringCatalog'
import { LogUtils } from '../../../utils/LogUtils'
import { generateRandomSuffix } from '../../../utils/ValuePicker'
import {
  PeripheralTraceMaintenanceService,
  PeripheralTraceMutationResult
} from './PeripheralTraceMaintenanceService'
import { UsbDeviceNameResolver } from './UsbDeviceNameResolver'

const TAG = 'PeripheralPolicySnapshotTrace'
const USB_CLASS_HUB = 0x09

export interface UsbDeviceSnapshotProvider {
  getDevices(): usbManager.USBDevice[]
}

class BasicServicesUsbDeviceSnapshotProvider implements UsbDeviceSnapshotProvider {
  getDevices(): usbManager.USBDevice[] {
    try {
      return usbManager.getDevices() as usbManager.USBDevice[]
    } catch (err) {
      LogUtils.warn(TAG, `usbManager.getDevices failed: ${JSON.stringify(err)}`)
      return []
    }
  }
}

interface CurrentUsbDeviceSnapshot {
  vendorId: number
  productId: number
  baseClass: number
  subClass: number
  protocol: number
  deviceId: string
  deviceName: string
  deviceType: PeripheralType
  rawPayload: string
}

export class PeripheralPolicySnapshotTraceService {
  private static readonly defaultProvider: UsbDeviceSnapshotProvider = new BasicServicesUsbDeviceSnapshotProvider()
  private static provider: UsbDeviceSnapshotProvider = PeripheralPolicySnapshotTraceService.defaultProvider
  private static nowProvider: () => number = () => Date.now()

  static setUsbDeviceSnapshotProviderForTest(provider: UsbDeviceSnapshotProvider | null): void {
    PeripheralPolicySnapshotTraceService.provider = provider ?? PeripheralPolicySnapshotTraceService.defaultProvider
  }

  static setNowProviderForTest(nowProvider: (() => number) | null): void {
    PeripheralPolicySnapshotTraceService.nowProvider = nowProvider ?? (() => Date.now())
  }

  static resetForTest(): void {
    PeripheralPolicySnapshotTraceService.provider = PeripheralPolicySnapshotTraceService.defaultProvider
    PeripheralPolicySnapshotTraceService.nowProvider = () => Date.now()
  }

  static async appendUsbDefaultPolicySnapshot(policy: PeripheralDevicePolicy): Promise<PeripheralTraceMutationResult> {
    const devices = PeripheralPolicySnapshotTraceService.listCurrentUsbDevices()
    return PeripheralPolicySnapshotTraceService.appendSnapshotRecords(devices, policy, 'usb_default_policy')
  }

  static async appendDevicePolicySnapshot(record: PeripheralDevicePolicySnapshotRequest): Promise<PeripheralTraceMutationResult> {
    const target = parseUsbDeviceId(record.deviceId)
    if (!target) {
      return { success: true, code: 'ok' }
    }

    const devices = PeripheralPolicySnapshotTraceService.listCurrentUsbDevices()
    const matched = devices.filter((device: CurrentUsbDeviceSnapshot) => {
      return device.vendorId === target.vendorId && device.productId === target.productId
    })
    return PeripheralPolicySnapshotTraceService.appendSnapshotRecords(matched, record.policy, 'device_policy')
  }

  static async appendUsbStoragePolicySnapshot(policy: UsbStoragePolicy): Promise<PeripheralTraceMutationResult> {
    const devices = PeripheralPolicySnapshotTraceService.listCurrentUsbDevices().filter((device: CurrentUsbDeviceSnapshot) => {
      return device.deviceType === PeripheralType.USB_STORAGE
    })
    return PeripheralPolicySnapshotTraceService.appendUsbStoragePolicyRecords(devices, policy)
  }

  private static listCurrentUsbDevices(): CurrentUsbDeviceSnapshot[] {
    try {
      const rawDevices = PeripheralPolicySnapshotTraceService.provider.getDevices()
      const devices: CurrentUsbDeviceSnapshot[] = []
      for (const raw of rawDevices) {
        const device = PeripheralPolicySnapshotTraceService.toCurrentUsbDeviceSnapshot(raw)
        if (!device) {
          continue
        }
        devices.push(device)
      }
      return devices
    } catch (err) {
      LogUtils.warn(TAG, `listCurrentUsbDevices failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  private static toCurrentUsbDeviceSnapshot(device: usbManager.USBDevice): CurrentUsbDeviceSnapshot | null {
    const vendorId = PeripheralPolicySnapshotTraceService.normalizeNumber(device.vendorId)
    const productId = PeripheralPolicySnapshotTraceService.normalizeNumber(device.productId)
    if (!Number.isFinite(vendorId) || !Number.isFinite(productId) || vendorId < 0 || productId < 0) {
      return null
    }

    let baseClass = PeripheralPolicySnapshotTraceService.normalizeNumber(device.clazz)
    if (!Number.isFinite(baseClass) || baseClass <= 0) {
      baseClass = PeripheralPolicySnapshotTraceService.pickInterfaceClass(device)
    }
    if (baseClass === USB_CLASS_HUB) {
      return null
    }
    if (!Number.isFinite(baseClass) || baseClass <= 0) {
      return null
    }

    const subClass = PeripheralPolicySnapshotTraceService.normalizeNumber(device.subClass)
    const protocol = PeripheralPolicySnapshotTraceService.normalizeNumber(device.protocol)
    const deviceId = formatUsbDeviceId(vendorId, productId)
    const deviceName = UsbDeviceNameResolver.resolve({
      manufacturerName: device.manufacturerName,
      productName: device.productName
    }, PeripheralConnectionRecordStrings.USB_DEVICE)
    return {
      vendorId: vendorId,
      productId: productId,
      baseClass: baseClass,
      subClass: Number.isFinite(subClass) ? subClass : 0,
      protocol: Number.isFinite(protocol) ? protocol : 0,
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: inferPeripheralTypeFromBaseClass(baseClass),
      rawPayload: PeripheralPolicySnapshotTraceService.buildRawPayload(device)
    }
  }

  private static async appendSnapshotRecords(
    devices: CurrentUsbDeviceSnapshot[],
    policy: PeripheralDevicePolicy,
    reason: string
  ): Promise<PeripheralTraceMutationResult> {
    if (devices.length === 0) {
      return { success: true, code: 'ok' }
    }

    const now = PeripheralPolicySnapshotTraceService.nowProvider()
    const records = devices.map((device: CurrentUsbDeviceSnapshot) => {
      return PeripheralPolicySnapshotTraceService.buildTraceRecord(device, policy, reason, now)
    })
    const result = await PeripheralTraceMaintenanceService.appendEntries(records)
    if (!result.success) {
      LogUtils.warn(TAG, `append policy snapshot failed: code=${result.code}, reason=${reason}, count=${records.length}`)
    }
    return result
  }

  private static buildTraceRecord(
    device: CurrentUsbDeviceSnapshot,
    policy: PeripheralDevicePolicy,
    reason: string,
    occurAt: number
  ): PeripheralTraceRecord {
    const policyLabel = policy === 'deny' ? StatusText.DISABLED : StatusText.ENABLED
    return {
      recordId: `policy_snapshot_usb_${occurAt}_${PeripheralPolicySnapshotTraceService.sanitizeRecordKey(device.deviceId)}_${generateRandomSuffix()}`,
      occurAt: occurAt,
      collectAt: occurAt,
      deviceName: device.deviceName,
      deviceType: device.deviceType,
      deviceId: device.deviceId,
      action: 'discover',
      decision: policy,
      result: SecurityEventResult.SUCCESS,
      source: 'policy_snapshot',
      summary: PeripheralConnectionRecordStrings.POLICY_SNAPSHOT_SUMMARY,
      rawEventName: reason,
      rawAction: 'discover',
      rawPayload: device.rawPayload,
      detail: PeripheralConnectionRecordStrings.buildPolicySnapshotDetail(device.deviceId, policyLabel),
      effectivePolicyLabel: policyLabel,
      matchedPolicyKind: policy === 'deny' ? 'device_deny' : 'default_allow'
    }
  }

  private static async appendUsbStoragePolicyRecords(
    devices: CurrentUsbDeviceSnapshot[],
    policy: UsbStoragePolicy
  ): Promise<PeripheralTraceMutationResult> {
    if (devices.length === 0) {
      return { success: true, code: 'ok' }
    }

    const now = PeripheralPolicySnapshotTraceService.nowProvider()
    const records = devices.map((device: CurrentUsbDeviceSnapshot) => {
      return PeripheralPolicySnapshotTraceService.buildUsbStoragePolicyRecord(device, policy, now)
    })
    const result = await PeripheralTraceMaintenanceService.appendEntries(records)
    if (!result.success) {
      LogUtils.warn(TAG, `append usb storage policy snapshot failed: code=${result.code}, count=${records.length}`)
    }
    return result
  }

  private static buildUsbStoragePolicyRecord(
    device: CurrentUsbDeviceSnapshot,
    policy: UsbStoragePolicy,
    occurAt: number
  ): PeripheralTraceRecord {
    const disabled = policy === UsbStoragePolicy.DISABLED
    const readOnly = policy === UsbStoragePolicy.READ_ONLY
    const policyLabel = disabled ? StatusText.DISABLED : StatusText.ENABLED
    return {
      recordId: `policy_snapshot_usb_storage_${occurAt}_${PeripheralPolicySnapshotTraceService.sanitizeRecordKey(device.deviceId)}_${generateRandomSuffix()}`,
      occurAt: occurAt,
      collectAt: occurAt,
      deviceName: device.deviceName,
      deviceType: device.deviceType,
      deviceId: device.deviceId,
      action: 'discover',
      decision: disabled ? 'deny' : 'allow',
      result: disabled ? SecurityEventResult.BLOCKED : SecurityEventResult.SUCCESS,
      source: 'policy_snapshot',
      summary: disabled ? PeripheralMatchedPolicyStrings.USB_STORAGE_DISABLED :
        (readOnly ? PeripheralMatchedPolicyStrings.USB_STORAGE_READ_ONLY : PeripheralConnectionRecordStrings.DEFAULT_ALLOW),
      rawEventName: 'usb_storage_policy',
      rawAction: 'discover',
      rawPayload: device.rawPayload,
      detail: disabled ? PeripheralConnectionRecordStrings.USB_STORAGE_DISABLED_DETAIL :
        (readOnly ? PeripheralConnectionRecordStrings.USB_STORAGE_READ_ONLY_DETAIL : PeripheralConnectionRecordStrings.DEFAULT_ALLOW_DETAIL),
      usbPolicy: policy,
      effectivePolicyLabel: policyLabel,
      matchedPolicyKind: disabled ? 'usb_storage_disabled' : (readOnly ? 'usb_storage_read_only' : 'default_allow')
    }
  }

  private static buildRawPayload(device: usbManager.USBDevice): string {
    try {
      return JSON.stringify({
        source: 'usbManager.getDevices',
        name: device.name,
        manufacturerName: device.manufacturerName,
        productName: device.productName,
        vendorId: device.vendorId,
        productId: device.productId,
        clazz: device.clazz,
        subClass: device.subClass,
        protocol: device.protocol
      })
    } catch (_err) {
      return ''
    }
  }

  private static pickInterfaceClass(device: usbManager.USBDevice): number {
    const configs = device.configs ?? []
    for (const config of configs) {
      const interfaces = config.interfaces ?? []
      for (const item of interfaces) {
        const clazz = PeripheralPolicySnapshotTraceService.normalizeNumber(item.clazz)
        if (Number.isFinite(clazz) && clazz > 0) {
          return clazz
        }
      }
    }
    return Number.NaN
  }

  private static normalizeNumber(value: number | undefined): number {
    if (typeof value !== 'number') {
      return Number.NaN
    }
    return Number.isFinite(value) ? value : Number.NaN
  }

  private static sanitizeRecordKey(value: string): string {
    return value.replace(/[^0-9A-Za-z]/g, '').toUpperCase()
  }
}

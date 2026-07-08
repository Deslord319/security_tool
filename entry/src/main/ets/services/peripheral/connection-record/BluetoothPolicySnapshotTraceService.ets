import { BusinessError } from '@kit.BasicServicesKit'
import { connection } from '@kit.ConnectivityKit'
import { SecurityEventResult } from '../../../models/CommonModels'
import {
  PeripheralTraceRecord,
  PeripheralType,
  formatBluetoothDeviceId
} from '../../../models/PeripheralModels'
import { PeripheralConnectionRecordStrings } from '../../../constants/modules/PeripheralStrings'
import { StatusText } from '../../../constants/StringCatalog'
import { LogUtils } from '../../../utils/LogUtils'
import { generateRandomSuffix } from '../../../utils/ValuePicker'
import {
  PeripheralTraceMaintenanceService,
  PeripheralTraceMutationResult
} from './PeripheralTraceMaintenanceService'

const TAG = 'BluetoothPolicySnapshot'

export interface BluetoothConnectedDeviceSnapshot {
  rawDeviceId: string
  deviceId: string
  deviceName: string
  rawPayload: string
}

export class BluetoothPolicySnapshotTraceService {
  private static nowProvider: () => number = () => Date.now()
  private static runtimeConnectedSnapshots: Map<string, BluetoothConnectedDeviceSnapshot> = new Map<string, BluetoothConnectedDeviceSnapshot>()
  private static deviceNameCache: Map<string, string> = new Map<string, string>()

  static setNowProviderForTest(nowProvider: (() => number) | null): void {
    BluetoothPolicySnapshotTraceService.nowProvider = nowProvider ?? (() => Date.now())
  }

  static resetForTest(): void {
    BluetoothPolicySnapshotTraceService.nowProvider = () => Date.now()
    BluetoothPolicySnapshotTraceService.runtimeConnectedSnapshots.clear()
    BluetoothPolicySnapshotTraceService.deviceNameCache.clear()
  }

  static captureCurrentConnectedDevices(): BluetoothConnectedDeviceSnapshot[] {
    const runtimeSnapshots = Array.from(BluetoothPolicySnapshotTraceService.runtimeConnectedSnapshots.values())
    LogUtils.info(TAG, `captured bluetooth connected device snapshots from acl cache: count=${runtimeSnapshots.length}`)
    return runtimeSnapshots
  }

  static async appendBluetoothDisabledPolicySnapshotForCachedDevices(
    beforeSnapshots: BluetoothConnectedDeviceSnapshot[]
  ): Promise<PeripheralTraceMutationResult> {
    if (beforeSnapshots.length === 0) {
      LogUtils.info(TAG, 'skip bluetooth policy snapshot append: no cached connected devices before policy')
      return { success: true, code: 'ok' }
    }

    LogUtils.info(TAG, `append bluetooth policy snapshot from acl cache: count=${beforeSnapshots.length}`)
    const result = await BluetoothPolicySnapshotTraceService.appendBluetoothDisabledPolicySnapshot(beforeSnapshots)
    if (result.success) {
      for (const snapshot of beforeSnapshots) {
        BluetoothPolicySnapshotTraceService.forgetRuntimeConnectedDevice(snapshot.deviceId)
      }
    }
    return result
  }

  static rememberRuntimeConnectedDevice(rawDeviceId: string, rawPayload: string, preferredDeviceName?: string): void {
    const normalizedRawId = BluetoothPolicySnapshotTraceService.normalizeRawDeviceId(rawDeviceId)
    if (normalizedRawId.length === 0) {
      return
    }
    const deviceId = formatBluetoothDeviceId(normalizedRawId)
    const deviceName = BluetoothPolicySnapshotTraceService.isValidBluetoothDeviceName(preferredDeviceName ?? '')
      ? (preferredDeviceName ?? '').trim()
      : BluetoothPolicySnapshotTraceService.resolveBluetoothDeviceName(normalizedRawId)
    BluetoothPolicySnapshotTraceService.rememberBluetoothDeviceName(deviceId, deviceName)
    BluetoothPolicySnapshotTraceService.runtimeConnectedSnapshots.set(deviceId, {
      rawDeviceId: normalizedRawId,
      deviceId: deviceId,
      deviceName: deviceName,
      rawPayload: rawPayload
    })
  }

  static rememberBluetoothDeviceName(deviceId: string, deviceName: string): void {
    if (!BluetoothPolicySnapshotTraceService.isValidBluetoothDeviceName(deviceName)) {
      return
    }
    const normalized = BluetoothPolicySnapshotTraceService.normalizeTraceDeviceId(deviceId)
    if (normalized.length > 0) {
      BluetoothPolicySnapshotTraceService.deviceNameCache.set(normalized, deviceName.trim())
    }
  }

  static resolveCachedBluetoothDeviceName(deviceId: string): string {
    const normalized = BluetoothPolicySnapshotTraceService.normalizeTraceDeviceId(deviceId)
    if (normalized.length === 0) {
      return ''
    }
    return BluetoothPolicySnapshotTraceService.deviceNameCache.get(normalized) ?? ''
  }

  static forgetRuntimeConnectedDevice(deviceId: string): void {
    const normalized = BluetoothPolicySnapshotTraceService.normalizeTraceDeviceId(deviceId)
    if (normalized.length > 0) {
      BluetoothPolicySnapshotTraceService.runtimeConnectedSnapshots.delete(normalized)
    }
  }

  static async appendBluetoothDisabledPolicySnapshot(
    snapshots: BluetoothConnectedDeviceSnapshot[]
  ): Promise<PeripheralTraceMutationResult> {
    if (snapshots.length === 0) {
      LogUtils.info(TAG, 'skip bluetooth policy snapshot append: no connected devices captured')
      return { success: true, code: 'ok' }
    }

    const now = BluetoothPolicySnapshotTraceService.nowProvider()
    const records = snapshots.map((snapshot: BluetoothConnectedDeviceSnapshot) => {
      return BluetoothPolicySnapshotTraceService.buildTraceRecord(snapshot, now)
    })
    const result = await PeripheralTraceMaintenanceService.appendEntries(records)
    if (!result.success) {
      LogUtils.warn(TAG, `append bluetooth policy snapshot failed: code=${result.code}, count=${records.length}`)
    }
    return result
  }

  static normalizeRawDeviceId(deviceId: string): string {
    return (deviceId ?? '').trim().replace(/-/g, ':').toUpperCase()
  }

  private static buildTraceRecord(
    snapshot: BluetoothConnectedDeviceSnapshot,
    occurAt: number
  ): PeripheralTraceRecord {
    return {
      recordId: `policy_snapshot_bluetooth_${occurAt}_${BluetoothPolicySnapshotTraceService.sanitizeRecordKey(snapshot.deviceId)}_${generateRandomSuffix()}`,
      occurAt: occurAt,
      collectAt: occurAt,
      deviceName: snapshot.deviceName,
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: snapshot.deviceId,
      action: 'discover',
      decision: 'deny',
      result: SecurityEventResult.BLOCKED,
      source: 'policy_snapshot',
      summary: PeripheralConnectionRecordStrings.BLUETOOTH_POLICY_SNAPSHOT_SUMMARY,
      rawEventName: 'bluetooth_global_policy',
      rawAction: 'discover',
      rawPayload: snapshot.rawPayload,
      detail: PeripheralConnectionRecordStrings.buildBluetoothPolicySnapshotDetail(snapshot.deviceId, StatusText.DISABLED),
      effectivePolicyLabel: StatusText.DISABLED,
      matchedPolicyKind: 'bluetooth_disabled'
    }
  }

  private static normalizeTraceDeviceId(deviceId: string): string {
    const normalized = (deviceId ?? '').trim().toUpperCase()
    if (normalized.startsWith('MAC:')) {
      return normalized.replace(/\s+/g, ' ')
    }
    const raw = BluetoothPolicySnapshotTraceService.normalizeRawDeviceId(normalized)
    return raw.length > 0 ? formatBluetoothDeviceId(raw) : ''
  }

  private static resolveBluetoothDeviceName(deviceId: string): string {
    const remoteName = BluetoothPolicySnapshotTraceService.queryRemoteDeviceName(deviceId)
    if (BluetoothPolicySnapshotTraceService.isValidBluetoothDeviceName(remoteName)) {
      BluetoothPolicySnapshotTraceService.rememberBluetoothDeviceName(deviceId, remoteName)
      return remoteName
    }
    const cachedName = BluetoothPolicySnapshotTraceService.resolveCachedBluetoothDeviceName(deviceId)
    if (cachedName.length > 0) {
      return cachedName
    }
    return PeripheralConnectionRecordStrings.UNNAMED_BLUETOOTH
  }

  private static isValidBluetoothDeviceName(deviceName: string): boolean {
    const normalized = (deviceName ?? '').trim()
    return normalized.length > 0 && normalized !== PeripheralConnectionRecordStrings.UNNAMED_BLUETOOTH
  }

  private static queryRemoteDeviceName(deviceId: string): string {
    try {
      return connection.getRemoteDeviceName(deviceId, false)?.trim() ?? ''
    } catch (err) {
      const error = err as BusinessError
      LogUtils.warn(
        TAG,
        `getRemoteDeviceName failed: deviceId=${BluetoothPolicySnapshotTraceService.maskBluetoothIdentifier(deviceId)}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      return ''
    }
  }

  private static maskBluetoothIdentifier(deviceId: string): string {
    const segments = deviceId.trim().replace(/-/g, ':').split(':').filter((item: string) => item.length > 0)
    if (segments.length < 2) {
      return 'unknown'
    }
    return `**:**:**:**:${segments[segments.length - 2]}:${segments[segments.length - 1]}`
  }

  private static sanitizeRecordKey(value: string): string {
    return value.replace(/[^0-9A-Za-z]/g, '').toUpperCase()
  }
}

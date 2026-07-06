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
const SUPPRESS_TTL_MS = 30000

export interface BluetoothConnectedDeviceSnapshot {
  rawDeviceId: string
  deviceId: string
  deviceName: string
  rawPayload: string
}

export class BluetoothPolicySnapshotTraceService {
  private static nowProvider: () => number = () => Date.now()
  private static suppressedDisconnects: Map<string, number> = new Map<string, number>()
  private static runtimeConnectedSnapshots: Map<string, BluetoothConnectedDeviceSnapshot> = new Map<string, BluetoothConnectedDeviceSnapshot>()

  static setNowProviderForTest(nowProvider: (() => number) | null): void {
    BluetoothPolicySnapshotTraceService.nowProvider = nowProvider ?? (() => Date.now())
  }

  static resetForTest(): void {
    BluetoothPolicySnapshotTraceService.nowProvider = () => Date.now()
    BluetoothPolicySnapshotTraceService.suppressedDisconnects.clear()
    BluetoothPolicySnapshotTraceService.runtimeConnectedSnapshots.clear()
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

  static rememberRuntimeConnectedDevice(rawDeviceId: string, deviceName: string, rawPayload: string): void {
    const normalizedRawId = BluetoothPolicySnapshotTraceService.normalizeRawDeviceId(rawDeviceId)
    if (normalizedRawId.length === 0) {
      return
    }
    const deviceId = formatBluetoothDeviceId(normalizedRawId)
    const resolvedDeviceName = (deviceName ?? '').trim().length > 0
      ? deviceName.trim()
      : BluetoothPolicySnapshotTraceService.resolveBluetoothDeviceName(normalizedRawId)
    BluetoothPolicySnapshotTraceService.runtimeConnectedSnapshots.set(deviceId, {
      rawDeviceId: normalizedRawId,
      deviceId: deviceId,
      deviceName: resolvedDeviceName,
      rawPayload: rawPayload
    })
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
    if (result.success) {
      BluetoothPolicySnapshotTraceService.registerSuppressedDisconnects(snapshots, now)
    } else {
      LogUtils.warn(TAG, `append bluetooth policy snapshot failed: code=${result.code}, count=${records.length}`)
    }
    return result
  }

  static shouldSuppressPolicyDisconnect(deviceId: string): boolean {
    BluetoothPolicySnapshotTraceService.pruneSuppressedDisconnects()
    const normalized = BluetoothPolicySnapshotTraceService.normalizeTraceDeviceId(deviceId)
    if (normalized.length === 0) {
      return false
    }
    if (!BluetoothPolicySnapshotTraceService.suppressedDisconnects.has(normalized)) {
      return false
    }
    BluetoothPolicySnapshotTraceService.suppressedDisconnects.delete(normalized)
    return true
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

  private static registerSuppressedDisconnects(snapshots: BluetoothConnectedDeviceSnapshot[], now: number): void {
    const expiresAt = now + SUPPRESS_TTL_MS
    for (const snapshot of snapshots) {
      const normalized = BluetoothPolicySnapshotTraceService.normalizeTraceDeviceId(snapshot.deviceId)
      if (normalized.length > 0) {
        BluetoothPolicySnapshotTraceService.suppressedDisconnects.set(normalized, expiresAt)
      }
    }
  }

  private static pruneSuppressedDisconnects(): void {
    const now = BluetoothPolicySnapshotTraceService.nowProvider()
    const expired: string[] = []
    BluetoothPolicySnapshotTraceService.suppressedDisconnects.forEach((expiresAt: number, deviceId: string) => {
      if (expiresAt < now) {
        expired.push(deviceId)
      }
    })
    for (const deviceId of expired) {
      BluetoothPolicySnapshotTraceService.suppressedDisconnects.delete(deviceId)
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
    const aliasName = BluetoothPolicySnapshotTraceService.queryRemoteDeviceName(deviceId, true)
    if (aliasName.length > 0) {
      return aliasName
    }
    const remoteName = BluetoothPolicySnapshotTraceService.queryRemoteDeviceName(deviceId, false)
    if (remoteName.length > 0) {
      return remoteName
    }
    return PeripheralConnectionRecordStrings.UNNAMED_BLUETOOTH
  }

  private static queryRemoteDeviceName(deviceId: string, alias: boolean): string {
    try {
      return connection.getRemoteDeviceName(deviceId, alias)?.trim() ?? ''
    } catch (err) {
      const error = err as BusinessError
      LogUtils.warn(
        TAG,
        `getRemoteDeviceName failed: deviceId=${BluetoothPolicySnapshotTraceService.maskBluetoothIdentifier(deviceId)}, alias=${alias}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
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

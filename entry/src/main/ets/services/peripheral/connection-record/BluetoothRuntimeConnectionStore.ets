import { BusinessError } from '@kit.BasicServicesKit'
import { connection } from '@kit.ConnectivityKit'
import { formatBluetoothDeviceId } from '../../../models/PeripheralModels'
import { PeripheralConnectionRecordStrings } from '../../../constants/modules/PeripheralStrings'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'BluetoothRuntimeStore'

export interface BluetoothConnectedDeviceSnapshot {
  rawDeviceId: string
  deviceId: string
  deviceName: string
  rawPayload: string
}

export class BluetoothRuntimeConnectionStore {
  private static connectedSnapshots: Map<string, BluetoothConnectedDeviceSnapshot> =
    new Map<string, BluetoothConnectedDeviceSnapshot>()
  private static deviceNameCache: Map<string, string> = new Map<string, string>()
  private static pendingDisabledDisconnects: Set<string> = new Set<string>()
  private static remoteDeviceNameProviderForTest: ((deviceId: string) => string) | null = null

  static setRemoteDeviceNameProviderForTest(provider: ((deviceId: string) => string) | null): void {
    BluetoothRuntimeConnectionStore.remoteDeviceNameProviderForTest = provider
  }

  static resetForTest(): void {
    BluetoothRuntimeConnectionStore.connectedSnapshots.clear()
    BluetoothRuntimeConnectionStore.deviceNameCache.clear()
    BluetoothRuntimeConnectionStore.pendingDisabledDisconnects.clear()
    BluetoothRuntimeConnectionStore.remoteDeviceNameProviderForTest = null
  }

  static captureConnectedDevices(): BluetoothConnectedDeviceSnapshot[] {
    const snapshots = Array.from(BluetoothRuntimeConnectionStore.connectedSnapshots.values())
    LogUtils.info(TAG, `captured bluetooth connected device snapshots from acl cache: count=${snapshots.length}`)
    return snapshots
  }

  static trackConnectedDevice(
    rawDeviceId: string,
    rawPayload: string,
    resolvedDeviceName: string
  ): BluetoothConnectedDeviceSnapshot | null {
    const normalizedRawId = BluetoothRuntimeConnectionStore.normalizeRawDeviceId(rawDeviceId)
    if (normalizedRawId.length === 0) {
      return null
    }
    const deviceId = formatBluetoothDeviceId(normalizedRawId)
    BluetoothRuntimeConnectionStore.pendingDisabledDisconnects.delete(deviceId)
    const deviceName = BluetoothRuntimeConnectionStore.isValidDeviceName(resolvedDeviceName)
      ? resolvedDeviceName.trim()
      : ''
    if (deviceName.length > 0) {
      BluetoothRuntimeConnectionStore.rememberDeviceName(deviceId, deviceName)
    }
    const snapshot: BluetoothConnectedDeviceSnapshot = {
      rawDeviceId: normalizedRawId,
      deviceId: deviceId,
      deviceName: deviceName,
      rawPayload: rawPayload
    }
    BluetoothRuntimeConnectionStore.connectedSnapshots.set(deviceId, snapshot)
    return snapshot
  }

  static forgetConnectedDevice(deviceId: string): void {
    const normalized = BluetoothRuntimeConnectionStore.normalizeTraceDeviceId(deviceId)
    if (normalized.length > 0) {
      BluetoothRuntimeConnectionStore.connectedSnapshots.delete(normalized)
    }
  }

  static hasConnectedDevice(deviceId: string): boolean {
    const normalized = BluetoothRuntimeConnectionStore.normalizeTraceDeviceId(deviceId)
    return normalized.length > 0 && BluetoothRuntimeConnectionStore.connectedSnapshots.has(normalized)
  }

  static markDisabledDisconnectPending(deviceId: string): void {
    const normalized = BluetoothRuntimeConnectionStore.normalizeTraceDeviceId(deviceId)
    if (normalized.length > 0) {
      BluetoothRuntimeConnectionStore.pendingDisabledDisconnects.add(normalized)
    }
  }

  static clearDisabledDisconnectPending(deviceId: string): void {
    const normalized = BluetoothRuntimeConnectionStore.normalizeTraceDeviceId(deviceId)
    if (normalized.length > 0) {
      BluetoothRuntimeConnectionStore.pendingDisabledDisconnects.delete(normalized)
    }
  }

  static clearAllDisabledDisconnectPending(): void {
    BluetoothRuntimeConnectionStore.pendingDisabledDisconnects.clear()
  }

  static consumeDisabledDisconnectPending(deviceId: string): boolean {
    const normalized = BluetoothRuntimeConnectionStore.normalizeTraceDeviceId(deviceId)
    if (normalized.length === 0 || !BluetoothRuntimeConnectionStore.pendingDisabledDisconnects.has(normalized)) {
      return false
    }
    BluetoothRuntimeConnectionStore.pendingDisabledDisconnects.delete(normalized)
    return true
  }

  static queryAndCacheDeviceName(deviceId: string): string {
    const remoteName = BluetoothRuntimeConnectionStore.queryRemoteDeviceName(deviceId)
    if (BluetoothRuntimeConnectionStore.isValidDeviceName(remoteName)) {
      BluetoothRuntimeConnectionStore.rememberDeviceName(deviceId, remoteName)
      BluetoothRuntimeConnectionStore.refreshConnectedSnapshotName(deviceId, remoteName)
      return remoteName
    }
    return ''
  }

  static getCachedDeviceName(deviceId: string): string {
    const normalized = BluetoothRuntimeConnectionStore.normalizeTraceDeviceId(deviceId)
    const snapshotName = normalized.length > 0
      ? (BluetoothRuntimeConnectionStore.connectedSnapshots.get(normalized)?.deviceName ?? '')
      : ''
    if (BluetoothRuntimeConnectionStore.isValidDeviceName(snapshotName)) {
      return snapshotName.trim()
    }
    return BluetoothRuntimeConnectionStore.resolveCachedDeviceName(deviceId)
  }

  static isValidResolvedDeviceName(deviceName: string): boolean {
    return BluetoothRuntimeConnectionStore.isValidDeviceName(deviceName)
  }

  static normalizeRawDeviceId(deviceId: string): string {
    return (deviceId ?? '').trim().replace(/-/g, ':').toUpperCase()
  }

  private static rememberDeviceName(deviceId: string, deviceName: string): void {
    if (!BluetoothRuntimeConnectionStore.isValidDeviceName(deviceName)) {
      return
    }
    const normalized = BluetoothRuntimeConnectionStore.normalizeTraceDeviceId(deviceId)
    if (normalized.length > 0) {
      BluetoothRuntimeConnectionStore.deviceNameCache.set(normalized, deviceName.trim())
    }
  }

  private static resolveCachedDeviceName(deviceId: string): string {
    const normalized = BluetoothRuntimeConnectionStore.normalizeTraceDeviceId(deviceId)
    return normalized.length > 0 ? (BluetoothRuntimeConnectionStore.deviceNameCache.get(normalized) ?? '') : ''
  }

  private static refreshConnectedSnapshotName(deviceId: string, deviceName: string): void {
    if (!BluetoothRuntimeConnectionStore.isValidDeviceName(deviceName)) {
      return
    }
    const normalized = BluetoothRuntimeConnectionStore.normalizeTraceDeviceId(deviceId)
    const snapshot = normalized.length > 0
      ? BluetoothRuntimeConnectionStore.connectedSnapshots.get(normalized)
      : undefined
    if (!snapshot) {
      return
    }
    BluetoothRuntimeConnectionStore.connectedSnapshots.set(normalized, {
      rawDeviceId: snapshot.rawDeviceId,
      deviceId: snapshot.deviceId,
      deviceName: deviceName.trim(),
      rawPayload: snapshot.rawPayload
    })
  }

  private static normalizeTraceDeviceId(deviceId: string): string {
    const normalized = (deviceId ?? '').trim().toUpperCase()
    if (normalized.startsWith('MAC:')) {
      return normalized.replace(/\s+/g, ' ')
    }
    const raw = BluetoothRuntimeConnectionStore.normalizeRawDeviceId(normalized)
    return raw.length > 0 ? formatBluetoothDeviceId(raw) : ''
  }

  private static isValidDeviceName(deviceName: string): boolean {
    const normalized = (deviceName ?? '').trim()
    return normalized.length > 0 &&
      normalized !== PeripheralConnectionRecordStrings.BLUETOOTH_DEVICE
  }

  private static queryRemoteDeviceName(deviceId: string): string {
    try {
      const provider = BluetoothRuntimeConnectionStore.remoteDeviceNameProviderForTest
      if (provider) {
        return provider(deviceId)?.trim() ?? ''
      }
      return connection.getRemoteDeviceName(deviceId, false)?.trim() ?? ''
    } catch (err) {
      const error = err as BusinessError
      LogUtils.warn(
        TAG,
        `getRemoteDeviceName failed: deviceId=${BluetoothRuntimeConnectionStore.maskIdentifier(deviceId)}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      return ''
    }
  }

  private static maskIdentifier(deviceId: string): string {
    const segments = deviceId.trim().replace(/-/g, ':').split(':').filter((item: string) => item.length > 0)
    if (segments.length < 2) {
      return 'unknown'
    }
    return `**:**:**:**:${segments[segments.length - 2]}:${segments[segments.length - 1]}`
  }
}

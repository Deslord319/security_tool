import { SecurityEventResult } from '../../../models/CommonModels'
import { PeripheralTraceRecord, PeripheralType } from '../../../models/PeripheralModels'
import { PeripheralConnectionRecordStrings } from '../../../constants/modules/PeripheralStrings'
import { StatusText } from '../../../constants/StringCatalog'
import { LogUtils } from '../../../utils/LogUtils'
import { generateRandomSuffix } from '../../../utils/ValuePicker'
import {
  PeripheralTraceMaintenanceService,
  PeripheralTraceMutationResult
} from './PeripheralTraceMaintenanceService'
import {
  BluetoothConnectedDeviceSnapshot,
  BluetoothRuntimeConnectionStore
} from './BluetoothRuntimeConnectionStore'

const TAG = 'BluetoothPolicySnapshot'

export class BluetoothPolicySnapshotTraceService {
  private static nowProvider: () => number = () => Date.now()

  static setNowProviderForTest(nowProvider: (() => number) | null): void {
    BluetoothPolicySnapshotTraceService.nowProvider = nowProvider ?? (() => Date.now())
  }

  static resetForTest(): void {
    BluetoothPolicySnapshotTraceService.nowProvider = () => Date.now()
  }

  static async appendBluetoothDisabledPolicySnapshot(
    beforeSnapshots: BluetoothConnectedDeviceSnapshot[]
  ): Promise<PeripheralTraceMutationResult> {
    if (beforeSnapshots.length === 0) {
      LogUtils.info(TAG, 'skip bluetooth policy snapshot append: no cached connected devices before policy')
      return { success: true, code: 'ok' }
    }

    LogUtils.info(TAG, `append bluetooth policy snapshot from acl cache: count=${beforeSnapshots.length}`)
    const now = BluetoothPolicySnapshotTraceService.nowProvider()
    const records = beforeSnapshots.map((snapshot: BluetoothConnectedDeviceSnapshot) => {
      return BluetoothPolicySnapshotTraceService.buildTraceRecord(snapshot, now)
    })
    const result = await PeripheralTraceMaintenanceService.appendEntries(records)
    if (!result.success) {
      LogUtils.warn(TAG, `append bluetooth policy snapshot failed: code=${result.code}, count=${records.length}`)
    }
    if (result.success) {
      for (const snapshot of beforeSnapshots) {
        BluetoothRuntimeConnectionStore.forgetConnectedDevice(snapshot.deviceId)
      }
    }
    return result
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

  private static sanitizeRecordKey(value: string): string {
    return value.replace(/[^0-9A-Za-z]/g, '').toUpperCase()
  }
}

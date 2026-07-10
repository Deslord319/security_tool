import { BusinessError } from '@kit.BasicServicesKit'
import { connection } from '@kit.ConnectivityKit'
import { SecurityEventResult } from '../../../models/CommonModels'
import { PeripheralType, formatBluetoothDeviceId } from '../../../models/PeripheralModels'
import { LogUtils } from '../../../utils/LogUtils'
import { PLACEHOLDER_TEXT, StatusText } from '../../../constants/StringCatalog'
import { PeripheralConnectionRecordStrings } from '../../../constants/modules/PeripheralStrings'
import { generateRandomSuffix } from '../../../utils/ValuePicker'
import {
  PeripheralConnectionAction,
  PeripheralConnectionRecordConsumeResult,
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent
} from './PeripheralConnectionRecordProducerContract'
import { BluetoothPolicySnapshotTraceService } from './BluetoothPolicySnapshotTraceService'

const TAG = 'ConnectionRecordBtConsumer'

interface BluetoothAclEventInfo {
  occurAt: number
  deviceId: string
  rawDeviceId: string
  deviceName: string
  action: PeripheralConnectionAction
  stateLabel: string
  rawPayload: string
}

export class PeripheralConnectionRecordBluetoothAclConsumer implements PeripheralConnectionRecordConsumer {
  private static remoteDeviceNameProviderForTest: ((deviceId: string) => string) | null = null

  static setRemoteDeviceNameProviderForTest(provider: ((deviceId: string) => string) | null): void {
    PeripheralConnectionRecordBluetoothAclConsumer.remoteDeviceNameProviderForTest = provider
  }

  canHandle(event: PeripheralConnectionRecordProducerEvent): boolean {
    return event.channel === 'bluetooth_acl'
  }

  async consume(event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralConnectionRecordConsumeResult> {
    if (!this.canHandle(event)) {
      return null
    }

    const eventInfo = PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothAclEventInfo(event)
    if (!eventInfo) {
      return null
    }
    if (eventInfo.action === 'connect') {
      BluetoothPolicySnapshotTraceService.rememberRuntimeConnectedDevice(
        eventInfo.rawDeviceId,
        eventInfo.rawPayload,
        eventInfo.deviceName
      )
    } else {
      BluetoothPolicySnapshotTraceService.forgetRuntimeConnectedDevice(eventInfo.deviceId)
    }

    return {
      recordId: `runtime_bt_acl_${eventInfo.occurAt}_${generateRandomSuffix()}`,
      occurAt: eventInfo.occurAt,
      collectAt: Date.now(),
      deviceName: eventInfo.deviceName,
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: eventInfo.deviceId,
      action: eventInfo.action,
      decision: 'allow',
      result: SecurityEventResult.SUCCESS,
      source: 'runtime_event',
      summary: eventInfo.action === 'connect'
        ? PeripheralConnectionRecordStrings.BLUETOOTH_CONNECTED
        : PeripheralConnectionRecordStrings.BLUETOOTH_DISCONNECTED,
      rawEventName: event.eventName,
      rawAction: eventInfo.action,
      rawPayload: eventInfo.rawPayload,
      detail: `aclState=${eventInfo.stateLabel}, reason=${PLACEHOLDER_TEXT}`,
      effectivePolicyLabel: StatusText.ENABLED,
      matchedPolicyKind: 'bluetooth_connection_event'
    }
  }

  private static resolveBluetoothAclEventInfo(
    event: PeripheralConnectionRecordProducerEvent
  ): BluetoothAclEventInfo | null {
    const payload = event.bluetoothAcl
    if (!payload || (payload.action !== 'connect' && payload.action !== 'disconnect')) {
      return null
    }
    const rawDeviceId = (payload.deviceId ?? '').trim()
    if (rawDeviceId.length === 0) {
      LogUtils.warn(TAG, 'skip bluetooth acl event: real deviceId missing')
      return null
    }

    let rawPayload = ''
    try {
      rawPayload = JSON.stringify(payload)
    } catch (_err) {
      rawPayload = ''
    }
    return {
      occurAt: Number.isFinite(payload.occurAt) && payload.occurAt > 0 ? payload.occurAt : Date.now(),
      deviceId: formatBluetoothDeviceId(rawDeviceId),
      rawDeviceId: rawDeviceId,
      deviceName: PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothDeviceName(rawDeviceId),
      action: payload.action,
      stateLabel: payload.action === 'connect' ? 'STATE_CONNECTED' : 'STATE_DISCONNECTED',
      rawPayload: rawPayload
    }
  }

  private static resolveBluetoothDeviceName(deviceId: string): string {
    const remoteName = PeripheralConnectionRecordBluetoothAclConsumer.queryRemoteDeviceName(deviceId)
    if (remoteName.length > 0) {
      BluetoothPolicySnapshotTraceService.rememberBluetoothDeviceName(deviceId, remoteName)
      return remoteName
    }

    const cachedName = BluetoothPolicySnapshotTraceService.resolveCachedBluetoothDeviceName(deviceId)
    if (cachedName.length > 0) {
      return cachedName
    }
    return PeripheralConnectionRecordStrings.UNNAMED_BLUETOOTH
  }

  private static queryRemoteDeviceName(deviceId: string): string {
    try {
      const provider = PeripheralConnectionRecordBluetoothAclConsumer.remoteDeviceNameProviderForTest
      if (provider) {
        return provider(deviceId)?.trim() ?? ''
      }
      return connection.getRemoteDeviceName(deviceId, false)?.trim() ?? ''
    } catch (err) {
      const error = err as BusinessError
      LogUtils.warn(
        TAG,
        `getRemoteDeviceName failed: deviceId=${PeripheralConnectionRecordBluetoothAclConsumer.maskBluetoothIdentifier(deviceId)}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
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
}

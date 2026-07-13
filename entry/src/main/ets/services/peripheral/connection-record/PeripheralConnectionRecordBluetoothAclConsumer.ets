import { SecurityEventResult } from '../../../models/CommonModels'
import { PeripheralType, formatBluetoothDeviceId } from '../../../models/PeripheralModels'
import { LogUtils } from '../../../utils/LogUtils'
import { PLACEHOLDER_TEXT, StatusText } from '../../../constants/StringCatalog'
import { PeripheralConnectionRecordStrings } from '../../../constants/modules/PeripheralStrings'
import { generateRandomSuffix } from '../../../utils/ValuePicker'
import {
  PeripheralBluetoothAclAction,
  PeripheralConnectionRecordConsumeResult,
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent
} from './PeripheralConnectionRecordProducerContract'
import { BluetoothRuntimeConnectionStore } from './BluetoothRuntimeConnectionStore'

const TAG = 'ConnectionRecordBtConsumer'

interface BluetoothAclEventInfo {
  occurAt: number
  deviceId: string
  rawDeviceId: string
  action: PeripheralBluetoothAclAction
  stateLabel: string
  rawPayload: string
}

export class PeripheralConnectionRecordBluetoothAclConsumer implements PeripheralConnectionRecordConsumer {
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
    const deviceName = (event.bluetoothAcl?.deviceName ?? '').trim()
    if (!BluetoothRuntimeConnectionStore.isValidResolvedDeviceName(deviceName)) {
      LogUtils.warn(TAG, 'skip bluetooth acl event: resolved device name missing')
      return null
    }
    const disabledByPolicy = eventInfo.action === 'disconnect' &&
      BluetoothRuntimeConnectionStore.consumeDisabledDisconnectPending(eventInfo.deviceId)

    return {
      recordId: `runtime_bt_acl_${eventInfo.occurAt}_${generateRandomSuffix()}`,
      occurAt: eventInfo.occurAt,
      collectAt: Date.now(),
      deviceName: deviceName,
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: eventInfo.deviceId,
      action: eventInfo.action,
      decision: disabledByPolicy ? 'deny' : 'allow',
      result: disabledByPolicy ? SecurityEventResult.BLOCKED : SecurityEventResult.SUCCESS,
      source: 'runtime_event',
      summary: eventInfo.action === 'connect'
        ? PeripheralConnectionRecordStrings.BLUETOOTH_CONNECTED
        : PeripheralConnectionRecordStrings.BLUETOOTH_DISCONNECTED,
      rawEventName: event.eventName,
      rawAction: eventInfo.action,
      rawPayload: eventInfo.rawPayload,
      detail: `aclState=${eventInfo.stateLabel}, reason=${PLACEHOLDER_TEXT}`,
      effectivePolicyLabel: disabledByPolicy ? StatusText.DISABLED : StatusText.ENABLED,
      matchedPolicyKind: disabledByPolicy ? 'bluetooth_disabled' : 'bluetooth_connection'
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
      LogUtils.warn(TAG, 'skip bluetooth acl event: system deviceId missing')
      return null
    }

    let rawPayload = ''
    try {
      rawPayload = JSON.stringify({
        deviceId: payload.deviceId,
        action: payload.action,
        occurAt: payload.occurAt
      })
    } catch (_err) {
      rawPayload = ''
    }
    return {
      occurAt: Number.isFinite(payload.occurAt) && payload.occurAt > 0 ? payload.occurAt : Date.now(),
      deviceId: formatBluetoothDeviceId(rawDeviceId),
      rawDeviceId: rawDeviceId,
      action: payload.action,
      stateLabel: payload.action === 'connect' ? 'STATE_CONNECTED' : 'STATE_DISCONNECTED',
      rawPayload: rawPayload
    }
  }

}

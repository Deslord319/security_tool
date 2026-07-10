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
    let deviceName = ''
    if (eventInfo.action === 'connect') {
      const snapshot = BluetoothRuntimeConnectionStore.rememberConnectedDevice(
        eventInfo.rawDeviceId,
        eventInfo.rawPayload
      )
      deviceName = snapshot?.deviceName ?? PeripheralConnectionRecordStrings.UNNAMED_BLUETOOTH
    } else {
      deviceName = BluetoothRuntimeConnectionStore.resolveDeviceName(eventInfo.rawDeviceId)
      BluetoothRuntimeConnectionStore.forgetConnectedDevice(eventInfo.deviceId)
    }

    return {
      recordId: `runtime_bt_acl_${eventInfo.occurAt}_${generateRandomSuffix()}`,
      occurAt: eventInfo.occurAt,
      collectAt: Date.now(),
      deviceName: deviceName,
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
      matchedPolicyKind: 'bluetooth_connection'
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
      action: payload.action,
      stateLabel: payload.action === 'connect' ? 'STATE_CONNECTED' : 'STATE_DISCONNECTED',
      rawPayload: rawPayload
    }
  }

}

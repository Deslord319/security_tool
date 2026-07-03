import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { connection } from '@kit.ConnectivityKit'
import { SecurityEventResult } from '../../../models/CommonModels'
import {
  PeripheralType,
  formatBluetoothDeviceId
} from '../../../models/PeripheralModels'
import { LogUtils } from '../../../utils/LogUtils'
import { PLACEHOLDER_TEXT } from '../../../constants/StringCatalog'
import {
  EventPayloadRecord,
  collectPayloadSources,
  pickNumber,
  pickString
} from './PeripheralConnectionRecordPayloadUtils'
import {
  PeripheralConnectionRecordConsumeResult,
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent,
  PeripheralConnectionAction
} from './PeripheralConnectionRecordProducerContract'
import { StatusText } from '../../../constants/StringCatalog'
import { PeripheralConnectionRecordStrings } from '../../../constants/modules/PeripheralStrings'
import { generateRandomSuffix } from '../../../utils/ValuePicker'

const TAG = 'ConnectionRecordBtConsumer'
const BLUETOOTH_ACL_STATE_DISCONNECTED = 0
const BLUETOOTH_ACL_STATE_CONNECTED = 1
const BLUETOOTH_ACL_STATE_CONNECTING = 2
const BLUETOOTH_ACL_STATE_DISCONNECTING = 3

interface BluetoothAclEventInfo {
  occurAt: number
  deviceId: string
  rawDeviceId: string
  deviceName: string
  action: PeripheralConnectionAction
  stateLabel: string
  reasonLabel: string
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
    const rawData = event.rawData
    if (!rawData) {
      return null
    }

    const eventInfo = await PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothAclEventInfo(rawData)
    if (!eventInfo || eventInfo.action === 'unknown') {
      return null
    }
    const detail = PeripheralConnectionRecordBluetoothAclConsumer.buildDetail(eventInfo)

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
      summary: eventInfo.action === 'connect' ? PeripheralConnectionRecordStrings.BLUETOOTH_CONNECTED : PeripheralConnectionRecordStrings.BLUETOOTH_DISCONNECTED,
      rawEventName: rawData.event,
      rawAction: eventInfo.action,
      rawPayload: eventInfo.rawPayload,
      detail: detail,
      effectivePolicyLabel: StatusText.ENABLED,
      matchedPolicyKind: 'bluetooth_connection_event'
    }
  }

  private static buildDetail(eventInfo: BluetoothAclEventInfo): string {
    return `aclState=${eventInfo.stateLabel}, reason=${eventInfo.reasonLabel}`
  }

  private static async resolveBluetoothAclEventInfo(
    data: commonEventManager.CommonEventData
  ): Promise<BluetoothAclEventInfo | null> {
    const payloads = collectPayloadSources(data)
    const rawDeviceId = PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothDeviceId(payloads)
    if (rawDeviceId.length === 0) {
      LogUtils.warn(
        TAG,
        `skip bluetooth acl event: deviceId missing, keys=${PeripheralConnectionRecordBluetoothAclConsumer.describePayloadKeys(payloads)}`
      )
      return null
    }

    const action = PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothAclAction(payloads)
    const stateLabel = PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothAclStateLabel(payloads)
    const reasonLabel = PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothAclReasonLabel(payloads)
    const occurAt = PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothOccurAt(payloads)
    const nameResolution = PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothDeviceName(rawDeviceId, payloads)

    let rawPayload = ''
    try {
      rawPayload = JSON.stringify(data)
    } catch (_err) {
      rawPayload = ''
    }

    return {
      occurAt: Number.isFinite(occurAt) && occurAt > 0 ? occurAt : Date.now(),
      deviceId: formatBluetoothDeviceId(rawDeviceId),
      rawDeviceId: rawDeviceId,
      deviceName: nameResolution,
      action: action,
      stateLabel: stateLabel,
      reasonLabel: reasonLabel,
      rawPayload: rawPayload
    }
  }

  private static resolveBluetoothDeviceId(sources: EventPayloadRecord[]): string {
    return pickString(
      sources,
      ['deviceId', 'deviceid', 'deviceAddr', 'deviceAddress', 'address', 'addr', 'remoteAddr', 'remoteAddress', 'mac', 'macAddress']
    )
  }

  private static resolveBluetoothAclAction(sources: EventPayloadRecord[]): PeripheralConnectionAction {
    const stateLabel = PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothAclStateLabel(sources).toUpperCase()
    if (stateLabel.includes('DISCONNECT')) {
      return 'disconnect'
    }
    if (stateLabel.includes('CONNECT')) {
      return 'connect'
    }

    const stateValue = pickNumber(
      sources,
      ['connectionstate', 'connectionState', 'aclState', 'aclstate', 'state', 'linkState', 'linkstate', 'status']
    )
    if (stateValue === BLUETOOTH_ACL_STATE_DISCONNECTED) {
      return 'disconnect'
    }
    if (stateValue === BLUETOOTH_ACL_STATE_CONNECTED || stateValue === BLUETOOTH_ACL_STATE_CONNECTING) {
      return 'connect'
    }
    return 'unknown'
  }

  private static resolveBluetoothAclStateLabel(sources: EventPayloadRecord[]): string {
    const rawLabel = pickString(
      sources,
      [
        'stateName',
        'stateLabel',
        'aclStateName',
        'aclstateName',
        'state',
        'aclState',
        'aclstate',
        'connectionState',
        'connectionstate',
        'linkState',
        'linkstate',
        'status'
      ]
    )
    if (rawLabel.length > 0) {
      return rawLabel
    }

    const rawState = pickNumber(
      sources,
      ['connectionstate', 'connectionState', 'aclState', 'aclstate', 'state', 'linkState', 'linkstate', 'status']
    )
    if (Number.isFinite(rawState)) {
      switch (rawState) {
        case BLUETOOTH_ACL_STATE_DISCONNECTED:
          return 'STATE_DISCONNECTED'
        case BLUETOOTH_ACL_STATE_CONNECTED:
        case BLUETOOTH_ACL_STATE_CONNECTING:
          return 'STATE_CONNECTED'
        case BLUETOOTH_ACL_STATE_DISCONNECTING:
          return 'STATE_DISCONNECTING'
        default:
          return `${rawState}`
      }
    }
    return 'UNKNOWN'
  }

  private static resolveBluetoothAclReasonLabel(sources: EventPayloadRecord[]): string {
    const rawReason = pickString(
      sources,
      ['reason', 'reasonCode', 'reasoncode', 'cause', 'disconnectReason', 'disconnectreason']
    )
    if (rawReason.length > 0) {
      return rawReason
    }

    const reasonCode = pickNumber(
      sources,
      ['reason', 'reasonCode', 'reasoncode', 'cause', 'disconnectReason', 'disconnectreason']
    )
    if (Number.isFinite(reasonCode)) {
      return `${reasonCode}`
    }
    return PLACEHOLDER_TEXT
  }

  private static resolveBluetoothOccurAt(sources: EventPayloadRecord[]): number {
    return pickNumber(sources, ['timestamp', 'time', 'occurAt'])
  }

  private static resolveBluetoothDeviceName(deviceId: string, sources: EventPayloadRecord[]): string {
    const payloadName = pickString(
      sources,
      ['deviceName', 'name', 'remoteName', 'remoteDeviceName', 'alias', 'deviceAlias', 'aliasName']
    )
    if (payloadName.length > 0) {
      return payloadName
    }

    try {
      const remoteName = connection.getRemoteDeviceName(deviceId, true)?.trim() ?? ''
      if (remoteName.length > 0) {
        return remoteName
      }
    } catch (err) {
      const error = err as BusinessError
      LogUtils.warn(
        TAG,
        `getRemoteDeviceName failed: deviceId=${PeripheralConnectionRecordBluetoothAclConsumer.maskBluetoothIdentifier(deviceId)}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
    }

    return PeripheralConnectionRecordStrings.UNNAMED_BLUETOOTH
  }

  private static maskBluetoothIdentifier(deviceId: string): string {
    const segments = deviceId.trim().replace(/-/g, ':').split(':').filter((item: string) => item.length > 0)
    if (segments.length < 2) {
      return 'unknown'
    }
    return `**:**:**:**:${segments[segments.length - 2]}:${segments[segments.length - 1]}`
  }

  private static describePayloadKeys(sources: EventPayloadRecord[]): string {
    const keys = new Set<string>()
    sources.forEach((source: EventPayloadRecord) => {
      Object.keys(source).forEach((key: string) => {
        if (key.trim().length > 0) {
          keys.add(key)
        }
      })
    })
    return Array.from(keys).sort().join('|')
  }
}

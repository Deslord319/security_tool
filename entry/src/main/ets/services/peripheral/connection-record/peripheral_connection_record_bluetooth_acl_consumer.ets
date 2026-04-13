import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { connection } from '@kit.ConnectivityKit'
import {
  LogEventResult,
  PeripheralTraceRecord,
  PeripheralType,
  formatBluetoothDeviceId
} from '../../../models/DataModels'
import { PeripheralDevicePolicyRepository } from '../device-policy/PeripheralDevicePolicyRepository'
import { LogUtils } from '../../../utils/LogUtils'
import { LabelText, PLACEHOLDER_TEXT } from '../../../constants/StringCatalog'
import {
  collectPayloadSources,
  pickNumber,
  pickString
} from './peripheral_connection_record_payload_utils'
import {
  PeripheralConnectionRecordConsumeResult,
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent
} from './peripheral_connection_record_producer_contract'
import { StatusText } from '../../../constants/StringCatalog'
import { PeripheralConnectionRecordStrings } from '../../../constants/modules/PeripheralStrings'
import { LooseRecord } from '../../../types/LooseValueTypes'
import { generateRandomSuffix } from '../../../utils/ValuePicker'

const TAG = 'ConnectionRecordBtConsumer'

type BluetoothAclAction = 'connect' | 'disconnect' | 'unknown'
type EventPayloadRecord = LooseRecord

interface BluetoothAclEventInfo {
  occurAt: number
  deviceId: string
  rawDeviceId: string
  deviceName: string
  action: BluetoothAclAction
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
    const rawData = event.rawData as commonEventManager.CommonEventData | undefined
    if (!rawData) {
      return null
    }

    const eventInfo = await PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothAclEventInfo(rawData)
    if (!eventInfo || eventInfo.action === 'unknown') {
      return null
    }
    const devicePolicy = PeripheralDevicePolicyRepository.get(eventInfo.deviceId)
    const denied = devicePolicy?.policy === 'deny'

    return {
      recordId: `runtime_bt_acl_${eventInfo.occurAt}_${generateRandomSuffix()}`,
      occurAt: eventInfo.occurAt,
      collectAt: Date.now(),
      deviceName: eventInfo.deviceName,
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: eventInfo.deviceId,
      action: eventInfo.action,
      decision: denied ? 'deny' : 'allow',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: eventInfo.action === 'connect' ? PeripheralConnectionRecordStrings.BLUETOOTH_CONNECTED : PeripheralConnectionRecordStrings.BLUETOOTH_DISCONNECTED,
      rawEventName: rawData.event,
      rawAction: eventInfo.action,
      rawPayload: eventInfo.rawPayload,
      detail: `aclState=${eventInfo.stateLabel}, reason=${eventInfo.reasonLabel}`,
      effectivePolicyLabel: denied ? StatusText.DISABLED : StatusText.ENABLED,
      matchedPolicyKind: 'bluetooth_connection_event'
    }
  }

  private static async resolveBluetoothAclEventInfo(
    data: commonEventManager.CommonEventData
  ): Promise<BluetoothAclEventInfo | null> {
    const payloads = collectPayloadSources(data as Object)
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
      deviceId: PeripheralConnectionRecordBluetoothAclConsumer.normalizeBluetoothDeviceId(rawDeviceId),
      rawDeviceId: rawDeviceId,
      deviceName: nameResolution,
      action: action,
      stateLabel: stateLabel,
      reasonLabel: reasonLabel,
      rawPayload: rawPayload
    }
  }

  private static normalizeBluetoothDeviceId(deviceId: string): string {
    return formatBluetoothDeviceId(deviceId)
  }

  private static resolveBluetoothDeviceId(sources: EventPayloadRecord[]): string {
    return pickString(
      sources,
      ['deviceId', 'deviceid', 'deviceAddr', 'deviceAddress', 'address', 'addr', 'remoteAddr', 'remoteAddress', 'mac', 'macAddress']
    )
  }

  private static resolveBluetoothAclAction(sources: EventPayloadRecord[]): BluetoothAclAction {
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
    if (stateValue === 0) {
      return 'disconnect'
    }
    if (stateValue === 1 || stateValue === 2) {
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
        case 0:
          return 'STATE_DISCONNECTED'
        case 1:
        case 2:
          return 'STATE_CONNECTED'
        case 3:
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

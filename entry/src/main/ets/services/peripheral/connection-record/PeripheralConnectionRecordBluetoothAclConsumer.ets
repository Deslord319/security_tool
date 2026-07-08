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
import { BluetoothPolicySnapshotTraceService } from './BluetoothPolicySnapshotTraceService'

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
  linkType: number
  action: PeripheralConnectionAction
  stateLabel: string
  reasonLabel: string
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
    const rawData = event.rawData
    if (!rawData) {
      return null
    }

    const eventInfo = await PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothAclEventInfo(rawData)
    if (!eventInfo || eventInfo.action === 'unknown') {
      return null
    }
    if (PeripheralConnectionRecordBluetoothAclConsumer.shouldDropAnonymousLinkTypeOneEvent(eventInfo)) {
      LogUtils.info(
        TAG,
        `drop anonymous bluetooth acl linktype=1 event: action=${eventInfo.action}, deviceId=${PeripheralConnectionRecordBluetoothAclConsumer.maskBluetoothIdentifier(eventInfo.rawDeviceId)}`
      )
      if (eventInfo.action === 'disconnect') {
        BluetoothPolicySnapshotTraceService.forgetRuntimeConnectedDevice(eventInfo.deviceId)
      }
      return null
    }
    if (eventInfo.action === 'connect') {
      BluetoothPolicySnapshotTraceService.rememberRuntimeConnectedDevice(
        eventInfo.rawDeviceId,
        eventInfo.rawPayload,
        eventInfo.deviceName
      )
    }
    if (eventInfo.action === 'disconnect') {
      BluetoothPolicySnapshotTraceService.forgetRuntimeConnectedDevice(eventInfo.deviceId)
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
    const linkType = PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothLinkType(payloads)
    const nameResolution = PeripheralConnectionRecordBluetoothAclConsumer.resolveBluetoothDeviceName(rawDeviceId)

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
      linkType: linkType,
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
    if (PeripheralConnectionRecordBluetoothAclConsumer.isDisconnectedStateLabel(stateLabel)) {
      return 'disconnect'
    }
    if (PeripheralConnectionRecordBluetoothAclConsumer.isConnectedStateLabel(stateLabel)) {
      return 'connect'
    }

    const stateValue = pickNumber(
      sources,
      ['connectionstate', 'connectionState', 'aclState', 'aclstate', 'state', 'linkState', 'linkstate', 'status']
    )
    if (stateValue === BLUETOOTH_ACL_STATE_DISCONNECTED) {
      return 'disconnect'
    }
    if (stateValue === BLUETOOTH_ACL_STATE_CONNECTED) {
      return 'connect'
    }
    return 'unknown'
  }

  private static isConnectedStateLabel(stateLabel: string): boolean {
    return stateLabel === 'STATE_CONNECTED' ||
      stateLabel === 'CONNECTED' ||
      stateLabel === 'ACL_CONNECTED' ||
      stateLabel === 'CONNECTION_STATE_CONNECTED'
  }

  private static isDisconnectedStateLabel(stateLabel: string): boolean {
    return stateLabel === 'STATE_DISCONNECTED' ||
      stateLabel === 'DISCONNECTED' ||
      stateLabel === 'ACL_DISCONNECTED' ||
      stateLabel === 'CONNECTION_STATE_DISCONNECTED'
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
      const numericLabel = Number(rawLabel)
      const mappedLabel = PeripheralConnectionRecordBluetoothAclConsumer.formatBluetoothAclStateValue(numericLabel)
      if (mappedLabel.length > 0) {
        return mappedLabel
      }
      return rawLabel
    }

    const rawState = pickNumber(
      sources,
      ['connectionstate', 'connectionState', 'aclState', 'aclstate', 'state', 'linkState', 'linkstate', 'status']
    )
    const mappedState = PeripheralConnectionRecordBluetoothAclConsumer.formatBluetoothAclStateValue(rawState)
    if (mappedState.length > 0) {
      return mappedState
    }
    return 'UNKNOWN'
  }

  private static formatBluetoothAclStateValue(stateValue: number): string {
    if (!Number.isFinite(stateValue)) {
      return ''
    }
    switch (stateValue) {
      case BLUETOOTH_ACL_STATE_DISCONNECTED:
        return 'STATE_DISCONNECTED'
      case BLUETOOTH_ACL_STATE_CONNECTED:
        return 'STATE_CONNECTED'
      case BLUETOOTH_ACL_STATE_CONNECTING:
        return 'STATE_CONNECTING'
      case BLUETOOTH_ACL_STATE_DISCONNECTING:
        return 'STATE_DISCONNECTING'
      default:
        return `${stateValue}`
    }
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

  private static resolveBluetoothLinkType(sources: EventPayloadRecord[]): number {
    return pickNumber(sources, ['linktype', 'linkType', 'link_type'])
  }

  private static shouldDropAnonymousLinkTypeOneEvent(eventInfo: BluetoothAclEventInfo): boolean {
    return eventInfo.linkType === 1 &&
      PeripheralConnectionRecordBluetoothAclConsumer.isUnnamedBluetoothDeviceName(eventInfo.deviceName)
  }

  private static isUnnamedBluetoothDeviceName(deviceName: string): boolean {
    return (deviceName ?? '').trim() === PeripheralConnectionRecordStrings.UNNAMED_BLUETOOTH
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

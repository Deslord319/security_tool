import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { connection } from '@kit.ConnectivityKit'
import {
  LogEventResult,
  PeripheralTraceRecord,
  PeripheralType,
  formatBluetoothDeviceId
} from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import {
  PeripheralConnectionRecordConsumeResult,
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent
} from './peripheral_connection_record_producer_contract'

const TAG = 'ConnectionRecordBtConsumer'
const FALLBACK_BLUETOOTH_NAME = '未命名蓝牙设备'

type BluetoothAclAction = 'connect' | 'disconnect' | 'unknown'
type EventPayloadRecord = Record<string, Object>

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

    return {
      recordId: `runtime_bt_acl_${eventInfo.occurAt}_${Math.random().toString(36).substring(2, 8)}`,
      occurAt: eventInfo.occurAt,
      collectAt: Date.now(),
      deviceName: eventInfo.deviceName,
      deviceType: PeripheralType.BLUETOOTH,
      deviceId: eventInfo.deviceId,
      action: eventInfo.action,
      decision: 'unknown',
      result: LogEventResult.SUCCESS,
      source: 'runtime_event',
      summary: eventInfo.action === 'connect' ? '蓝牙设备已连接' : '蓝牙设备已断开',
      rawEventName: rawData.event,
      rawAction: eventInfo.action,
      rawPayload: eventInfo.rawPayload,
      detail: `aclState=${eventInfo.stateLabel}, reason=${eventInfo.reasonLabel}`,
      effectivePolicyLabel: '--',
      matchedPolicyKind: 'bluetooth_connection_event'
    }
  }

  private static async resolveBluetoothAclEventInfo(
    data: commonEventManager.CommonEventData
  ): Promise<BluetoothAclEventInfo | null> {
    const payloads = PeripheralConnectionRecordBluetoothAclConsumer.collectPayloadSources(data)
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
    return PeripheralConnectionRecordBluetoothAclConsumer.pickString(
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

    const stateValue = PeripheralConnectionRecordBluetoothAclConsumer.pickNumber(
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
    const rawLabel = PeripheralConnectionRecordBluetoothAclConsumer.pickString(
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

    const rawState = PeripheralConnectionRecordBluetoothAclConsumer.pickNumber(
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
    const rawReason = PeripheralConnectionRecordBluetoothAclConsumer.pickString(
      sources,
      ['reason', 'reasonCode', 'reasoncode', 'cause', 'disconnectReason', 'disconnectreason']
    )
    if (rawReason.length > 0) {
      return rawReason
    }

    const reasonCode = PeripheralConnectionRecordBluetoothAclConsumer.pickNumber(
      sources,
      ['reason', 'reasonCode', 'reasoncode', 'cause', 'disconnectReason', 'disconnectreason']
    )
    if (Number.isFinite(reasonCode)) {
      return `${reasonCode}`
    }
    return '--'
  }

  private static resolveBluetoothOccurAt(sources: EventPayloadRecord[]): number {
    return PeripheralConnectionRecordBluetoothAclConsumer.pickNumber(sources, ['timestamp', 'time', 'occurAt'])
  }

  private static resolveBluetoothDeviceName(deviceId: string, sources: EventPayloadRecord[]): string {
    const payloadName = PeripheralConnectionRecordBluetoothAclConsumer.pickString(
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

    return FALLBACK_BLUETOOTH_NAME
  }

  private static maskBluetoothIdentifier(deviceId: string): string {
    const segments = deviceId.trim().replace(/-/g, ':').split(':').filter((item: string) => item.length > 0)
    if (segments.length < 2) {
      return 'unknown'
    }
    return `**:**:**:**:${segments[segments.length - 2]}:${segments[segments.length - 1]}`
  }

  private static collectPayloadSources(data: commonEventManager.CommonEventData): EventPayloadRecord[] {
    const sources: EventPayloadRecord[] = []
    const root = PeripheralConnectionRecordBluetoothAclConsumer.toRecord(data as Object)
    const parameters = PeripheralConnectionRecordBluetoothAclConsumer.toRecord(data.parameters as Object)
    const want = PeripheralConnectionRecordBluetoothAclConsumer.readObjectField(root, 'want')
    const wantParameters = PeripheralConnectionRecordBluetoothAclConsumer.readObjectField(want, 'parameters')
    const rootData = PeripheralConnectionRecordBluetoothAclConsumer.parseJsonObjectField(root, 'data')
    const wantData = PeripheralConnectionRecordBluetoothAclConsumer.parseJsonObjectField(want, 'data')

    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, root)
    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, parameters)
    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, want)
    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, wantParameters)
    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, rootData)
    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, wantData)

    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, PeripheralConnectionRecordBluetoothAclConsumer.readDeviceField(root))
    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, PeripheralConnectionRecordBluetoothAclConsumer.readDeviceField(parameters))
    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, PeripheralConnectionRecordBluetoothAclConsumer.readDeviceField(want))
    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, PeripheralConnectionRecordBluetoothAclConsumer.readDeviceField(wantParameters))
    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, PeripheralConnectionRecordBluetoothAclConsumer.readDeviceField(rootData))
    PeripheralConnectionRecordBluetoothAclConsumer.pushRecord(sources, PeripheralConnectionRecordBluetoothAclConsumer.readDeviceField(wantData))
    return sources
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

  private static pickNumber(sources: EventPayloadRecord[], keys: string[]): number {
    for (const source of sources) {
      for (const key of keys) {
        const value = source[key]
        if (typeof value === 'number' && Number.isFinite(value)) {
          return value
        }
        if (typeof value === 'string') {
          const normalized = value.trim()
          if (normalized.length === 0) {
            continue
          }
          const radix = normalized.startsWith('0x') || normalized.startsWith('0X') ? 16 : 10
          const parsed = parseInt(normalized.replace(/^0x/i, ''), radix)
          if (Number.isFinite(parsed)) {
            return parsed
          }
        }
      }
    }
    return Number.NaN
  }

  private static pickString(sources: EventPayloadRecord[], keys: string[]): string {
    for (const source of sources) {
      for (const key of keys) {
        const value = source[key]
        if (typeof value === 'string' && value.trim().length > 0) {
          return value.trim()
        }
      }
    }
    return ''
  }

  private static pushRecord(target: EventPayloadRecord[], value: EventPayloadRecord | undefined): void {
    if (value === undefined) {
      return
    }
    if (target.some((item: EventPayloadRecord) => item === value)) {
      return
    }
    target.push(value)
  }

  private static toRecord(value: Object | undefined | null): EventPayloadRecord | undefined {
    if (!value || typeof value !== 'object') {
      return undefined
    }
    return value as EventPayloadRecord
  }

  private static readObjectField(
    source: EventPayloadRecord | undefined,
    key: string
  ): EventPayloadRecord | undefined {
    if (source === undefined) {
      return undefined
    }
    return PeripheralConnectionRecordBluetoothAclConsumer.toRecord(source[key])
  }

  private static parseJsonObjectField(
    source: EventPayloadRecord | undefined,
    key: string
  ): EventPayloadRecord | undefined {
    if (source === undefined) {
      return undefined
    }
    const value = source[key]
    if (typeof value !== 'string') {
      return undefined
    }
    const normalized = value.trim()
    if (normalized.length === 0 || !normalized.startsWith('{')) {
      return undefined
    }
    try {
      return PeripheralConnectionRecordBluetoothAclConsumer.toRecord(JSON.parse(normalized) as Object)
    } catch (_err) {
      return undefined
    }
  }

  private static readDeviceField(source: EventPayloadRecord | undefined): EventPayloadRecord | undefined {
    if (source === undefined) {
      return undefined
    }
    return PeripheralConnectionRecordBluetoothAclConsumer.readObjectField(source, 'device') ||
      PeripheralConnectionRecordBluetoothAclConsumer.readObjectField(source, 'remoteDevice') ||
      PeripheralConnectionRecordBluetoothAclConsumer.readObjectField(source, 'remote_device') ||
      PeripheralConnectionRecordBluetoothAclConsumer.readObjectField(source, 'bluetoothDevice') ||
      PeripheralConnectionRecordBluetoothAclConsumer.readObjectField(source, 'usbDevice') ||
      PeripheralConnectionRecordBluetoothAclConsumer.readObjectField(source, 'usb_device')
  }
}

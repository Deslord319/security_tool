import type { PeripheralTraceRecord } from '../../DataModels'

export type ConnectionRecordChannel = 'usb' | 'bluetooth_acl'

export type ConnectionProducerEventName =
  'COMMON_EVENT_USB_DEVICE_ATTACHED' |
  'COMMON_EVENT_USB_DEVICE_DETACHED' |
  'COMMON_EVENT_BLUETOOTH_REMOTEDEVICE_ACL_STATE_CHANGE'

export interface ConnectionRecordProducerEvent {
  channel: ConnectionRecordChannel
  eventName: ConnectionProducerEventName | string
  occurAtHint?: number
  payload: object
  rawData: object
}

export interface ConnectionRecordProducer {
  start(): Promise<boolean>
  stop(): void
  subscribe(handler: (event: ConnectionRecordProducerEvent) => void): number
  unsubscribe(listenerId: number): void
  getStatus(): { running: boolean; degradedReason?: string }
}

export interface ConnectionRecordConsumer {
  canHandle(event: ConnectionRecordProducerEvent): boolean
  consume(event: ConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null>
}

export interface ConnectionRecordPipeline {
  push(event: ConnectionRecordProducerEvent): Promise<void>
}

export interface ConnectionRecordDedupePolicy {
  shouldSkip(record: PeripheralTraceRecord, now: number): boolean
}

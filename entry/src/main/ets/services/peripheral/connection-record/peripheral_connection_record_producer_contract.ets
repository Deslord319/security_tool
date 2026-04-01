import type { PeripheralTraceRecord } from '../../../models/DataModels'

export interface PeripheralConnectionRecordProducerCapabilities {
  usbRuntimeEvents: boolean
  bluetoothRuntimeEvents: boolean
  degradedReason?: string
}

export interface PeripheralConnectionRecordProducerStatus {
  running: boolean
  capabilities: PeripheralConnectionRecordProducerCapabilities
}

export interface PeripheralConnectionRecordProducerEvent {
  source: 'runtime'
  channel: 'usb' | 'bluetooth_acl'
  eventName: string
  payload?: Object
  rawData: Object
}

export type PeripheralConnectionRecordProducerListener = (event: PeripheralConnectionRecordProducerEvent) => void

export interface PeripheralConnectionRecordProducer {
  start(): Promise<boolean>
  stop(): void
  subscribe(listener: PeripheralConnectionRecordProducerListener): number
  unsubscribe(listenerId: number): void
  getStatus(): PeripheralConnectionRecordProducerStatus
}

export type PeripheralConnectionRecordConsumeResult = PeripheralTraceRecord | null

export interface PeripheralConnectionRecordConsumer {
  canHandle(event: PeripheralConnectionRecordProducerEvent): boolean
  consume(event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralConnectionRecordConsumeResult>
}

export interface PeripheralConnectionRecordPipeline {
  start(): Promise<boolean>
  stop(): void
  push(event: PeripheralConnectionRecordProducerEvent): Promise<boolean>
}

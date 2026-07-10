import type { common } from '@kit.AbilityKit'
import type { commonEventManager } from '@kit.BasicServicesKit'
import type { PeripheralTraceRecord } from '../../../models/PeripheralModels'
export interface PeripheralConnectionRecordProducerCapabilities {
  usbRuntimeEvents: boolean
  bluetoothRuntimeEvents: boolean
  degradedReason?: string
}

export interface PeripheralConnectionRecordProducerStatus {
  running: boolean
  capabilities: PeripheralConnectionRecordProducerCapabilities
}

export type PeripheralConnectionAction = 'connect' | 'disconnect' | 'unknown'

export interface PeripheralBluetoothAclProducerPayload {
  deviceId: string
  action: PeripheralConnectionAction
  occurAt: number
}

export interface PeripheralConnectionRecordProducerEvent {
  source: 'runtime'
  channel: 'usb' | 'bluetooth_acl'
  eventName: string
  payload?: Object
  rawData?: commonEventManager.CommonEventData
  bluetoothAcl?: PeripheralBluetoothAclProducerPayload
}

export type PeripheralConnectionRecordProducerListener = (event: PeripheralConnectionRecordProducerEvent) => void

export interface PeripheralConnectionRecordProducer {
  bindContext?(context: common.UIAbilityContext): void
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
  bindContext(context: common.UIAbilityContext): Promise<boolean>
  attachProducer(producer: PeripheralConnectionRecordProducer | null): Promise<boolean>
  detachProducer(): void
  start(): Promise<boolean>
  stop(): void
  push(event: PeripheralConnectionRecordProducerEvent): Promise<boolean>
}

import type { common } from '@kit.AbilityKit'
import type { commonEventManager } from '@kit.BasicServicesKit'
import type { connection } from '@kit.ConnectivityKit'
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

export type PeripheralBluetoothAclAction = 'connect' | 'disconnect'

export interface PeripheralBluetoothAclProducerPayload {
  deviceId: string
  action: PeripheralBluetoothAclAction
  occurAt: number
  deviceName?: string
}

export interface PeripheralBluetoothBondProducerPayload {
  deviceId: string
  state: connection.BondState
  cause?: connection.UnbondCause
  occurAt: number
}

export interface PeripheralConnectionRecordProducerEvent {
  source: 'runtime'
  channel: 'usb' | 'bluetooth_acl' | 'bluetooth_bond'
  eventName: string
  rawData?: commonEventManager.CommonEventData
  bluetoothAcl?: PeripheralBluetoothAclProducerPayload
  bluetoothBond?: PeripheralBluetoothBondProducerPayload
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

import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import {
  LogEventResult,
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import { PeripheralTraceRepository } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceRepository'
import { PeripheralConnectionRecordPipelineImpl } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline'
import {
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducer,
  PeripheralConnectionRecordProducerEvent,
  PeripheralConnectionRecordProducerListener,
  PeripheralConnectionRecordProducerStatus
} from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'

interface PipelineProbe {
  traceRepositoryReady: boolean
  context: common.UIAbilityContext | null
}

class EmptyRawData {
}

class FixedEvent implements PeripheralConnectionRecordProducerEvent {
  source: 'runtime' = 'runtime'
  channel: 'usb' | 'bluetooth_acl'
  eventName: string
  rawData: Object = new EmptyRawData()

  constructor(channel: 'usb' | 'bluetooth_acl', eventName: string) {
    this.channel = channel
    this.eventName = eventName
  }
}

class StaticRecordConsumer implements PeripheralConnectionRecordConsumer {
  canHandleCalls: number = 0
  consumeCalls: number = 0
  private channel: 'usb' | 'bluetooth_acl' | 'all' | 'none'
  private record: PeripheralTraceRecord | null

  constructor(channel: 'usb' | 'bluetooth_acl' | 'all' | 'none', record: PeripheralTraceRecord | null) {
    this.channel = channel
    this.record = record
  }

  canHandle(event: PeripheralConnectionRecordProducerEvent): boolean {
    this.canHandleCalls++
    if (this.channel === 'all') {
      return true
    }
    if (this.channel === 'none') {
      return false
    }
    return event.channel === this.channel
  }

  async consume(_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> {
    this.consumeCalls++
    return this.record
  }
}

class ThrowingDeviceIdRecord implements PeripheralTraceRecord {
  recordId: string = 'runtime_usb_throwing'
  occurAt: number = 300
  collectAt: number = 301
  deviceName: string = 'Broken Device'
  deviceType: PeripheralType = PeripheralType.USB_STORAGE
  action: 'connect' = 'connect'
  decision: 'allow' = 'allow'
  result: LogEventResult = LogEventResult.SUCCESS
  source: 'runtime_event' = 'runtime_event'
  summary: string = 'broken'
  rawEventName: string = 'usual.event.USB_ATTACHED'

  get deviceId(): string {
    throw new Error('deviceId read failed')
  }
}

class FakeProducer implements PeripheralConnectionRecordProducer {
  bindContextCalls: number = 0
  startCalls: number = 0
  stopCalls: number = 0
  subscribeCalls: number = 0
  unsubscribeCalls: number = 0
  lastListenerId: number = 0
  lastContext: common.UIAbilityContext | null = null
  listeners: Map<number, PeripheralConnectionRecordProducerListener> = new Map()
  startResult: boolean = true

  bindContext(context: common.UIAbilityContext): void {
    this.bindContextCalls++
    this.lastContext = context
  }

  async start(): Promise<boolean> {
    this.startCalls++
    return this.startResult
  }

  stop(): void {
    this.stopCalls++
  }

  subscribe(listener: PeripheralConnectionRecordProducerListener): number {
    this.subscribeCalls++
    this.lastListenerId++
    this.listeners.set(this.lastListenerId, listener)
    return this.lastListenerId
  }

  unsubscribe(listenerId: number): void {
    this.unsubscribeCalls++
    this.listeners.delete(listenerId)
  }

  getStatus(): PeripheralConnectionRecordProducerStatus {
    return {
      running: this.startCalls > this.stopCalls,
      capabilities: {
        usbRuntimeEvents: true,
        bluetoothRuntimeEvents: true
      }
    }
  }
}

function buildUsbRecord(): PeripheralTraceRecord {
  return {
    recordId: 'runtime_usb_1',
    occurAt: 100,
    collectAt: 101,
    deviceName: 'USB Device',
    deviceType: PeripheralType.USB_STORAGE,
    deviceId: 'VID:1234 PID:5678',
    action: 'connect',
    decision: 'allow',
    result: LogEventResult.SUCCESS,
    source: 'runtime_event',
    summary: 'usb',
    rawEventName: 'usual.event.USB_ATTACHED'
  }
}

function buildBluetoothRecord(): PeripheralTraceRecord {
  return {
    recordId: 'runtime_bt_acl_1',
    occurAt: 200,
    collectAt: 201,
    deviceName: 'BT Device',
    deviceType: PeripheralType.BLUETOOTH,
    deviceId: 'MAC: 11:22:33:44:55:66',
    action: 'connect',
    decision: 'unknown',
    result: LogEventResult.SUCCESS,
    source: 'runtime_event',
    summary: 'bt',
    rawEventName: 'usual.event.BLUETOOTH_ACL'
  }
}

function markTraceRepositoryReady(pipeline: PeripheralConnectionRecordPipelineImpl): void {
  let probe = pipeline as Object as PipelineProbe
  probe.traceRepositoryReady = true
  probe.context = {} as common.UIAbilityContext
}

function createUsbEvent(eventName: string = 'usual.event.USB_ATTACHED'): PeripheralConnectionRecordProducerEvent {
  return new FixedEvent('usb', eventName)
}

function createBluetoothEvent(): PeripheralConnectionRecordProducerEvent {
  return new FixedEvent('bluetooth_acl', 'usual.event.BLUETOOTH_ACL')
}

export default function peripheralConnectionRecordPipelineTest() {
  describe('PeripheralConnectionRecordPipeline', () => {
    beforeEach(() => {
      PeripheralTraceRepository.resetForTest()
      PeripheralTraceRepository.setRecordsForTest([])
    })

    it('should dedupe usb records within 1500ms window by deviceId|action|rawEventName', 0, async () => {
      const consumer = new StaticRecordConsumer('usb', buildUsbRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      markTraceRepositoryReady(pipeline)

      const event = createUsbEvent()

      await pipeline.push(event)
      await pipeline.push(event)

      expect(consumer.consumeCalls).assertEqual(2)
      expect(PeripheralTraceRepository.query().length).assertEqual(1)
    })

    it('should not apply usb dedupe window for bluetooth acl records', 0, async () => {
      const consumer = new StaticRecordConsumer('bluetooth_acl', buildBluetoothRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      markTraceRepositoryReady(pipeline)

      await pipeline.push(createBluetoothEvent())
      await pipeline.push(createBluetoothEvent())

      expect(consumer.consumeCalls).assertEqual(2)
      expect(PeripheralTraceRepository.query().length).assertEqual(2)
    })

    it('should skip consumers whose canHandle returns false', 0, async () => {
      const skippedConsumer = new StaticRecordConsumer('none', buildUsbRecord())
      const handledConsumer = new StaticRecordConsumer('usb', buildUsbRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [skippedConsumer, handledConsumer])
      markTraceRepositoryReady(pipeline)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertTrue()
      expect(skippedConsumer.consumeCalls).assertEqual(0)
      expect(handledConsumer.consumeCalls).assertEqual(1)
      expect(PeripheralTraceRepository.query().length).assertEqual(1)
    })

    it('should not append when consumer returns null', 0, async () => {
      const consumer = new StaticRecordConsumer('usb', null)
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      markTraceRepositoryReady(pipeline)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertFalse()
      expect(consumer.consumeCalls).assertEqual(1)
      expect(PeripheralTraceRepository.query().length).assertEqual(0)
    })

    it('should only append records produced by matching consumers', 0, async () => {
      const usbConsumer = new StaticRecordConsumer('usb', buildUsbRecord())
      const bluetoothConsumer = new StaticRecordConsumer('bluetooth_acl', buildBluetoothRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [bluetoothConsumer, usbConsumer])
      markTraceRepositoryReady(pipeline)

      const processed = await pipeline.push(createUsbEvent())
      const records: PeripheralTraceRecord[] = PeripheralTraceRepository.query()

      expect(processed).assertTrue()
      expect(usbConsumer.consumeCalls).assertEqual(1)
      expect(bluetoothConsumer.consumeCalls).assertEqual(0)
      expect(records.length).assertEqual(1)
      expect(records[0].deviceType).assertEqual(PeripheralType.USB_STORAGE)
    })

    it('should return false and skip append when trace repository is not ready', 0, async () => {
      const consumer = new StaticRecordConsumer('all', buildUsbRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertFalse()
      expect(consumer.consumeCalls).assertEqual(0)
      expect(PeripheralTraceRepository.query().length).assertEqual(0)
    })

    it('should stay stable when append fails after consumer produces a record', 0, async () => {
      const consumer = new StaticRecordConsumer('all', new ThrowingDeviceIdRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      markTraceRepositoryReady(pipeline)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertTrue()
      expect(consumer.consumeCalls).assertEqual(1)
      expect(PeripheralTraceRepository.query().length).assertEqual(0)
    })

    it('should bind and start the new producer when attachProducer is called after start', 0, async () => {
      const firstProducer = new FakeProducer()
      const nextProducer = new FakeProducer()
      const pipeline = new PeripheralConnectionRecordPipelineImpl(firstProducer, [])
      let probe = pipeline as Object as PipelineProbe
      probe.context = {} as common.UIAbilityContext
      probe.traceRepositoryReady = true

      const started = await pipeline.start()
      expect(started).assertTrue()
      expect(firstProducer.bindContextCalls).assertEqual(1)
      expect(firstProducer.startCalls).assertEqual(1)
      expect(firstProducer.subscribeCalls).assertEqual(1)

      const attached = await pipeline.attachProducer(nextProducer)

      expect(attached).assertTrue()
      expect(firstProducer.unsubscribeCalls).assertEqual(1)
      expect(firstProducer.stopCalls).assertEqual(1)
      expect(nextProducer.bindContextCalls).assertEqual(1)
      expect(nextProducer.startCalls).assertEqual(1)
      expect(nextProducer.subscribeCalls).assertEqual(1)
      expect(nextProducer.lastContext).assertEqual(probe.context)
    })

    it('should unsubscribe and stop producer on detachProducer', 0, async () => {
      const producer = new FakeProducer()
      const pipeline = new PeripheralConnectionRecordPipelineImpl(producer, [])
      let probe = pipeline as Object as PipelineProbe
      probe.context = {} as common.UIAbilityContext
      probe.traceRepositoryReady = true

      await pipeline.start()
      pipeline.detachProducer()

      expect(producer.subscribeCalls).assertEqual(1)
      expect(producer.unsubscribeCalls).assertEqual(1)
      expect(producer.stopCalls).assertEqual(1)
      expect(producer.listeners.size).assertEqual(0)
    })
  })
}

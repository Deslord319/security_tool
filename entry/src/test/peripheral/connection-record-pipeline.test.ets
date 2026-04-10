import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  LogEventResult,
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import {
  PeripheralTraceMaintenanceService,
  PeripheralTraceMutationResult
} from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'
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
  occurAt: number = Date.now()
  collectAt: number = Date.now() + 1
  deviceType: PeripheralType = PeripheralType.USB_STORAGE
  deviceId: string = 'VID:1234 PID:5678'
  action: 'connect' = 'connect'
  decision: 'allow' = 'allow'
  result: LogEventResult = LogEventResult.SUCCESS
  source: 'runtime_event' = 'runtime_event'
  summary: string = 'broken'
  rawEventName: string = 'usual.event.USB_ATTACHED'

  get deviceName(): string {
    throw new Error('deviceName read failed')
  }
}

class FakeProducer implements PeripheralConnectionRecordProducer {
  bindContextCalls: number = 0
  startCalls: number = 0
  stopCalls: number = 0
  subscribeCalls: number = 0
  unsubscribeCalls: number = 0
  lastListenerId: number = 0
  listeners: Map<number, PeripheralConnectionRecordProducerListener> = new Map()
  startResult: boolean = true

  bindContext(): void {
    this.bindContextCalls++
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
  const now = Date.now()
  return {
    recordId: 'runtime_usb_1',
    occurAt: now,
    collectAt: now + 1,
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
  const now = Date.now()
  return {
    recordId: 'runtime_bt_acl_1',
    occurAt: now,
    collectAt: now + 1,
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
}

function createUsbEvent(eventName: string = 'usual.event.USB_ATTACHED'): PeripheralConnectionRecordProducerEvent {
  return new FixedEvent('usb', eventName)
}

function createBluetoothEvent(): PeripheralConnectionRecordProducerEvent {
  return new FixedEvent('bluetooth_acl', 'usual.event.BLUETOOTH_ACL')
}

export default function peripheralConnectionRecordPipelineTest() {
  describe('PeripheralConnectionRecordPipeline', () => {
    let mockKit: MockKit
    let savedRecords: PeripheralTraceRecord[]

    beforeEach(() => {
      mockKit = new MockKit()
      savedRecords = []
      let appendMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.appendEntries)
      when(appendMock)(ArgumentMatchers.any).afterAction((records: PeripheralTraceRecord[]) => {
        if (records.length > 0 && records[0].recordId === 'runtime_usb_throwing') {
          let failed: PeripheralTraceMutationResult = { success: false, code: 'save_failed' }
          return Promise.resolve(failed)
        }
        savedRecords = savedRecords.concat(records)
        let success: PeripheralTraceMutationResult = { success: true, code: 'ok' }
        return Promise.resolve(success)
      })
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should dedupe usb records within 1500ms window by deviceId|action|rawEventName', 0, async () => {
      const consumer = new StaticRecordConsumer('usb', buildUsbRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      markTraceRepositoryReady(pipeline)

      const event = createUsbEvent()
      await pipeline.push(event)
      await pipeline.push(event)

      expect(consumer.consumeCalls).assertEqual(2)
      expect(savedRecords.length).assertEqual(1)
    })

    it('should not apply usb dedupe window for bluetooth acl records', 0, async () => {
      const consumer = new StaticRecordConsumer('bluetooth_acl', buildBluetoothRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      markTraceRepositoryReady(pipeline)

      await pipeline.push(createBluetoothEvent())
      await pipeline.push(createBluetoothEvent())

      expect(consumer.consumeCalls).assertEqual(2)
      expect(savedRecords.length).assertEqual(2)
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
      expect(savedRecords.length).assertEqual(1)
    })

    it('should not append when consumer returns null', 0, async () => {
      const consumer = new StaticRecordConsumer('usb', null)
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      markTraceRepositoryReady(pipeline)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertFalse()
      expect(consumer.consumeCalls).assertEqual(1)
      expect(savedRecords.length).assertEqual(0)
    })

    it('should only append records produced by matching consumers', 0, async () => {
      const usbConsumer = new StaticRecordConsumer('usb', buildUsbRecord())
      const bluetoothConsumer = new StaticRecordConsumer('bluetooth_acl', buildBluetoothRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [bluetoothConsumer, usbConsumer])
      markTraceRepositoryReady(pipeline)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertTrue()
      expect(usbConsumer.consumeCalls).assertEqual(1)
      expect(bluetoothConsumer.consumeCalls).assertEqual(0)
      expect(savedRecords.length).assertEqual(1)
      expect(savedRecords[0].deviceType).assertEqual(PeripheralType.USB_STORAGE)
    })

    it('should return false and skip append when trace repository is not ready', 0, async () => {
      const consumer = new StaticRecordConsumer('all', buildUsbRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertFalse()
      expect(consumer.consumeCalls).assertEqual(0)
      expect(savedRecords.length).assertEqual(0)
    })

    it('should stay stable when append fails after consumer produces a record', 0, async () => {
      const consumer = new StaticRecordConsumer('all', new ThrowingDeviceIdRecord())
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      markTraceRepositoryReady(pipeline)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertFalse()
      expect(consumer.consumeCalls).assertEqual(1)
      expect(savedRecords.length).assertEqual(0)
    })

    it('should wire producer start and stop lifecycles', 0, async () => {
      const producer = new FakeProducer()
      const pipeline = new PeripheralConnectionRecordPipelineImpl(producer, [])
      markTraceRepositoryReady(pipeline)

      let started = await pipeline.start()
      pipeline.stop()

      expect(started).assertTrue()
      expect(producer.subscribeCalls).assertEqual(1)
      expect(producer.startCalls).assertEqual(1)
      expect(producer.stopCalls).assertEqual(1)
    })
  })
}

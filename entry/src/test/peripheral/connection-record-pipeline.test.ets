import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import {
  LogEventResult,
  PeripheralTraceRecord,
  PeripheralType
} from '../../main/ets/models/DataModels'
import { PeripheralTraceRepository } from '../../main/ets/services/PeripheralTraceRepository'
import { PeripheralConnectionRecordPipelineImpl } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline'
import {
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducer,
  PeripheralConnectionRecordProducerEvent,
  PeripheralConnectionRecordProducerListener,
  PeripheralConnectionRecordProducerStatus
} from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'

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

function createUsbEvent(eventName: string = 'usual.event.USB_ATTACHED'): PeripheralConnectionRecordProducerEvent {
  return {
    source: 'runtime',
    channel: 'usb',
    eventName,
    rawData: {}
  }
}

function createBluetoothEvent(): PeripheralConnectionRecordProducerEvent {
  return {
    source: 'runtime',
    channel: 'bluetooth_acl',
    eventName: 'usual.event.BLUETOOTH_ACL',
    rawData: {}
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

export default function peripheralConnectionRecordPipelineTest() {
  describe('PeripheralConnectionRecordPipeline', () => {
    let originalInit: (context: common.UIAbilityContext) => Promise<boolean>
    let originalAppend: (record: PeripheralTraceRecord) => Promise<boolean>
    let originalDateNow: () => number
    let nowValue: number
    let appendCount: number
    let appendedRecords: PeripheralTraceRecord[]

    beforeEach(() => {
      originalInit = PeripheralTraceRepository.init
      originalAppend = PeripheralTraceRepository.append
      originalDateNow = Date.now
      nowValue = 1000
      appendCount = 0
      appendedRecords = []

      Date.now = (): number => nowValue
      PeripheralTraceRepository.init = async (_context: common.UIAbilityContext): Promise<boolean> => true
      PeripheralTraceRepository.append = async (record: PeripheralTraceRecord): Promise<boolean> => {
        appendCount++
        appendedRecords.push(record)
        return true
      }
    })

    afterEach(() => {
      PeripheralTraceRepository.init = originalInit
      PeripheralTraceRepository.append = originalAppend
      Date.now = originalDateNow
    })

    it('should dedupe usb records within 1500ms window by deviceId|action|rawEventName', 0, async () => {
      const consumer: PeripheralConnectionRecordConsumer = {
        canHandle: (event: PeripheralConnectionRecordProducerEvent): boolean => event.channel === 'usb',
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => buildUsbRecord()
      }
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      const ok = await pipeline.bindContext({} as common.UIAbilityContext)
      expect(ok).assertTrue()

      const event = createUsbEvent()

      await pipeline.push(event)
      nowValue = 2000
      await pipeline.push(event)

      expect(appendCount).assertEqual(1)
    })

    it('should not apply usb dedupe window for bluetooth acl records', 0, async () => {
      const consumer: PeripheralConnectionRecordConsumer = {
        canHandle: (event: PeripheralConnectionRecordProducerEvent): boolean => event.channel === 'bluetooth_acl',
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => {
          return buildBluetoothRecord()
        }
      }
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      const ok = await pipeline.bindContext({} as common.UIAbilityContext)
      expect(ok).assertTrue()

      const event = createBluetoothEvent()

      await pipeline.push(event)
      nowValue = 1200
      await pipeline.push(event)

      expect(appendCount).assertEqual(2)
    })

    it('should skip consumers whose canHandle returns false', 0, async () => {
      let skippedConsumeCount = 0
      let handledConsumeCount = 0
      const skippedConsumer: PeripheralConnectionRecordConsumer = {
        canHandle: (_event: PeripheralConnectionRecordProducerEvent): boolean => false,
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => {
          skippedConsumeCount++
          return buildUsbRecord()
        }
      }
      const handledConsumer: PeripheralConnectionRecordConsumer = {
        canHandle: (event: PeripheralConnectionRecordProducerEvent): boolean => event.channel === 'usb',
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => {
          handledConsumeCount++
          return buildUsbRecord()
        }
      }
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [skippedConsumer, handledConsumer])
      await pipeline.bindContext({} as common.UIAbilityContext)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertTrue()
      expect(skippedConsumeCount).assertEqual(0)
      expect(handledConsumeCount).assertEqual(1)
      expect(appendCount).assertEqual(1)
    })

    it('should not append when consumer returns null', 0, async () => {
      let consumeCount = 0
      const consumer: PeripheralConnectionRecordConsumer = {
        canHandle: (event: PeripheralConnectionRecordProducerEvent): boolean => event.channel === 'usb',
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => {
          consumeCount++
          return null
        }
      }
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      await pipeline.bindContext({} as common.UIAbilityContext)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertFalse()
      expect(consumeCount).assertEqual(1)
      expect(appendCount).assertEqual(0)
    })

    it('should only append records produced by matching consumers', 0, async () => {
      let usbConsumeCount = 0
      let bluetoothConsumeCount = 0
      const usbConsumer: PeripheralConnectionRecordConsumer = {
        canHandle: (event: PeripheralConnectionRecordProducerEvent): boolean => event.channel === 'usb',
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => {
          usbConsumeCount++
          return buildUsbRecord()
        }
      }
      const bluetoothConsumer: PeripheralConnectionRecordConsumer = {
        canHandle: (event: PeripheralConnectionRecordProducerEvent): boolean => event.channel === 'bluetooth_acl',
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => {
          bluetoothConsumeCount++
          return buildBluetoothRecord()
        }
      }
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [bluetoothConsumer, usbConsumer])
      await pipeline.bindContext({} as common.UIAbilityContext)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertTrue()
      expect(usbConsumeCount).assertEqual(1)
      expect(bluetoothConsumeCount).assertEqual(0)
      expect(appendCount).assertEqual(1)
      expect(appendedRecords[0].deviceType).assertEqual(PeripheralType.USB_STORAGE)
    })

    it('should return false and skip append when trace repository init fails', 0, async () => {
      let consumeCount = 0
      PeripheralTraceRepository.init = async (_context: common.UIAbilityContext): Promise<boolean> => false
      const consumer: PeripheralConnectionRecordConsumer = {
        canHandle: (_event: PeripheralConnectionRecordProducerEvent): boolean => true,
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => {
          consumeCount++
          return buildUsbRecord()
        }
      }
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      await pipeline.bindContext({} as common.UIAbilityContext)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertFalse()
      expect(consumeCount).assertEqual(0)
      expect(appendCount).assertEqual(0)
    })

    it('should stay stable when append fails after consumer produces a record', 0, async () => {
      PeripheralTraceRepository.append = async (record: PeripheralTraceRecord): Promise<boolean> => {
        appendCount++
        appendedRecords.push(record)
        return false
      }
      const consumer: PeripheralConnectionRecordConsumer = {
        canHandle: (_event: PeripheralConnectionRecordProducerEvent): boolean => true,
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => buildUsbRecord()
      }
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      await pipeline.bindContext({} as common.UIAbilityContext)

      const processed = await pipeline.push(createUsbEvent())

      expect(processed).assertTrue()
      expect(appendCount).assertEqual(1)
      expect(appendedRecords.length).assertEqual(1)
    })

    it('should bind and start the new producer when attachProducer is called after start', 0, async () => {
      const firstProducer = new FakeProducer()
      const nextProducer = new FakeProducer()
      const pipeline = new PeripheralConnectionRecordPipelineImpl(firstProducer, [])
      const context = {} as common.UIAbilityContext

      const bindOk = await pipeline.bindContext(context)
      expect(bindOk).assertTrue()

      const started = await pipeline.start()
      expect(started).assertTrue()
      expect(firstProducer.bindContextCalls).assertEqual(2)
      expect(firstProducer.startCalls).assertEqual(1)
      expect(firstProducer.subscribeCalls).assertEqual(1)

      const attached = await pipeline.attachProducer(nextProducer)

      expect(attached).assertTrue()
      expect(firstProducer.unsubscribeCalls).assertEqual(1)
      expect(firstProducer.stopCalls).assertEqual(1)
      expect(nextProducer.bindContextCalls).assertEqual(1)
      expect(nextProducer.startCalls).assertEqual(1)
      expect(nextProducer.subscribeCalls).assertEqual(1)
      expect(nextProducer.lastContext).assertEqual(context)
    })

    it('should unsubscribe and stop producer on detachProducer', 0, async () => {
      const producer = new FakeProducer()
      const pipeline = new PeripheralConnectionRecordPipelineImpl(producer, [])

      await pipeline.bindContext({} as common.UIAbilityContext)
      await pipeline.start()
      pipeline.detachProducer()

      expect(producer.subscribeCalls).assertEqual(1)
      expect(producer.unsubscribeCalls).assertEqual(1)
      expect(producer.stopCalls).assertEqual(1)
      expect(producer.listeners.size).assertEqual(0)
    })
  })
}

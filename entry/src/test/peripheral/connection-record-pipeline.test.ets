import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { LogEventResult, PeripheralTraceRecord, PeripheralType } from '../../main/ets/models/DataModels'
import { PeripheralTraceRepository } from '../../main/ets/services/PeripheralTraceRepository'
import { PeripheralConnectionRecordPipelineImpl } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_pipeline'
import {
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent
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

export default function peripheralConnectionRecordPipelineTest() {
  describe('PeripheralConnectionRecordPipeline', () => {
    let originalInit: (context: common.UIAbilityContext) => Promise<boolean>
    let originalAppend: (record: PeripheralTraceRecord) => Promise<boolean>
    let originalDateNow: () => number
    let nowValue: number
    let appendCount: number

    beforeEach(() => {
      originalInit = PeripheralTraceRepository.init
      originalAppend = PeripheralTraceRepository.append
      originalDateNow = Date.now
      nowValue = 1000
      appendCount = 0

      Date.now = (): number => nowValue
      PeripheralTraceRepository.init = async (_context: common.UIAbilityContext): Promise<boolean> => true
      PeripheralTraceRepository.append = async (_record: PeripheralTraceRecord): Promise<boolean> => {
        appendCount++
        return true
      }
    })

    afterEach(() => {
      PeripheralTraceRepository.init = originalInit
      PeripheralTraceRepository.append = originalAppend
      Date.now = originalDateNow
    })

    it('should dedupe usb records within 1500ms window by deviceId|action|rawEventName', 0, async (done: Function) => {
      const consumer: PeripheralConnectionRecordConsumer = {
        canHandle: (event: PeripheralConnectionRecordProducerEvent): boolean => event.channel === 'usb',
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => buildUsbRecord()
      }
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      const ok = await pipeline.bindContext({} as common.UIAbilityContext)
      expect(ok).assertTrue()

      const event: PeripheralConnectionRecordProducerEvent = {
        source: 'runtime',
        channel: 'usb',
        eventName: 'usual.event.USB_ATTACHED',
        rawData: {}
      }

      await pipeline.push(event)
      nowValue = 2000
      await pipeline.push(event)

      expect(appendCount).assertEqual(1)
      done()
    })

    it('should not apply usb dedupe window for bluetooth acl records', 0, async (done: Function) => {
      const consumer: PeripheralConnectionRecordConsumer = {
        canHandle: (event: PeripheralConnectionRecordProducerEvent): boolean => event.channel === 'bluetooth_acl',
        consume: async (_event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralTraceRecord | null> => {
          return buildBluetoothRecord()
        }
      }
      const pipeline = new PeripheralConnectionRecordPipelineImpl(null, [consumer])
      const ok = await pipeline.bindContext({} as common.UIAbilityContext)
      expect(ok).assertTrue()

      const event: PeripheralConnectionRecordProducerEvent = {
        source: 'runtime',
        channel: 'bluetooth_acl',
        eventName: 'usual.event.BLUETOOTH_ACL',
        rawData: {}
      }

      await pipeline.push(event)
      nowValue = 1200
      await pipeline.push(event)

      expect(appendCount).assertEqual(2)
      done()
    })
  })
}

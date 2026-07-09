import { common } from '@kit.AbilityKit'
import { PeripheralTraceRecord } from '../../../models/PeripheralModels'
import { PeripheralTraceMaintenanceService } from './PeripheralTraceMaintenanceService'
import { LogUtils } from '../../../utils/LogUtils'
import {
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordPipeline,
  PeripheralConnectionRecordProducer,
  PeripheralConnectionRecordProducerEvent
} from './PeripheralConnectionRecordProducerContract'

const TAG = 'ConnectionRecordPipeline'
const USB_DEDUPE_WINDOW_MS = 1500

export class PeripheralConnectionRecordPipelineImpl implements PeripheralConnectionRecordPipeline {
  private producerListenerId: number = 0
  private lastSeenByKey: Map<string, number> = new Map()
  private context: common.UIAbilityContext | null = null
  private traceRepositoryReady: boolean = false
  private started: boolean = false
  private producer: PeripheralConnectionRecordProducer | null
  private consumers: PeripheralConnectionRecordConsumer[]

  constructor(producer: PeripheralConnectionRecordProducer | null, consumers: PeripheralConnectionRecordConsumer[]) {
    this.producer = producer
    this.consumers = consumers
  }

  async bindContext(context: common.UIAbilityContext): Promise<boolean> {
    this.context = context
    if (this.producer?.bindContext) {
      this.producer.bindContext(context)
    }
    return this.ensureTraceRepositoryReady()
  }

  async attachProducer(producer: PeripheralConnectionRecordProducer | null): Promise<boolean> {
    if (this.producer === producer) {
      if (producer?.bindContext && this.context) {
        producer.bindContext(this.context)
      }
      return this.started ? this.start() : true
    }
    this.detachProducer()
    this.producer = producer
    if (!producer) {
      return true
    }
    if (producer.bindContext && this.context) {
      producer.bindContext(this.context)
    }
    if (!this.started) {
      return true
    }
    return this.start()
  }

  detachProducer(): void {
    if (!this.producer) {
      return
    }
    if (this.producerListenerId > 0) {
      this.producer.unsubscribe(this.producerListenerId)
      this.producerListenerId = 0
    }
    this.producer.stop()
    this.producer = null
  }

  async start(): Promise<boolean> {
    this.started = true
    if (!this.producer) {
      return true
    }
    if (this.producer.bindContext && this.context) {
      this.producer.bindContext(this.context)
    }
    if (this.producerListenerId <= 0) {
      this.producerListenerId = this.producer.subscribe((event: PeripheralConnectionRecordProducerEvent) => {
        this.push(event)
      })
    }
    const started = await this.producer.start()
    if (!started) {
      this.producer.unsubscribe(this.producerListenerId)
      this.producerListenerId = 0
    }
    return started
  }

  stop(): void {
    this.started = false
    if (!this.producer) {
      return
    }
    if (this.producerListenerId > 0) {
      this.producer.unsubscribe(this.producerListenerId)
      this.producerListenerId = 0
    }
    this.producer.stop()
  }

  async push(event: PeripheralConnectionRecordProducerEvent): Promise<boolean> {
    const traceReady = await this.ensureTraceRepositoryReady()
    if (!traceReady) {
      LogUtils.warn(TAG, `skip runtime event: storage not ready, channel=${event.channel}`)
      return false
    }
    let persisted: boolean = false
    for (let index = 0; index < this.consumers.length; index++) {
      const consumer = this.consumers[index]
      if (!consumer.canHandle(event)) {
        continue
      }
      const record = await consumer.consume(event)
      if (!record) {
        continue
      }
      if (this.shouldSkipByDedupe(event, record)) {
        continue
      }
      const appended = await PeripheralTraceMaintenanceService.appendEntries([record])
      if (!appended.success) {
        LogUtils.warn(TAG, `append failed: channel=${event.channel}, deviceId=${record.deviceId}, code=${appended.code}`)
        continue
      }
      persisted = true
    }
    return persisted
  }

  private shouldSkipByDedupe(event: PeripheralConnectionRecordProducerEvent, record: PeripheralTraceRecord): boolean {
    if (event.channel !== 'usb') {
      return false
    }
    const now = Date.now()
    const dedupeKey = `${record.deviceId}|${record.action}|${record.rawEventName ?? ''}`
    const lastSeen = this.lastSeenByKey.get(dedupeKey) || 0
    if (now - lastSeen < USB_DEDUPE_WINDOW_MS) {
      return true
    }
    this.lastSeenByKey.set(dedupeKey, now)
    return false
  }

  private async ensureTraceRepositoryReady(): Promise<boolean> {
    if (this.traceRepositoryReady) {
      return true
    }
    if (!this.context) {
      return false
    }
    const initialized = await PeripheralTraceMaintenanceService.initialize(this.context)
    this.traceRepositoryReady = initialized.success
    return initialized.success
  }
}

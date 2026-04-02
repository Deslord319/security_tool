import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PeripheralDevicePolicyRepository } from './PeripheralDevicePolicyRepository'
import { PeripheralConnectionRecordBluetoothAclConsumer } from './peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer'
import { PeripheralConnectionRecordPipelineImpl } from './peripheral/connection-record/peripheral_connection_record_pipeline'
import type { PeripheralConnectionRecordProducerCapabilities } from './peripheral/connection-record/peripheral_connection_record_producer_contract'
import { PeripheralConnectionRecordRuntimeProducerAdapter } from './peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter'
import { PeripheralConnectionRecordUsbConsumer } from './peripheral/connection-record/peripheral_connection_record_usb_consumer'

const TAG = 'PeripheralRuntimeEvent'
const DOMAIN = 0x000A

interface PeripheralRuntimeCapabilities {
  usbRuntimeEvents: boolean
  bluetoothRuntimeEvents: boolean
  degradedReason?: string
}

interface PeripheralRuntimeStatus {
  running: boolean
  capabilities: PeripheralRuntimeCapabilities
}

export class PeripheralRuntimeEventService {
  private static context: common.UIAbilityContext | null = null
  private static initialized: boolean = false
  private static running: boolean = false
  private static capabilities: PeripheralRuntimeCapabilities = {
    usbRuntimeEvents: false,
    bluetoothRuntimeEvents: false,
    degradedReason: 'not_started'
  }
  private static runtimePipeline: PeripheralConnectionRecordPipelineImpl | null = null
  private static runtimeProducer: PeripheralConnectionRecordRuntimeProducerAdapter | null = null

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    PeripheralRuntimeEventService.context = context

    const pipeline = PeripheralRuntimeEventService.getRuntimePipeline()
    const traceInited = await pipeline.bindContext(context)
    const producerAttached = await pipeline.attachProducer(PeripheralRuntimeEventService.getRuntimeProducer())
    const policyInited = await PeripheralDevicePolicyRepository.init(context)

    PeripheralRuntimeEventService.initialized = traceInited && producerAttached && policyInited
    if (!PeripheralRuntimeEventService.initialized) {
      PeripheralRuntimeEventService.capabilities = {
        usbRuntimeEvents: false,
        bluetoothRuntimeEvents: false,
        degradedReason: PeripheralRuntimeEventService.buildInitDegradedReason(traceInited, producerAttached, policyInited)
      }
      return false
    }

    PeripheralRuntimeEventService.capabilities = PeripheralRuntimeEventService.toRuntimeCapabilities(
      PeripheralRuntimeEventService.getRuntimeProducer().getStatus().capabilities
    )
    return true
  }

  static async start(): Promise<boolean> {
    if (!PeripheralRuntimeEventService.initialized) {
      if (!PeripheralRuntimeEventService.context) {
        PeripheralRuntimeEventService.capabilities = {
          usbRuntimeEvents: false,
          bluetoothRuntimeEvents: false,
          degradedReason: 'not_initialized'
        }
        return false
      }
      const initialized = await PeripheralRuntimeEventService.init(PeripheralRuntimeEventService.context)
      if (!initialized) {
        return false
      }
    }

    const started = await PeripheralRuntimeEventService.getRuntimePipeline().start()
    const producerStatus = PeripheralRuntimeEventService.getRuntimeProducer().getStatus()
    PeripheralRuntimeEventService.running = started && producerStatus.running
    PeripheralRuntimeEventService.capabilities = PeripheralRuntimeEventService.toRuntimeCapabilities(
      producerStatus.capabilities
    )
    hilog.info(
      DOMAIN,
      TAG,
      `start complete, running=${PeripheralRuntimeEventService.running}, usb=${producerStatus.capabilities.usbRuntimeEvents}, bluetooth=${producerStatus.capabilities.bluetoothRuntimeEvents}, degradedReason=${producerStatus.capabilities.degradedReason ?? 'none'}`
    )
    return PeripheralRuntimeEventService.running
  }

  static stop(): void {
    PeripheralRuntimeEventService.running = false
    if (PeripheralRuntimeEventService.runtimePipeline) {
      PeripheralRuntimeEventService.runtimePipeline.stop()
    }
    if (PeripheralRuntimeEventService.runtimeProducer) {
      PeripheralRuntimeEventService.capabilities = PeripheralRuntimeEventService.toRuntimeCapabilities(
        PeripheralRuntimeEventService.runtimeProducer.getStatus().capabilities
      )
    }
  }

  static getStatus(): PeripheralRuntimeStatus {
    const capabilities = PeripheralRuntimeEventService.probeCapabilities()
    return {
      running: PeripheralRuntimeEventService.running,
      capabilities: capabilities
    }
  }

  static probeCapabilities(): PeripheralRuntimeCapabilities {
    if (PeripheralRuntimeEventService.runtimeProducer) {
      return PeripheralRuntimeEventService.toRuntimeCapabilities(
        PeripheralRuntimeEventService.runtimeProducer.getStatus().capabilities
      )
    }
    return {
      usbRuntimeEvents: PeripheralRuntimeEventService.capabilities.usbRuntimeEvents,
      bluetoothRuntimeEvents: PeripheralRuntimeEventService.capabilities.bluetoothRuntimeEvents,
      degradedReason: PeripheralRuntimeEventService.capabilities.degradedReason
    }
  }

  private static getRuntimeProducer(): PeripheralConnectionRecordRuntimeProducerAdapter {
    if (!PeripheralRuntimeEventService.runtimeProducer) {
      PeripheralRuntimeEventService.runtimeProducer = new PeripheralConnectionRecordRuntimeProducerAdapter()
    }
    if (PeripheralRuntimeEventService.context) {
      PeripheralRuntimeEventService.runtimeProducer.bindContext(PeripheralRuntimeEventService.context)
    }
    return PeripheralRuntimeEventService.runtimeProducer
  }

  private static getRuntimePipeline(): PeripheralConnectionRecordPipelineImpl {
    if (!PeripheralRuntimeEventService.runtimePipeline) {
      PeripheralRuntimeEventService.runtimePipeline = new PeripheralConnectionRecordPipelineImpl(
        PeripheralRuntimeEventService.getRuntimeProducer(),
        [
          new PeripheralConnectionRecordUsbConsumer(),
          new PeripheralConnectionRecordBluetoothAclConsumer()
        ]
      )
    }
    return PeripheralRuntimeEventService.runtimePipeline
  }

  private static buildInitDegradedReason(
    traceInited: boolean,
    producerAttached: boolean,
    policyInited: boolean
  ): string {
    if (!traceInited) {
      return 'trace_repo_init_failed'
    }
    if (!producerAttached) {
      return 'runtime_producer_attach_failed'
    }
    if (!policyInited) {
      return 'device_policy_repo_init_failed'
    }
    return 'not_initialized'
  }

  private static toRuntimeCapabilities(
    capabilities: PeripheralConnectionRecordProducerCapabilities
  ): PeripheralRuntimeCapabilities {
    return {
      usbRuntimeEvents: capabilities.usbRuntimeEvents,
      bluetoothRuntimeEvents: capabilities.bluetoothRuntimeEvents,
      degradedReason: capabilities.degradedReason
    }
  }
}

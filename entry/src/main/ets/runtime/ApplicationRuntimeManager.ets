import { common } from '@kit.AbilityKit'
import { LogCollectorService } from '../services/log-manage/collector/LogCollectorService'
import { PeripheralDevicePolicyRepository } from '../services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { PeripheralTraceMaintenanceService } from '../services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { PeripheralConnectionRecordBluetoothAclConsumer } from '../services/peripheral/connection-record/peripheral_connection_record_bluetooth_acl_consumer'
import { PeripheralConnectionRecordPipelineImpl } from '../services/peripheral/connection-record/peripheral_connection_record_pipeline'
import { PeripheralConnectionRecordRuntimeProducerAdapter } from '../services/peripheral/connection-record/peripheral_connection_record_runtime_producer_adapter'
import { PeripheralConnectionRecordUsbConsumer } from '../services/peripheral/connection-record/peripheral_connection_record_usb_consumer'
import { LogManageViewModel } from '../viewmodels/log-manage/overview/LogManageViewModel'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'ApplicationRuntime'
const TRACE_RETENTION_DAYS = 180
const TRACE_MAX_ENTRIES = 200000

export class ApplicationRuntimeManager {
  private static instance?: ApplicationRuntimeManager

  private context: common.UIAbilityContext | null = null
  private logRuntimeInitialized: boolean = false
  private peripheralRuntimeInitialized: boolean = false
  private logRuntimeInitPromise: Promise<void> | null = null
  private peripheralRuntimeInitPromise: Promise<void> | null = null
  private readonly logManageViewModel: LogManageViewModel = new LogManageViewModel()
  private readonly connectionRecordProducer: PeripheralConnectionRecordRuntimeProducerAdapter =
    new PeripheralConnectionRecordRuntimeProducerAdapter()
  private readonly connectionRecordPipeline: PeripheralConnectionRecordPipelineImpl =
    new PeripheralConnectionRecordPipelineImpl(this.connectionRecordProducer, [
      new PeripheralConnectionRecordUsbConsumer(),
      new PeripheralConnectionRecordBluetoothAclConsumer()
    ])

  static getInstance(): ApplicationRuntimeManager {
    if (!ApplicationRuntimeManager.instance) {
      ApplicationRuntimeManager.instance = new ApplicationRuntimeManager()
    }
    return ApplicationRuntimeManager.instance
  }

  bindContext(context: common.UIAbilityContext): void {
    this.context = context
  }

  getLogManageViewModel(): LogManageViewModel {
    return this.logManageViewModel
  }

  async initializeAll(): Promise<void> {
    await this.ensureRuntimeServices()
  }

  async ensureRuntimeServices(): Promise<void> {
    await this.ensureLogRuntimeInitialized()
    await this.ensurePeripheralRuntimeInitialized()
    await this.ensureCollectorsRunning()
  }

  async refreshLogManageData(): Promise<void> {
    let context = this.requireContext()
    let viewModel = this.logManageViewModel
    if (!viewModel.state.initialized) {
      let initResult = await viewModel.initialize(context)
      if (!initResult.success) {
        LogUtils.warn(TAG, `LogManageViewModel initialize failed: ${initResult.code}`)
        return
      }
    }
    try {
      viewModel.activate()
    } catch (_err) {
    }
    let refreshResult = await viewModel.refreshAll()
    if (!refreshResult.success) {
      LogUtils.warn(TAG, `LogManageViewModel refresh failed: ${refreshResult.code}`)
    }
  }

  private async ensureLogRuntimeInitialized(): Promise<void> {
    if (!this.logRuntimeInitPromise) {
      this.logRuntimeInitPromise = this.initializeLogRuntime().finally(() => {
        if (!this.logRuntimeInitialized) {
          this.logRuntimeInitPromise = null
        }
      })
    }
    await this.logRuntimeInitPromise
  }

  private async ensurePeripheralRuntimeInitialized(): Promise<void> {
    if (!this.peripheralRuntimeInitPromise) {
      this.peripheralRuntimeInitPromise = this.initializePeripheralRuntime().finally(() => {
        if (!this.peripheralRuntimeInitialized) {
          this.peripheralRuntimeInitPromise = null
        }
      })
    }
    await this.peripheralRuntimeInitPromise
  }

  private async initializeLogRuntime(): Promise<void> {
    if (this.logRuntimeInitialized) {
      return
    }
    let context = this.requireContext()
    let collectorInited = await LogCollectorService.init(context)
    if (!collectorInited.success) {
      LogUtils.error(TAG, `LogCollectorService init failed: ${collectorInited.code}`)
      return
    }
    this.logRuntimeInitialized = true
    LogUtils.info(TAG, 'initializeLogRuntime success')
  }

  private async initializePeripheralRuntime(): Promise<void> {
    if (this.peripheralRuntimeInitialized) {
      return
    }
    let context = this.requireContext()
    let traceRepoInited = await this.connectionRecordPipeline.bindContext(context)
    if (!traceRepoInited) {
      LogUtils.error(TAG, 'connection record pipeline bindContext failed')
      return
    }

    let traceConfigured = await PeripheralTraceMaintenanceService.configure(TRACE_RETENTION_DAYS, TRACE_MAX_ENTRIES)
    if (!traceConfigured.success) {
      LogUtils.error(TAG, `PeripheralTraceMaintenanceService configure failed: ${traceConfigured.code}`)
      return
    }

    let devicePolicyInited = await PeripheralDevicePolicyRepository.init(context)
    if (!devicePolicyInited) {
      LogUtils.error(TAG, 'PeripheralDevicePolicyRepository init failed')
      return
    }

    let producerAttached = await this.connectionRecordPipeline.attachProducer(this.connectionRecordProducer)
    if (!producerAttached) {
      LogUtils.error(TAG, 'connection record pipeline attachProducer failed')
      return
    }

    this.peripheralRuntimeInitialized = true
    LogUtils.info(TAG, 'initializePeripheralRuntime success')
  }

  private async ensureCollectorsRunning(): Promise<void> {
    let collectorStatus = LogCollectorService.getStatus()
    if (this.logRuntimeInitialized && !collectorStatus.running) {
      let collectorStarted = await LogCollectorService.start()
      LogUtils.info(TAG,
        `ensureCollectorsRunning log collector start result: started=${collectorStarted.success}, code=${collectorStarted.code}`)
      if (!collectorStarted.success) {
        LogUtils.warn(TAG, `LogCollectorService restart failed: ${collectorStarted.code}`)
      }
    }

    let runtimeStatus = this.connectionRecordProducer.getStatus()
    if (this.peripheralRuntimeInitialized && !runtimeStatus.running) {
      let runtimeStarted = await this.connectionRecordPipeline.start()
      let latestStatus = this.connectionRecordProducer.getStatus()
      LogUtils.info(TAG,
        `ensureCollectorsRunning peripheral runtime start result: started=${runtimeStarted}, usb=${latestStatus.capabilities.usbRuntimeEvents}, bluetooth=${latestStatus.capabilities.bluetoothRuntimeEvents}, reason=${latestStatus.capabilities.degradedReason ?? 'none'}`)
      if (!runtimeStarted) {
        LogUtils.warn(TAG, 'connection record runtime start failed')
      }
    }
  }

  private requireContext(): common.UIAbilityContext {
    if (!this.context) {
      throw new Error('Application runtime context is not bound')
    }
    return this.context
  }
}

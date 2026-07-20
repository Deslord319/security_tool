import { common } from '@kit.AbilityKit'
import { LogCollectorService } from '../services/log-manage/collector/LogCollectorService'
import { PeripheralDevicePolicyRepository } from '../services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { UsbDevicePolicyStateRepository } from '../services/peripheral/device-policy/UsbDevicePolicyStateRepository'
import { PeripheralTraceMaintenanceService } from '../services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { PermissionPolicyLocalRepository } from '../services/permission-manage/PermissionPolicyLocalRepository'
import { PeripheralConnectionRecordBluetoothAclConsumer } from '../services/peripheral/connection-record/PeripheralConnectionRecordBluetoothAclConsumer'
import { PeripheralConnectionRecordPipelineImpl } from '../services/peripheral/connection-record/PeripheralConnectionRecordPipeline'
import { PeripheralConnectionRecordRuntimeProducerAdapter } from '../services/peripheral/connection-record/PeripheralConnectionRecordRuntimeProducerAdapter'
import { PeripheralConnectionRecordUsbConsumer } from '../services/peripheral/connection-record/PeripheralConnectionRecordUsbConsumer'
import { BluetoothConnectionRecordCoordinator } from '../services/peripheral/connection-record/BluetoothConnectionRecordCoordinator'
import { AccountChangeEventPayload } from '../services/account/AccountChangeEventBus'
import { AccountRuntimeService } from '../services/account/AccountRuntimeService'
import { UserFirewallOption } from '../models/firewall/FirewallModels'
import { SystemUserProvider } from '../services/firewall/providers/SystemUserProvider'
import { FirewallOverviewViewModel } from '../viewmodels/firewall/overview/FirewallOverviewViewModel'
import { FirewallRulesViewModel } from '../viewmodels/firewall/rules/FirewallRulesViewModel'
import { IdentitySettingsViewModel } from '../viewmodels/identity/settings/IdentitySettingsViewModel'
import { LogManageViewModel } from '../viewmodels/log-manage/overview/LogManageViewModel'
import { PeripheralViewModel } from '../viewmodels/peripheral/overview/PeripheralViewModel'
import { PermissionViewModel } from '../viewmodels/permission-manage/PermissionViewModel'
import { ToolSettingsViewModel } from '../viewmodels/tool-settings/system-settings/ToolSettingsViewModel'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'ApplicationRuntime'
const TRACE_RETENTION_DAYS = 180
const TRACE_MAX_ENTRIES = 200000

export class ApplicationRuntimeManager {
  private static instance?: ApplicationRuntimeManager

  private context: common.UIAbilityContext | null = null
  private logRuntimeInitialized: boolean = false
  private identityRuntimeInitialized: boolean = false
  private peripheralRuntimeInitialized: boolean = false
  private permissionRuntimeInitialized: boolean = false
  private logRuntimeInitPromise: Promise<void> | null = null
  private identityRuntimeInitPromise: Promise<void> | null = null
  private peripheralRuntimeInitPromise: Promise<void> | null = null
  private permissionRuntimeInitPromise: Promise<void> | null = null
  private lastPermissionAccountEventTimestamp: number = 0
  private readonly firewallOverviewViewModel: FirewallOverviewViewModel = new FirewallOverviewViewModel()
  private readonly firewallRulesViewModel: FirewallRulesViewModel = new FirewallRulesViewModel()
  private readonly identitySettingsViewModel: IdentitySettingsViewModel = new IdentitySettingsViewModel()
  private readonly logManageViewModel: LogManageViewModel = new LogManageViewModel()
  private readonly peripheralViewModel: PeripheralViewModel = new PeripheralViewModel()
  private readonly permissionViewModel: PermissionViewModel = new PermissionViewModel()
  private readonly toolSettingsViewModel: ToolSettingsViewModel = new ToolSettingsViewModel()
  private readonly accountRuntimeService: AccountRuntimeService = new AccountRuntimeService(
    async (payload: AccountChangeEventPayload): Promise<void> => {
      await this.handleAccountChange(payload)
    }
  )
  private readonly connectionRecordProducer: PeripheralConnectionRecordRuntimeProducerAdapter =
    new PeripheralConnectionRecordRuntimeProducerAdapter()
  private readonly bluetoothConnectionRecordCoordinator: BluetoothConnectionRecordCoordinator =
    new BluetoothConnectionRecordCoordinator()
  private readonly connectionRecordPipeline: PeripheralConnectionRecordPipelineImpl =
    new PeripheralConnectionRecordPipelineImpl(this.connectionRecordProducer, [
      new PeripheralConnectionRecordUsbConsumer(),
      new PeripheralConnectionRecordBluetoothAclConsumer()
    ], this.bluetoothConnectionRecordCoordinator)

  static getInstance(): ApplicationRuntimeManager {
    if (!ApplicationRuntimeManager.instance) {
      ApplicationRuntimeManager.instance = new ApplicationRuntimeManager()
    }
    return ApplicationRuntimeManager.instance
  }

  bindContext(context: common.UIAbilityContext): void {
    this.context = context
    this.accountRuntimeService.start()
  }

  release(): void {
    this.accountRuntimeService.stop()
  }

  getFirewallOverviewViewModel(): FirewallOverviewViewModel {
    return this.firewallOverviewViewModel
  }

  getFirewallRulesViewModel(): FirewallRulesViewModel {
    return this.firewallRulesViewModel
  }

  getLogManageViewModel(): LogManageViewModel {
    return this.logManageViewModel
  }

  getIdentitySettingsViewModel(): IdentitySettingsViewModel {
    return this.identitySettingsViewModel
  }

  getPeripheralViewModel(): PeripheralViewModel {
    return this.peripheralViewModel
  }

  getPermissionViewModel(): PermissionViewModel {
    return this.permissionViewModel
  }

  getToolSettingsViewModel(): ToolSettingsViewModel {
    return this.toolSettingsViewModel
  }

  async ensureRuntimeServices(): Promise<void> {
    await Promise.all([
      this.ensureLogRuntimeInitialized(),
      this.ensureIdentityRuntimeInitialized(),
      this.ensurePeripheralRuntimeInitialized(),
      this.ensurePermissionRuntimeInitialized()
    ])
    await this.ensureCollectorsRunning()
  }

  async ensureLogRuntimeServices(): Promise<void> {
    await this.ensureLogRuntimeInitialized()
    await this.ensureCollectorsRunning()
  }

  async ensureIdentityRuntimeServices(): Promise<void> {
    await this.ensureIdentityRuntimeInitialized()
    await this.identitySettingsViewModel.activate()
  }

  async ensurePeripheralRuntimeServices(): Promise<void> {
    await this.ensurePeripheralRuntimeInitialized()
    await this.ensureCollectorsRunning()
  }

  async ensurePermissionRuntimeServices(): Promise<void> {
    await this.ensurePermissionRuntimeInitialized()
    await this.refreshPermissionForLatestAccountState()
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
    } catch (err) {
      LogUtils.warn(TAG, `LogManageViewModel activate failed: ${JSON.stringify(err)}`)
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

  private async ensureIdentityRuntimeInitialized(): Promise<void> {
    if (!this.identityRuntimeInitPromise) {
      this.identityRuntimeInitPromise = this.initializeIdentityRuntime().finally(() => {
        if (!this.identityRuntimeInitialized) {
          this.identityRuntimeInitPromise = null
        }
      })
    }
    await this.identityRuntimeInitPromise
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

  private async ensurePermissionRuntimeInitialized(): Promise<void> {
    if (!this.permissionRuntimeInitPromise) {
      this.permissionRuntimeInitPromise = this.initializePermissionRuntime().finally(() => {
        if (!this.permissionRuntimeInitialized) {
          this.permissionRuntimeInitPromise = null
        }
      })
    }
    await this.permissionRuntimeInitPromise
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

  private async initializeIdentityRuntime(): Promise<void> {
    if (this.identityRuntimeInitialized) {
      return
    }
    this.identityRuntimeInitialized = true
    LogUtils.info(TAG, 'initializeIdentityRuntime success')
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
    let usbPolicyStateInited = await UsbDevicePolicyStateRepository.init(context)
    if (!usbPolicyStateInited) {
      LogUtils.error(TAG, 'UsbDevicePolicyStateRepository init failed')
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

  private async initializePermissionRuntime(): Promise<void> {
    if (this.permissionRuntimeInitialized) {
      return
    }
    let context = this.requireContext()
    let localRepoInited = await PermissionPolicyLocalRepository.init(context)
    if (!localRepoInited) {
      LogUtils.warn(TAG, 'PermissionPolicyLocalRepository init failed')
    }
    if (this.permissionViewModel.state.initialized) {
      this.permissionRuntimeInitialized = true
      LogUtils.info(TAG, 'initializePermissionRuntime reuse initialized permission state')
      return
    }
    await this.permissionViewModel.loadInitialState()
    this.permissionRuntimeInitialized = this.permissionViewModel.state.initialized
    if (this.permissionRuntimeInitialized) {
      LogUtils.info(TAG, 'initializePermissionRuntime success')
    } else {
      LogUtils.warn(TAG, 'initializePermissionRuntime skipped: permission page state not initialized')
    }
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

  private async handleAccountChange(payload: AccountChangeEventPayload): Promise<void> {
    await Promise.all([
      this.refreshPermissionForAccountChange(payload),
      this.refreshFirewallOverviewForAccountChange(),
      this.refreshFirewallRulesForAccountChange()
    ])
  }

  private async refreshPermissionForLatestAccountState(): Promise<void> {
    let payload = this.accountRuntimeService.getLatestPayload()
    if (!payload || payload.timestamp <= this.lastPermissionAccountEventTimestamp) {
      return
    }
    await this.refreshPermissionForAccountChange(payload)
  }

  private async refreshPermissionForAccountChange(payload: AccountChangeEventPayload): Promise<void> {
    if (!this.permissionRuntimeInitialized && !this.permissionViewModel.state.initialized) {
      return
    }
    try {
      let success = await this.permissionViewModel.refreshForAccountChange()
      if (success) {
        this.lastPermissionAccountEventTimestamp = payload.timestamp
      }
    } catch (err) {
      LogUtils.warn(TAG, `refresh permission for account change failed: ${JSON.stringify(err)}`)
    }
  }

  private async refreshFirewallOverviewForAccountChange(): Promise<void> {
    let context = this.context
    if (!context || !this.firewallOverviewViewModel.state.initialized) {
      return
    }
    try {
      await this.firewallOverviewViewModel.refresh(context)
    } catch (err) {
      LogUtils.warn(TAG, `refresh firewall overview for account change failed: ${JSON.stringify(err)}`)
    }
  }

  private async refreshFirewallRulesForAccountChange(): Promise<void> {
    let context = this.context
    if (!context || !this.firewallRulesViewModel.hasLoadedData()) {
      return
    }
    try {
      let users: UserFirewallOption[] = (await SystemUserProvider.loadAvailableUserIds()).users
      await this.firewallRulesViewModel.refreshForAccountChange(context, users)
    } catch (err) {
      LogUtils.warn(TAG, `refresh firewall rules for account change failed: ${JSON.stringify(err)}`)
    }
  }
}

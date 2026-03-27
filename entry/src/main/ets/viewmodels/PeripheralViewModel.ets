/**
 * Peripheral page coordinator ViewModel.
 */
import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AdminActivationState, PeripheralConnectionRecord, PeripheralType } from '../models/DataModels'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { PeripheralRuntimeEventService } from '../services/PeripheralRuntimeEventService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { InterfaceControlViewModel } from './InterfaceControlViewModel'
import { PeripheralPolicyViewModel } from './PeripheralPolicyViewModel'
import { PeripheralRecordViewModel } from './PeripheralRecordViewModel'
import { PeripheralViewModelReasons } from './PeripheralViewModelReasons'

const TAG = 'PeripheralViewModel'
const DOMAIN = 0x0013

@Observed
export class PeripheralViewModel {
  adminState: AdminActivationState = {
    activated: false,
    enableCommand: EnterpriseAdminService.buildEnableCommand(),
    adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE
  }

  isLoading: boolean = false
  reasonCode: string | null = null
  currentTab: number = 0
  onRefresh?: () => void
  interfaceControl: InterfaceControlViewModel = new InterfaceControlViewModel()
  records: PeripheralRecordViewModel = new PeripheralRecordViewModel()
  policy: PeripheralPolicyViewModel = new PeripheralPolicyViewModel()

  private traceStorageListenerId: number = -1
  private runtimeEventListenerId: number = -1
  private appContext: common.UIAbilityContext | null = null

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.isLoading = true
    this.appContext = context
    try {
      await this.reloadAllData()
      this.traceStorageListenerId = PeripheralTraceRepository.addChangeListener(() => {
        this.refreshTraceDrivenData()
      })
      this.runtimeEventListenerId = PeripheralRuntimeEventService.addUsbEventListener(() => {
        this.refreshTraceDrivenData()
      })
      this.reasonCode = null
    } catch (err) {
      this.reasonCode = PeripheralViewModelReasons.REASON_INIT_FAILED
      hilog.error(DOMAIN, TAG, `initialize failed: ${JSON.stringify(err)}`)
    } finally {
      this.isLoading = false
    }
  }

  destroy(): void {
    if (this.traceStorageListenerId > 0) {
      PeripheralTraceRepository.removeChangeListener(this.traceStorageListenerId)
      this.traceStorageListenerId = -1
    }
    if (this.runtimeEventListenerId > 0) {
      PeripheralRuntimeEventService.removeUsbEventListener(this.runtimeEventListenerId)
      this.runtimeEventListenerId = -1
    }
  }

  async reloadAllData(): Promise<void> {
    this.refreshAdminActivationState()
    this.interfaceControl.reloadState()
    this.policy.reloadWhitelistBlacklist()
    this.records.reloadRecords()
    this.policy.rebuildRecords(this.records.records)
    this.notifyRefresh('reloadAllData')
  }

  refreshAdminActivationState(): void {
    this.adminState = EnterpriseAdminService.probeActivation()
  }

  ensureAdminReady(): boolean {
    this.refreshAdminActivationState()
    if (this.adminState.activated) {
      return true
    }
    this.reasonCode = PeripheralViewModelReasons.REASON_ADMIN_REQUIRED
    return false
  }

  reloadDeviceRecords(): void {
    this.records.reloadRecords()
    this.policy.rebuildRecords(this.records.records)
    this.notifyRefresh('reloadDeviceRecords')
  }

  private refreshTraceDrivenData(): void {
    this.records.reloadRecords()
    this.policy.reloadWhitelistBlacklist()
    this.policy.rebuildRecords(this.records.records)
    this.notifyRefresh('refreshTraceDrivenData')
  }

  private notifyRefresh(source: string): void {
    try {
      this.onRefresh && this.onRefresh()
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `onRefresh callback failed: ${JSON.stringify(err)}`)
    }
    hilog.info(
      DOMAIN,
      TAG,
      `source=${source}, records=${this.records.records.length}, policyRecords=${this.policy.records.length}`
    )
  }

  async toggleInterface(feature: string, disallow: boolean): Promise<boolean> {
    if (!this.ensureAdminReady()) {
      return false
    }
    this.reasonCode = await this.interfaceControl.toggleInterface(feature, disallow)
    return this.reasonCode === null
  }

  async setUsbStoragePolicy(index: number): Promise<boolean> {
    if (!this.ensureAdminReady()) {
      return false
    }
    this.reasonCode = await this.interfaceControl.setUsbStoragePolicy(index)
    if (this.reasonCode !== null) {
      return false
    }
    this.policy.reloadWhitelistBlacklist()
    this.policy.rebuildRecords(this.records.records)
    this.notifyRefresh('setUsbStoragePolicy')
    return true
  }

  async handlePeripheralPolicyChange(deviceId: string, deviceType: PeripheralType, policyIndex: number): Promise<boolean> {
    if (!this.ensureAdminReady()) {
      return false
    }
    this.reasonCode = await this.policy.changePolicy(deviceId, deviceType, policyIndex)
    if (this.reasonCode !== null) {
      return false
    }
    await this.reloadAllData()
    return true
  }

  async exportConnectionHistory(): Promise<boolean> {
    this.reasonCode = await this.records.exportConnectionHistory(this.appContext)
    return this.reasonCode === null
  }

  async exportPeripheralPolicyRecords(): Promise<boolean> {
    this.reasonCode = await this.policy.exportRecords(this.appContext)
    return this.reasonCode === null
  }

  async clearPeripheralPolicyRecords(): Promise<boolean> {
    if (!this.appContext) {
      return false
    }
    try {
      await PeripheralTraceRepository.init(this.appContext)
      const success = await PeripheralTraceRepository.clearAll()
      if (!success) {
        return false
      }
      this.policy.resetUpdatingState()
      await this.reloadAllData()
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `clearPeripheralPolicyRecords failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  openConnectionDetailDialog(record: PeripheralConnectionRecord): void {
    this.records.openConnectionDetailDialog(record)
    this.notifyRefresh('openConnectionDetailDialog')
  }

  closeConnectionDetailDialog(): void {
    this.records.closeConnectionDetailDialog()
    this.notifyRefresh('closeConnectionDetailDialog')
  }

  switchToTab(index: number): void {
    if (index < 0 || index > 2 || index === this.currentTab) {
      return
    }
    this.currentTab = index
  }
}

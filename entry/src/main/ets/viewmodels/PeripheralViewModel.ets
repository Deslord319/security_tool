import { LogUtils } from '../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { PeripheralStrings } from '../constants/modules/PeripheralStrings'
import { AdminActivationState, ExportActionResult, PeripheralConnectionRecord, PeripheralType } from '../models/DataModels'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { PeripheralDevicePolicyRepository } from '../services/PeripheralDevicePolicyRepository'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { InterfaceControlViewModel } from './InterfaceControlViewModel'
import { PeripheralConnectionRecordClearUsecase } from './peripheral/connection-record/peripheral_connection_record_clear_usecase'
import { PeripheralPolicyViewModel } from './PeripheralPolicyViewModel'
import { PeripheralRecordViewModel } from './PeripheralRecordViewModel'

const TAG = 'PeripheralViewModel'

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
  private devicePolicyListenerId: number = -1
  private appContext: common.UIAbilityContext | null = null
  private connectionRecordClearUsecase: PeripheralConnectionRecordClearUsecase =
    new PeripheralConnectionRecordClearUsecase()

  setConnectionRecordClearUsecaseForTest(usecase: PeripheralConnectionRecordClearUsecase): void {
    this.connectionRecordClearUsecase = usecase
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.isLoading = true
    this.appContext = context
    try {
      await this.policy.initialize(context)
      await this.reloadAllData()
      this.traceStorageListenerId = PeripheralTraceRepository.addChangeListener(() => {
        this.refreshTraceDrivenData()
      })
      this.devicePolicyListenerId = PeripheralDevicePolicyRepository.addChangeListener(() => {
        this.refreshPolicyDrivenData()
      })
      this.reasonCode = null
    } catch (err) {
      this.reasonCode = PeripheralStrings.initFailed
      LogUtils.error(TAG, `initialize failed: ${JSON.stringify(err)}`)
    } finally {
      this.isLoading = false
    }
  }

  destroy(): void {
    if (this.traceStorageListenerId > 0) {
      PeripheralTraceRepository.removeChangeListener(this.traceStorageListenerId)
      this.traceStorageListenerId = -1
    }
    if (this.devicePolicyListenerId > 0) {
      PeripheralDevicePolicyRepository.removeChangeListener(this.devicePolicyListenerId)
      this.devicePolicyListenerId = -1
    }
  }

  async reloadAllData(): Promise<void> {
    this.refreshAdminActivationState()
    this.interfaceControl.reloadState()
    this.records.reloadRecords()
    this.policy.reloadRecords(this.records.records)
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
      this.reasonCode = PeripheralStrings.adminRequired
    return false
  }

  reloadDeviceRecords(): void {
    this.records.reloadRecords()
    this.policy.reloadRecords(this.records.records)
    this.notifyRefresh('reloadDeviceRecords')
  }

  private refreshTraceDrivenData(): void {
    this.records.reloadRecords()
    this.policy.reloadRecords(this.records.records)
    this.notifyRefresh('refreshTraceDrivenData')
  }

  private refreshPolicyDrivenData(): void {
    this.policy.reloadRecords(this.records.records)
    this.notifyRefresh('refreshPolicyDrivenData')
  }

  private notifyRefresh(source: string): void {
    try {
      this.onRefresh && this.onRefresh()
    } catch (err) {
      LogUtils.warn(TAG, `onRefresh callback failed: ${JSON.stringify(err)}`)
    }
    LogUtils.info(TAG, `source=${source}, records=${this.records.records.length}, policyRecords=${this.policy.records.length}`)
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
    this.notifyRefresh('setUsbStoragePolicy')
    return true
  }

  async handlePeripheralPolicyChange(
    deviceId: string,
    deviceType: PeripheralType,
    deviceName: string,
    policyIndex: number
  ): Promise<boolean> {
    if (!this.ensureAdminReady()) {
      return false
    }
    this.policy.startUpdate(deviceId)
    this.notifyRefresh('policyChangeStart')
    try {
      this.reasonCode = await this.policy.setDevicePolicy(deviceId, deviceName, deviceType, policyIndex)
      if (this.reasonCode !== null) {
        return false
      }
      this.policy.reloadRecords(this.records.records)
      this.notifyRefresh('policyChangeSuccess')
      return true
    } finally {
      this.policy.endUpdate(deviceId)
      this.notifyRefresh('policyChangeFinish')
    }
  }

  async exportConnectionHistory(): Promise<ExportActionResult> {
    const result = await this.records.exportConnectionHistory(this.appContext)
    this.reasonCode = result.success ? null : (result.reason ?? PeripheralStrings.exportConnectionHistoryFailed)
    return result
  }

  async exportPeripheralPolicyRecords(): Promise<ExportActionResult> {
    const result = await this.policy.exportRecords(this.appContext)
    this.reasonCode = result.success ? null : (result.reason ?? PeripheralStrings.exportPolicyRecordsFailed)
    return result
  }

  async clearPeripheralPolicyRecords(): Promise<boolean> {
    try {
      const success = await this.policy.clearAllPolicies()
      if (!success) {
        return false
      }
      this.policy.resetUpdatingState()
      this.policy.reloadRecords(this.records.records)
      this.notifyRefresh('clearPeripheralPolicyRecords')
      return true
    } catch (err) {
      LogUtils.error(TAG, `clearPeripheralPolicyRecords failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  async clearConnectionHistory(): Promise<boolean> {
    const cleared = await this.connectionRecordClearUsecase.execute(this.appContext)
    if (!cleared) {
      return false
    }
    this.records.closeConnectionDetailDialog()
    this.reloadDeviceRecords()
    return true
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

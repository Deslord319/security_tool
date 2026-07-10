import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import {
  PeripheralReasonCodes,
  PeripheralTabIndexes
} from '../../../constants/modules/PeripheralStrings'
import {
  AdminActivationState,
  ExportActionResult
} from '../../../models/CommonModels'
import {
  PeripheralConnectionRecord,
  PeripheralInterfaceFeature,
  PeripheralType
} from '../../../models/PeripheralModels'
import { EnterpriseAdminService } from '../../../services/admin/activation/EnterpriseAdminService'
import { PeripheralDevicePolicyRepository } from '../../../services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { UsbDevicePolicyStateRepository } from '../../../services/peripheral/device-policy/UsbDevicePolicyStateRepository'
import { PeripheralTraceEntryRepository } from '../../../services/peripheral/connection-record/PeripheralTraceEntryRepository'
import { PeripheralTraceMaintenanceService } from '../../../services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { InterfaceControlViewModel } from '../interface-control/InterfaceControlViewModel'
import { PeripheralConnectionRecordClearUsecase } from '../connection-record/PeripheralConnectionRecordClearUsecase'
import { PeripheralPolicyViewModel } from '../device-policy/PeripheralPolicyViewModel'
import { PeripheralRecordViewModel } from '../connection-record/PeripheralRecordViewModel'

const TAG = 'PeripheralViewModel'

@ObservedV2
export class PeripheralViewModel {
  @Trace adminState: AdminActivationState = {
    activated: false,
    enableCommand: EnterpriseAdminService.buildEnableCommand(),
    adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE
  }

  @Trace reasonCode: string | null = null
  @Trace currentTab: number = PeripheralTabIndexes.INTERFACE_CONTROL
  @Trace interfaceControl: InterfaceControlViewModel = new InterfaceControlViewModel()
  @Trace records: PeripheralRecordViewModel = new PeripheralRecordViewModel()
  @Trace policy: PeripheralPolicyViewModel = new PeripheralPolicyViewModel()

  private traceStorageListenerId: number = -1
  private devicePolicyListenerId: number = -1
  private usbPolicyStateListenerId: number = -1
  private appContext: common.UIAbilityContext | null = null
  private connectionRecordClearUsecase: PeripheralConnectionRecordClearUsecase =
    new PeripheralConnectionRecordClearUsecase()

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.appContext = context
    try {
      this.destroy()
      let traceReady = await PeripheralTraceMaintenanceService.initialize(context)
      if (!traceReady.success) {
        this.reasonCode = PeripheralReasonCodes.INIT_FAILED
        LogUtils.error(TAG, `initialize failed: trace storage not ready, code=${traceReady.code}`)
        return
      }
      await this.policy.initialize(context)
      await this.reloadAllData()
      this.traceStorageListenerId = PeripheralTraceEntryRepository.addChangeListener(() => {
        this.refreshTraceDrivenData()
      })
      this.devicePolicyListenerId = PeripheralDevicePolicyRepository.addChangeListener(() => {
        this.refreshPolicyDrivenData()
      })
      this.usbPolicyStateListenerId = UsbDevicePolicyStateRepository.addChangeListener(() => {
        this.refreshPolicyDrivenData()
      })
      this.reasonCode = null
    } catch (err) {
      this.reasonCode = PeripheralReasonCodes.INIT_FAILED
      LogUtils.error(TAG, `initialize failed: ${JSON.stringify(err)}`)
    }
  }

  destroy(): void {
    if (this.traceStorageListenerId > 0) {
      PeripheralTraceEntryRepository.removeChangeListener(this.traceStorageListenerId)
      this.traceStorageListenerId = -1
    }
    if (this.devicePolicyListenerId > 0) {
      PeripheralDevicePolicyRepository.removeChangeListener(this.devicePolicyListenerId)
      this.devicePolicyListenerId = -1
    }
    if (this.usbPolicyStateListenerId > 0) {
      UsbDevicePolicyStateRepository.removeChangeListener(this.usbPolicyStateListenerId)
      this.usbPolicyStateListenerId = -1
    }
  }

  async reloadAllData(): Promise<void> {
    this.refreshAdminActivationState()
    this.interfaceControl.reloadState()
    await this.records.reloadRecords()
    await this.policy.reloadRecords()
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
    this.reasonCode = PeripheralReasonCodes.ADMIN_REQUIRED
    return false
  }

  async reloadDeviceRecords(): Promise<void> {
    await this.records.reloadRecords()
    this.notifyRefresh('reloadDeviceRecords')
  }

  private async refreshTraceDrivenData(): Promise<void> {
    await this.records.reloadRecords()
    this.notifyRefresh('refreshTraceDrivenData')
  }

  private async refreshPolicyDrivenData(): Promise<void> {
    await this.policy.reloadRecords()
    this.notifyRefresh('refreshPolicyDrivenData')
  }

  private notifyRefresh(source: string): void {
    LogUtils.info(TAG, `source=${source}, records=${this.records.state.records.length}, policyRecords=${this.policy.state.records.length}`)
  }

  async toggleInterface(feature: PeripheralInterfaceFeature, disallow: boolean): Promise<boolean> {
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
    policyIndex: number
  ): Promise<boolean> {
    if (!this.ensureAdminReady()) {
      return false
    }
    this.policy.startUpdate(deviceId)
    this.notifyRefresh('policyChangeStart')
    try {
      this.reasonCode = await this.policy.setDevicePolicy(deviceId, deviceType, policyIndex)
      if (this.reasonCode !== null) {
        return false
      }
      await this.records.reloadRecords()
      await this.policy.reloadRecords()
      this.notifyRefresh('policyChangeSuccess')
      return true
    } finally {
      this.policy.endUpdate(deviceId)
      this.notifyRefresh('policyChangeFinish')
    }
  }

  async exportConnectionHistory(): Promise<ExportActionResult> {
    const result = await this.records.exportConnectionHistory(this.appContext)
    this.reasonCode = result.success ? null : (result.reason ?? PeripheralReasonCodes.EXPORT_CONNECTION_HISTORY_FAILED)
    return result
  }

  async exportPeripheralPolicyRecords(): Promise<ExportActionResult> {
    const result = await this.policy.exportRecords(this.appContext)
    this.reasonCode = result.success ? null : (result.reason ?? PeripheralReasonCodes.EXPORT_POLICY_RECORDS_FAILED)
    return result
  }

  hasRestorablePolicyRecords(): boolean {
    return this.policy.state.hasRestorableRecords
  }

  async clearPeripheralPolicyRecords(): Promise<boolean> {
    if (!this.hasRestorablePolicyRecords()) {
      return true
    }
    try {
      const success = await this.policy.clearAllPolicies()
      if (!success) {
        return false
      }
      this.policy.resetUpdatingState()
      await this.policy.reloadRecords()
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
    await this.reloadDeviceRecords()
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
    if (!PeripheralTabIndexes.isValid(index) || index === this.currentTab) {
      return
    }
    this.currentTab = index
  }
}

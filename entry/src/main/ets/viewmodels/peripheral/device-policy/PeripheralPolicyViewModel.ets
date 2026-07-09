import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'

import { DeviceTypeLabels,
  PeripheralExportStrings,
  PeripheralMatchedPolicyStrings,
  PeripheralOptionStrings,
  PeripheralPolicyOptionIndexes,
  PeripheralReasonCodes
} from '../../../constants/modules/PeripheralStrings'
import { ExportActionResult } from '../../../models/CommonModels'
import {
  PeripheralPolicyRecord,
  PeripheralType,
  formatUsbDeviceId,
  isUsbPeripheralType
} from '../../../models/PeripheralModels'
import { getPeripheralTypeLabel } from '../connection-record/PeripheralRecordPresentationMapper'
import { PeripheralDevicePolicyRepository } from '../../../services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import { UsbDevicePolicyStateRepository } from '../../../services/peripheral/device-policy/UsbDevicePolicyStateRepository'
import { UsbDevicePolicyStateService } from '../../../services/peripheral/device-policy/UsbDevicePolicyStateService'
import {
  PeripheralPolicyDispatchReason,
  PeripheralPolicyDispatchResult
} from '../../../services/peripheral/device-policy/PeripheralDevicePolicyDispatchService'
import { PeripheralPolicyService } from '../../../services/peripheral/device-policy/PeripheralPolicyService'
import { CsvFileExportService } from '../../../services/common/export/CsvFileExportService'
import { PeripheralPolicySnapshotTraceService } from '../../../services/peripheral/connection-record/PeripheralPolicySnapshotTraceService'

const TAG = 'PeripheralPolicyViewModel'

@ObservedV2
export class PeripheralPolicyState {
  @Trace records: PeripheralPolicyRecord[] = []
  @Trace updatingKeys: string[] = []
  @Trace hasRestorableRecords: boolean = false
}

@ObservedV2
export class PeripheralPolicyViewModel {
  @Trace state: PeripheralPolicyState = new PeripheralPolicyState()

  async initialize(context: common.UIAbilityContext): Promise<boolean> {
    const devicePolicyReady = await PeripheralDevicePolicyRepository.init(context)
    const usbStateReady = await UsbDevicePolicyStateRepository.init(context)
    return devicePolicyReady && usbStateReady
  }

  async reloadRecords(): Promise<void> {
    const usbPolicyStates = await UsbDevicePolicyStateRepository.listAll()
    const records = PeripheralPolicyService.buildPolicyRecords(usbPolicyStates)
    this.state.hasRestorableRecords = this.hasRestorableRecords(records)
    this.state.records = records
  }

  isUpdating(deviceId: string): boolean {
    return this.state.updatingKeys.includes(deviceId) || this.state.updatingKeys.includes(deviceId.toUpperCase())
  }

  startUpdate(deviceId: string): void {
    const deviceKey = this.normalizeDeviceKey(deviceId)
    if (!this.state.updatingKeys.includes(deviceKey)) {
      this.state.updatingKeys = [...this.state.updatingKeys, deviceKey]
    }
  }

  endUpdate(deviceId: string): void {
    const deviceKey = this.normalizeDeviceKey(deviceId)
    this.state.updatingKeys = this.state.updatingKeys.filter((item: string) => item !== deviceKey)
  }

  resetUpdatingState(): void {
    this.state.updatingKeys = []
  }

  async setDevicePolicy(
    deviceId: string,
    deviceType: PeripheralType,
    policyIndex: number
  ): Promise<string | null> {
    if (!isUsbPeripheralType(deviceType)) {
      return PeripheralReasonCodes.UNSUPPORTED_DEVICE_TYPE_DISPATCH
    }

    const normalizedDeviceId = PeripheralPolicyService.normalizeDeviceIdForPolicy(deviceId)
    if (normalizedDeviceId.length === 0) {
      return PeripheralReasonCodes.INVALID_DEVICE_ID
    }
    if (!normalizedDeviceId.startsWith('USB-SN:') && !normalizedDeviceId.startsWith('USB-WEAK:')) {
      return PeripheralReasonCodes.INVALID_DEVICE_ID
    }

    try {
      const policy = policyIndex === PeripheralPolicyOptionIndexes.DENY ? 'deny' : 'allow'
      const stateDispatchResult = await UsbDevicePolicyStateService.setPolicy(normalizedDeviceId, policy)
      if (!stateDispatchResult.success) {
        return this.resolveDispatchFailure(stateDispatchResult)
      }
      const stateRecord = await UsbDevicePolicyStateRepository.get(normalizedDeviceId)
      if (stateRecord) {
        await PeripheralPolicySnapshotTraceService.appendDevicePolicySnapshot({
          deviceId: formatUsbDeviceId(stateRecord.vendorId, stateRecord.productId),
          deviceName: stateRecord.deviceName,
          deviceType: UsbDevicePolicyStateService.resolveDeviceType(stateRecord.baseClass),
          policy: policy,
          updatedAt: Date.now()
        })
      }
      return null
    } catch (err) {
      LogUtils.error(TAG, `setDevicePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralReasonCodes.POLICY_CHANGE_FAILED
    }
  }

  async clearAllPolicies(): Promise<boolean> {
    const stateRecords = await UsbDevicePolicyStateRepository.listAll()
    if (stateRecords.length === 0) {
      return true
    }

    LogUtils.info(TAG, `clearAllPolicies start: usbStates=${stateRecords.length}`)
    return await UsbDevicePolicyStateService.clearAllPolicies()
  }

  async exportRecords(context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    if (this.state.records.length === 0) {
      return { success: false, reason: PeripheralReasonCodes.EMPTY_POLICY_RECORDS } as ExportActionResult
    }
    if (!context) {
      return { success: false, reason: PeripheralReasonCodes.EXPORT_ENV_NOT_READY } as ExportActionResult
    }

    try {
      const csvContent = this.buildPolicyCsv(this.state.records)
      const result = await CsvFileExportService.saveText(context, csvContent, PeripheralExportStrings.POLICY_LIST_FILE_PREFIX, 'csv')
      return result.success
        ? { success: true, fileName: result.fileName } as ExportActionResult
        : { success: false, reason: PeripheralReasonCodes.EXPORT_POLICY_RECORDS_FAILED } as ExportActionResult
    } catch (err) {
      LogUtils.error(TAG, `exportRecords failed: ${JSON.stringify(err)}`)
      return { success: false, reason: PeripheralReasonCodes.EXPORT_POLICY_RECORDS_FAILED } as ExportActionResult
    }
  }

  private normalizeDeviceKey(deviceId: string): string {
    return PeripheralPolicyService.normalizeDeviceIdForPolicy(deviceId)
  }

  private hasRestorableRecords(records: PeripheralPolicyRecord[]): boolean {
    return records.some((record: PeripheralPolicyRecord) => {
      return record.policyIndex === PeripheralPolicyOptionIndexes.DENY
    })
  }

  private resolveDispatchFailure(result: PeripheralPolicyDispatchResult | null | undefined): string {
    return this.mapDispatchReason(result?.reason)
  }

  private mapDispatchReason(reason?: PeripheralPolicyDispatchReason): string {
    switch (reason) {
      case PeripheralReasonCodes.UNSUPPORTED_POLICY_DISPATCH:
        return PeripheralReasonCodes.UNSUPPORTED_POLICY_DISPATCH
      case PeripheralReasonCodes.UNSUPPORTED_DEVICE_TYPE_DISPATCH:
        return PeripheralReasonCodes.UNSUPPORTED_DEVICE_TYPE_DISPATCH
      case 'dispatch_not_implemented':
        return PeripheralReasonCodes.DEVICE_POLICY_DISPATCH_NOT_IMPLEMENTED
      case PeripheralReasonCodes.USB_CONFLICT_ACCOUNT_STORAGE:
        return PeripheralReasonCodes.USB_CONFLICT_ACCOUNT_STORAGE
      case PeripheralReasonCodes.USB_DISPATCH_FAILED:
        return PeripheralReasonCodes.USB_DISPATCH_FAILED
      case PeripheralReasonCodes.USB_DISPATCH_CONFLICT_UNRESOLVED:
        return PeripheralReasonCodes.USB_DISPATCH_CONFLICT_UNRESOLVED
      case 'device_offline':
        return PeripheralReasonCodes.DEVICE_POLICY_OFFLINE
      default:
        return PeripheralReasonCodes.POLICY_CHANGE_FAILED
    }
  }

  private buildPolicyCsv(records: PeripheralPolicyRecord[]): string {
    const headers: string[] = PeripheralExportStrings.POLICY_LIST_CSV_HEADERS
    const rows: string[][] = records.map((record: PeripheralPolicyRecord) => {
      return [
        record.deviceName,
        this.getDeviceTypeLabel(record.deviceType),
        record.deviceId,
        record.lastSeenLabel,
        this.getPolicyLabel(record.policyIndex)
      ]
    })
    return CsvFileExportService.buildCsvContent(headers, rows)
  }

  private getPolicyLabel(policyIndex: number): string {
    return PeripheralOptionStrings.POLICY_OPTIONS[policyIndex] ??
      PeripheralOptionStrings.POLICY_OPTIONS[PeripheralPolicyOptionIndexes.DEFAULT]
  }

  private getDeviceTypeLabel(deviceType: PeripheralType): string {
    return deviceType === PeripheralType.USB_OTHER ? DeviceTypeLabels.USB_OTHER :
      (deviceType ? getPeripheralTypeLabel(deviceType) : PeripheralMatchedPolicyStrings.UNKNOWN_DEVICE)
  }
}

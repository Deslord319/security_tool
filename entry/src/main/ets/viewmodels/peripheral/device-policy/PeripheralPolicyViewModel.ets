import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'

import { DeviceTypeLabels,
  PeripheralExportStrings,
  PeripheralMatchedPolicyStrings,
  PeripheralOptionStrings,
  PeripheralPolicyOptionIndexes,
  PeripheralReasonCodes
} from '../../../constants/modules/PeripheralStrings'
import {
  ExportActionResult,
  PeripheralConnectionRecord,
  PeripheralDevicePolicyRecord,
  PeripheralPolicyRecord,
  PeripheralType,
  isUsbPeripheralType
} from '../../../models/DataModels'
import { getPeripheralTypeLabel } from '../connection-record/PeripheralRecordPresentationMapper'
import { PeripheralDevicePolicyRepository } from '../../../services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import {
  PeripheralDevicePolicyDispatchService,
  PeripheralPolicyDispatchReason,
  PeripheralPolicyDispatchResult
} from '../../../services/peripheral/device-policy/peripheral_device_policy_dispatch_service'
import { PeripheralPolicyService } from '../../../services/peripheral/device-policy/PeripheralPolicyService'
import { CsvFileExportService } from '../../../services/common/export/CsvFileExportService'

const TAG = 'PeripheralPolicyViewModel'

@ObservedV2
export class PeripheralPolicyState {
  @Trace records: PeripheralPolicyRecord[] = []
  @Trace updatingKeys: string[] = []
}

@ObservedV2
export class PeripheralPolicyViewModel {
  @Trace state: PeripheralPolicyState = new PeripheralPolicyState()

  async initialize(context: common.UIAbilityContext): Promise<boolean> {
    return PeripheralDevicePolicyRepository.init(context)
  }

  reloadRecords(connectionRecords: PeripheralConnectionRecord[]): void {
    this.state.records = PeripheralPolicyService.buildPolicyRecords(
      connectionRecords,
      PeripheralDevicePolicyRepository.getAll()
    )
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
    deviceName: string,
    deviceType: PeripheralType,
    policyIndex: number
  ): Promise<string | null> {
    const normalizedDeviceId = PeripheralPolicyService.normalizeDeviceIdForPolicy(deviceId, deviceType)
    if (normalizedDeviceId.length === 0) {
      return PeripheralReasonCodes.INVALID_DEVICE_ID
    }

    try {
      const policy = policyIndex === PeripheralPolicyOptionIndexes.DENY ? 'deny' : 'allow'
      if (this.shouldDispatchBeforeSave(deviceType)) {
        const dispatchResult = await PeripheralDevicePolicyDispatchService.dispatch({
          deviceId: normalizedDeviceId,
          deviceType: deviceType,
          policy: policy
        })
        if (!dispatchResult.success) {
          return this.resolveDispatchFailure(dispatchResult)
        }
      }

      const record: PeripheralDevicePolicyRecord = {
        deviceId: normalizedDeviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        policy: policy,
        updatedAt: Date.now()
      }
      const success = await PeripheralDevicePolicyRepository.set(record)
      return success ? null : PeripheralReasonCodes.POLICY_CHANGE_FAILED
    } catch (err) {
      LogUtils.error(TAG, `setDevicePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralReasonCodes.POLICY_CHANGE_FAILED
    }
  }

  async clearAllPolicies(): Promise<boolean> {
    const records = PeripheralDevicePolicyRepository.getAll()
    if (records.length === 0) {
      return true
    }

    LogUtils.info(TAG, `clearAllPolicies start: total=${records.length}`)
    const revertedRecords: PeripheralDevicePolicyRecord[] = []
    for (const record of records) {
      const clearResult = await this.dispatchPolicyRecord(record, 'allow')
      if (!clearResult.success) {
        LogUtils.error(
          TAG,
          `clearAllPolicies dispatch failed: deviceId=${record.deviceId}, deviceType=${record.deviceType}, reason=${clearResult.reason ?? 'unknown'}`
        )
        const rollbackSuccess = await this.rollbackClearedPolicies(revertedRecords)
        LogUtils.warn(TAG, `clearAllPolicies rollback result: success=${rollbackSuccess}, reverted=${revertedRecords.length}`)
        return false
      }
      revertedRecords.push(record)
    }

    const cleared = await PeripheralDevicePolicyRepository.clearAll()
    if (cleared) {
      LogUtils.info(TAG, `clearAllPolicies completed: total=${records.length}`)
    } else {
      LogUtils.error(TAG, `clearAllPolicies repository clear failed: total=${records.length}`)
    }
    return cleared
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

  private async dispatchPolicyRecord(
    record: PeripheralDevicePolicyRecord,
    policy: 'allow' | 'deny'
  ): Promise<PeripheralPolicyDispatchResult> {
    if (!record.deviceType || !this.shouldDispatchBeforeSave(record.deviceType)) {
      return { success: true } as PeripheralPolicyDispatchResult
    }
    return PeripheralDevicePolicyDispatchService.dispatch({
      deviceId: record.deviceId,
      deviceType: record.deviceType,
      policy: policy
    })
  }

  private async rollbackClearedPolicies(records: PeripheralDevicePolicyRecord[]): Promise<boolean> {
    if (records.length === 0) {
      return true
    }

    LogUtils.warn(TAG, `rollbackClearedPolicies start: total=${records.length}`)
    for (let index = records.length - 1; index >= 0; index--) {
      const record = records[index]
      const rollbackResult = await this.dispatchPolicyRecord(record, record.policy)
      if (!rollbackResult.success) {
        LogUtils.error(
          TAG,
          `rollbackClearedPolicies failed: deviceId=${record.deviceId}, deviceType=${record.deviceType}, reason=${rollbackResult.reason ?? 'unknown'}`
        )
        return false
      }
    }
    return true
  }

  private shouldDispatchBeforeSave(deviceType: PeripheralType): boolean {
    return isUsbPeripheralType(deviceType) || deviceType === PeripheralType.BLUETOOTH
  }

  private resolveDispatchFailure(result: PeripheralPolicyDispatchResult | null | undefined): string {
    return this.mapDispatchReason(result?.reason)
  }

  private mapDispatchReason(reason?: PeripheralPolicyDispatchReason): string {
    switch (reason) {
      case 'unsupported_policy':
        return PeripheralReasonCodes.UNSUPPORTED_POLICY_DISPATCH
      case 'unsupported_device_type':
        return PeripheralReasonCodes.UNSUPPORTED_DEVICE_TYPE_DISPATCH
      case 'dispatch_not_implemented':
        return PeripheralReasonCodes.DEVICE_POLICY_DISPATCH_NOT_IMPLEMENTED
      case 'usb_conflict_global_disabled':
        return PeripheralReasonCodes.USB_CONFLICT_GLOBAL_DISABLED
      case 'usb_conflict_account_storage':
        return PeripheralReasonCodes.USB_CONFLICT_ACCOUNT_STORAGE
      case 'usb_dispatch_failed':
        return PeripheralReasonCodes.USB_DISPATCH_FAILED
      case 'usb_dispatch_conflict_unresolved':
        return PeripheralReasonCodes.USB_DISPATCH_CONFLICT_UNRESOLVED
      case 'bluetooth_conflict_global_disabled':
        return PeripheralReasonCodes.BLUETOOTH_CONFLICT_GLOBAL_DISABLED
      case 'bluetooth_dispatch_failed':
        return PeripheralReasonCodes.BLUETOOTH_DISPATCH_FAILED
      case 'bluetooth_dispatch_conflict_unresolved':
        return PeripheralReasonCodes.BLUETOOTH_DISPATCH_CONFLICT_UNRESOLVED
      default:
        return PeripheralReasonCodes.POLICY_CHANGE_FAILED
    }
  }

  private buildPolicyCsv(records: PeripheralPolicyRecord[]): string {
    const headers: string[] = PeripheralExportStrings.POLICY_LIST_CSV_HEADERS
    const rows = records.map((record: PeripheralPolicyRecord) => {
      return [
        record.deviceName,
        this.getDeviceTypeLabel(record.deviceType),
        record.deviceId,
        record.lastSeenLabel,
        this.getPolicyLabel(record.policyIndex)
      ].map((value: string) => CsvFileExportService.escapeCsvValue(value)).join(',')
    })
    return `\uFEFF${headers.map((value: string) => CsvFileExportService.escapeCsvValue(value)).join(',')}\n${rows.join('\n')}`
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

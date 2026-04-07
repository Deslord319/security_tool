import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'

import { DeviceTypeLabels } from '../../../constants/modules/DialogStrings'
import { PeripheralStrings } from '../../../constants/modules/PeripheralStrings'
import {
  ExportActionResult,
  PeripheralConnectionRecord,
  PeripheralDevicePolicyRecord,
  PeripheralPolicyRecord,
  getPeripheralTypeLabel,
  PeripheralType
} from '../../../models/DataModels'
import { PeripheralDevicePolicyRepository } from '../../../services/peripheral/device-policy/PeripheralDevicePolicyRepository'
import {
  PeripheralDevicePolicyDispatchService,
  PeripheralPolicyDispatchReason,
  PeripheralPolicyDispatchResult
} from '../../../services/peripheral/device-policy/peripheral_device_policy_dispatch_service'
import { PeripheralPolicyService } from '../../../services/peripheral/device-policy/PeripheralPolicyService'
import { LogExportService } from '../../../services/log-manage/export/LogExportService'

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
      return PeripheralStrings.invalidDeviceId
    }

    try {
      const policy = policyIndex === 1 ? 'deny' : 'allow'
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
      return success ? null : PeripheralStrings.policyChangeFailed
    } catch (err) {
      LogUtils.error(TAG, `setDevicePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralStrings.policyChangeFailed
    }
  }

  async clearAllPolicies(): Promise<boolean> {
    return PeripheralDevicePolicyRepository.clearAll()
  }

  async exportRecords(context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    if (this.state.records.length === 0) {
      return { success: false, reason: PeripheralStrings.emptyPolicyRecords } as ExportActionResult
    }
    if (!context) {
      return { success: false, reason: PeripheralStrings.exportEnvNotReady } as ExportActionResult
    }

    try {
      const csvContent = this.buildPolicyCsv(this.state.records)
      const result = await LogExportService.saveCsvContent(context, csvContent, PeripheralStrings.csvPolicyListFilePrefix)
      return result.success
        ? { success: true, fileName: result.fileName } as ExportActionResult
        : { success: false, reason: PeripheralStrings.exportPolicyRecordsFailed } as ExportActionResult
    } catch (err) {
      LogUtils.error(TAG, `exportRecords failed: ${JSON.stringify(err)}`)
      return { success: false, reason: PeripheralStrings.exportPolicyRecordsFailed } as ExportActionResult
    }
  }

  private normalizeDeviceKey(deviceId: string): string {
    return PeripheralPolicyService.normalizeDeviceIdForPolicy(deviceId)
  }

  private shouldDispatchBeforeSave(deviceType: PeripheralType): boolean {
    switch (deviceType) {
      case PeripheralType.USB_STORAGE:
      case PeripheralType.USB_CAMERA:
      case PeripheralType.USB_PRINTER:
      case PeripheralType.USB_HID:
      case PeripheralType.USB_OTHER:
      case PeripheralType.BLUETOOTH:
        return true
      default:
        return false
    }
  }

  private resolveDispatchFailure(result: PeripheralPolicyDispatchResult | null | undefined): string {
    return this.mapDispatchReason(result?.reason)
  }

  private mapDispatchReason(reason?: PeripheralPolicyDispatchReason): string {
    switch (reason) {
      case 'unsupported_policy':
        return PeripheralStrings.unsupportedPolicyDispatch
      case 'unsupported_device_type':
        return PeripheralStrings.unsupportedDeviceTypeDispatch
      case 'dispatch_not_implemented':
        return PeripheralStrings.devicePolicyDispatchNotImplemented
      case 'usb_conflict_global_disabled':
        return PeripheralStrings.usbConflictGlobalDisabled
      case 'usb_conflict_account_storage':
        return PeripheralStrings.usbConflictAccountStorage
      case 'usb_dispatch_failed':
        return PeripheralStrings.usbDispatchFailed
      case 'usb_dispatch_conflict_unresolved':
        return PeripheralStrings.usbDispatchConflictUnresolved
      case 'bluetooth_conflict_global_disabled':
        return PeripheralStrings.bluetoothConflictGlobalDisabled
      case 'bluetooth_dispatch_failed':
        return PeripheralStrings.bluetoothDispatchFailed
      case 'bluetooth_dispatch_conflict_unresolved':
        return PeripheralStrings.bluetoothDispatchConflictUnresolved
      default:
        return PeripheralStrings.policyChangeFailed
    }
  }

  private buildPolicyCsv(records: PeripheralPolicyRecord[]): string {
    const headers: string[] = PeripheralStrings.policyListCsvHeaders
    const rows = records.map((record: PeripheralPolicyRecord) => {
      return [
        record.deviceName,
        this.getDeviceTypeLabel(record.deviceType),
        record.deviceId,
        record.lastSeenLabel,
        this.getPolicyLabel(record.policyIndex)
      ].map((value: string) => this.escapeCsvValue(value)).join(',')
    })
    return `\uFEFF${headers.map((value: string) => this.escapeCsvValue(value)).join(',')}\n${rows.join('\n')}`
  }

  private getPolicyLabel(policyIndex: number): string {
    return PeripheralStrings.policyOptions[policyIndex] ?? PeripheralStrings.policyOptions[0]
  }

  private getDeviceTypeLabel(deviceType: PeripheralType): string {
    return deviceType === PeripheralType.USB_OTHER ? DeviceTypeLabels.USB_OTHER :
      (deviceType ? getPeripheralTypeLabel(deviceType) : PeripheralStrings.unknownDevice)
  }

  private escapeCsvValue(value: string): string {
    const normalized = value.replace(/"/g, '""')
    if (/[",\r\n]/.test(normalized)) {
      return `"${normalized}"`
    }
    return normalized
  }
}

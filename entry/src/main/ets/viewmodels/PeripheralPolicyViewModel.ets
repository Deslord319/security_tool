import { LogUtils } from '../utils/LogUtils'
import { common } from '@kit.AbilityKit'

import { PeripheralStrings } from '../constants/modules/PeripheralStrings'
import {
  ExportActionResult,
  PeripheralConnectionRecord,
  PeripheralDevicePolicyRecord,
  PeripheralPolicyRecord,
  getPeripheralTypeLabel,
  PeripheralType
} from '../models/DataModels'
import { LogStorageService } from '../services/LogStorageService'
import { PeripheralDevicePolicyRepository } from '../services/PeripheralDevicePolicyRepository'
import { PeripheralPolicyService } from '../services/PeripheralPolicyService'

const TAG = 'PeripheralPolicyViewModel'

@Observed
export class PeripheralPolicyViewModel {
  records: PeripheralPolicyRecord[] = []
  updatingKeys: string[] = []

  async initialize(context: common.UIAbilityContext): Promise<boolean> {
    return PeripheralDevicePolicyRepository.init(context)
  }

  reloadRecords(connectionRecords: PeripheralConnectionRecord[]): void {
    this.records = PeripheralPolicyService.buildPolicyRecords(
      connectionRecords,
      PeripheralDevicePolicyRepository.getAll()
    )
  }

  isUpdating(deviceId: string): boolean {
    return this.updatingKeys.includes(deviceId) || this.updatingKeys.includes(deviceId.toUpperCase())
  }

  startUpdate(deviceId: string): void {
    const deviceKey = this.normalizeDeviceKey(deviceId)
    if (!this.updatingKeys.includes(deviceKey)) {
      this.updatingKeys = [...this.updatingKeys, deviceKey]
    }
  }

  endUpdate(deviceId: string): void {
    const deviceKey = this.normalizeDeviceKey(deviceId)
    this.updatingKeys = this.updatingKeys.filter((item: string) => item !== deviceKey)
  }

  resetUpdatingState(): void {
    this.updatingKeys = []
  }

  async setDevicePolicy(
    deviceId: string,
    deviceName: string,
    deviceType: PeripheralType,
    policyIndex: number
  ): Promise<string | null> {
    const normalizedDeviceId = this.normalizeDeviceKey(deviceId)
    if (normalizedDeviceId.length === 0) {
      return PeripheralStrings.INVALID_DEVICE_ID
    }

    try {
      const record: PeripheralDevicePolicyRecord = {
        deviceId: normalizedDeviceId,
        deviceName: deviceName,
        deviceType: deviceType,
        policy: policyIndex === 1 ? 'deny' : 'allow',
        updatedAt: Date.now()
      }
      const success = await PeripheralDevicePolicyRepository.set(record)
      return success ? null : PeripheralStrings.POLICY_CHANGE_FAILED
    } catch (err) {
      LogUtils.error(TAG, `setDevicePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralStrings.POLICY_CHANGE_FAILED
    }
  }

  async clearAllPolicies(): Promise<boolean> {
    return PeripheralDevicePolicyRepository.clearAll()
  }

  async exportRecords(context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    if (this.records.length === 0) {
      return { success: false, reason: PeripheralStrings.EMPTY_POLICY_RECORDS } as ExportActionResult
    }
    if (!context) {
      return { success: false, reason: PeripheralStrings.EXPORT_ENV_NOT_READY } as ExportActionResult
    }

    try {
      await LogStorageService.init(context)
      const csvContent = this.buildPolicyCsv(this.records)
      const result = await LogStorageService.exportToCsvFile({
        csvContent,
        fileNamePrefix: PeripheralStrings.csvPolicyListFilePrefix
      })
      return result.success
        ? { success: true, fileName: result.fileName } as ExportActionResult
        : { success: false, reason: PeripheralStrings.EXPORT_POLICY_RECORDS_FAILED } as ExportActionResult
    } catch (err) {
      LogUtils.error(TAG, `exportRecords failed: ${JSON.stringify(err)}`)
      return { success: false, reason: PeripheralStrings.EXPORT_POLICY_RECORDS_FAILED } as ExportActionResult
    }
  }

  private normalizeDeviceKey(deviceId: string): string {
    return (deviceId || '').trim().replace(/\s+/g, ' ').toUpperCase()
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
    return deviceType === PeripheralType.USB_OTHER ? PeripheralStrings.usbOtherDevice :
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

import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PeripheralStrings } from '../constants/modules/PeripheralStrings'
import {
  ExportActionResult,
  PeripheralConnectionRecord,
  PeripheralDevicePolicyRecord,
  PeripheralPolicyRecord,
  PeripheralType
} from '../models/DataModels'
import { LogStorageService } from '../services/LogStorageService'
import { PeripheralDevicePolicyRepository } from '../services/PeripheralDevicePolicyRepository'
import { PeripheralPolicyService } from '../services/PeripheralPolicyService'

const TAG = 'PeripheralPolicyViewModel'
const DOMAIN = 0x0013

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
      hilog.error(DOMAIN, TAG, `setDevicePolicy failed: ${JSON.stringify(err)}`)
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
        fileNamePrefix: 'peripheral_policy_list'
      })
      return result.success
        ? { success: true, fileName: result.fileName } as ExportActionResult
        : { success: false, reason: PeripheralStrings.EXPORT_POLICY_RECORDS_FAILED } as ExportActionResult
    } catch (err) {
      hilog.error(DOMAIN, TAG, `exportRecords failed: ${JSON.stringify(err)}`)
      return { success: false, reason: PeripheralStrings.EXPORT_POLICY_RECORDS_FAILED } as ExportActionResult
    }
  }

  private normalizeDeviceKey(deviceId: string): string {
    return (deviceId || '').trim().replace(/\s+/g, ' ').toUpperCase()
  }

  private buildPolicyCsv(records: PeripheralPolicyRecord[]): string {
    const headers: string[] = [
      '设备名称',
      '设备类型',
      '设备标识',
      '最近出现时间',
      '当前策略'
    ]
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
    return policyIndex === 0 ? '允许接入' : '禁止接入'
  }

  private getDeviceTypeLabel(deviceType: PeripheralType): string {
    switch (deviceType) {
      case PeripheralType.USB_STORAGE:
        return 'USB 存储设备'
      case PeripheralType.USB_CAMERA:
        return 'USB 摄像头'
      case PeripheralType.USB_PRINTER:
        return 'USB 打印机'
      case PeripheralType.USB_HID:
        return 'USB 人机输入设备'
      case PeripheralType.USB_OTHER:
        return 'USB 其他设备'
      case PeripheralType.BLUETOOTH:
        return '蓝牙设备'
      default:
        return '未知设备'
    }
  }

  private escapeCsvValue(value: string): string {
    const normalized = value.replace(/"/g, '""')
    if (/[",\r\n]/.test(normalized)) {
      return `"${normalized}"`
    }
    return normalized
  }
}


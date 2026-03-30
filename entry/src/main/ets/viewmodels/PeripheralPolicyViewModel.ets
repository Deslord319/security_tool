import { common } from '@kit.AbilityKit'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  ExportActionResult,
  formatUsbDeviceId,
  getPeripheralTypeLabel,
  parseUsbDeviceId,
  PeripheralConnectionRecord,
  PeripheralPolicyRecord,
  PeripheralType
} from '../models/DataModels'
import { PeripheralReasons } from '../constants/modules/PeripheralReasons'
import { LogStorageService } from '../services/LogStorageService'
import { PeripheralService } from '../services/PeripheralService'
import { buildPeripheralPolicyRecords } from './PeripheralRecordPresentationMapper'

const TAG = 'PeripheralPolicyViewModel'
const DOMAIN = 0x0013

export interface WhitelistBlacklistState {
  usbWhitelist: edmUsbManager.UsbDeviceId[]
  usbBlacklist: edmUsbManager.UsbDeviceType[]
}

@Observed
export class PeripheralPolicyViewModel {
  whitelistBlacklistState: WhitelistBlacklistState = {
    usbWhitelist: [],
    usbBlacklist: []
  }

  records: PeripheralPolicyRecord[] = []
  updatingKeys: string[] = []

  resolveDeviceKey(deviceId: string): string | null {
    const parsed = parseUsbDeviceId(deviceId)
    if (!parsed) {
      return null
    }
    return formatUsbDeviceId(parsed.vendorId, parsed.productId).toUpperCase()
  }

  reloadWhitelistBlacklist(): void {
    try {
      this.whitelistBlacklistState.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.whitelistBlacklistState.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
    } catch (err) {
      hilog.error(DOMAIN, TAG, `reloadWhitelistBlacklist failed: ${JSON.stringify(err)}`)
      this.whitelistBlacklistState = {
        usbWhitelist: [],
        usbBlacklist: []
      }
    }
  }

  rebuildRecords(connectionRecords: PeripheralConnectionRecord[]): void {
    this.records = buildPeripheralPolicyRecords(
      connectionRecords,
      this.whitelistBlacklistState.usbWhitelist,
      this.whitelistBlacklistState.usbBlacklist
    )
  }

  isUpdating(deviceId: string): boolean {
    return this.updatingKeys.includes(deviceId) || this.updatingKeys.includes(deviceId.toUpperCase())
  }

  startUpdate(deviceId: string): void {
    const deviceKey = this.resolveDeviceKey(deviceId) ?? deviceId.toUpperCase()
    if (!this.updatingKeys.includes(deviceKey)) {
      this.updatingKeys = [...this.updatingKeys, deviceKey]
    }
  }

  endUpdate(deviceId: string): void {
    const deviceKey = this.resolveDeviceKey(deviceId) ?? deviceId.toUpperCase()
    this.updatingKeys = this.updatingKeys.filter((item: string) => item !== deviceKey)
  }

  resetUpdatingState(): void {
    this.updatingKeys = []
  }

  async changePolicy(deviceId: string, deviceType: PeripheralType, policyIndex: number): Promise<string | null> {
    const parsed = parseUsbDeviceId(deviceId)
    if (!parsed) {
      return PeripheralReasons.INVALID_DEVICE_ID
    }

    try {
      const result = await PeripheralService.switchUsbDevicePolicyWithResult(
        { vendorId: parsed.vendorId, productId: parsed.productId },
        deviceType,
        policyIndex === 0 ? PeripheralService.USB_DEVICE_POLICY_ALLOW : PeripheralService.USB_DEVICE_POLICY_DENY
      )
      return result.success ? null : this.normalizeReason(result.stage)
    } catch (err) {
      hilog.error(DOMAIN, TAG, `changePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralReasons.POLICY_CHANGE_FAILED
    }
  }

  async exportRecords(context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    if (this.records.length === 0) {
      return { success: false, reason: PeripheralReasons.EMPTY_POLICY_RECORDS } as ExportActionResult
    }
    if (!context) {
      return { success: false, reason: PeripheralReasons.EXPORT_ENV_NOT_READY } as ExportActionResult
    }

    try {
      await LogStorageService.init(context)
      const csvContent = this.buildPolicyCsv(this.records)
      const result = await LogStorageService.exportToCsvFile({
        csvContent,
        fileNamePrefix: 'peripheral_policy_list'
      })
      return result.success ?
        { success: true, fileName: result.fileName } as ExportActionResult :
        { success: false, reason: PeripheralReasons.EXPORT_POLICY_RECORDS_FAILED } as ExportActionResult
    } catch (err) {
      hilog.error(DOMAIN, TAG, `exportRecords failed: ${JSON.stringify(err)}`)
      return { success: false, reason: PeripheralReasons.EXPORT_POLICY_RECORDS_FAILED } as ExportActionResult
    }
  }

  private normalizeReason(stage: string | undefined): string {
    switch (stage) {
      case PeripheralReasons.PRECHECK_BLACKLIST_CONFLICT:
        return PeripheralReasons.PRECHECK_BLACKLIST_CONFLICT
      case PeripheralReasons.PRECHECK_WHITELIST_CONFLICT:
        return PeripheralReasons.PRECHECK_WHITELIST_CONFLICT
      case PeripheralReasons.INFER_BLACKLIST_TYPE_FAILED:
        return PeripheralReasons.INFER_BLACKLIST_TYPE_FAILED
      default:
        return stage || PeripheralReasons.POLICY_CHANGE_FAILED
    }
  }

  private buildPolicyCsv(records: PeripheralPolicyRecord[]): string {
    const headers: string[] = [
      '设备名称',
      '设备类型',
      '设备标识',
      '最近连接时间',
      '当前策略'
    ]
    const rows = records.map((record: PeripheralPolicyRecord) => {
      return [
        record.deviceName,
        getPeripheralTypeLabel(record.deviceType),
        record.deviceId,
        record.lastSeenLabel,
        this.getPolicyLabel(record.policyIndex)
      ].map((value: string) => this.escapeCsvValue(value)).join(',')
    })
    return `\uFEFF${headers.map((value: string) => this.escapeCsvValue(value)).join(',')}\n${rows.join('\n')}`
  }

  private getPolicyLabel(policyIndex: number): string {
    return policyIndex === 0 ? '允许接入' : '禁止访问'
  }

  private escapeCsvValue(value: string): string {
    const normalized = value.replace(/"/g, '""')
    if (/[",\r\n]/.test(normalized)) {
      return `"${normalized}"`
    }
    return normalized
  }
}

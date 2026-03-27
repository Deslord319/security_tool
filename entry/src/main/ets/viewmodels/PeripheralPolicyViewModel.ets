import { common } from '@kit.AbilityKit'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  formatUsbDeviceId,
  getPeripheralTypeLabel,
  parseUsbDeviceId,
  PeripheralConnectionRecord,
  PeripheralPolicyRecord,
  PeripheralType
} from '../models/DataModels'
import { LogStorageService } from '../services/LogStorageService'
import { PeripheralService } from '../services/PeripheralService'
import { buildPeripheralPolicyRecords } from '../utils/PeripheralRecordViewDataUtils'
import {
  REASON_EMPTY_POLICY_RECORDS,
  REASON_EXPORT_ENV_NOT_READY,
  REASON_EXPORT_POLICY_RECORDS_FAILED,
  REASON_INFER_BLACKLIST_TYPE_FAILED,
  REASON_INVALID_DEVICE_ID,
  REASON_POLICY_CHANGE_FAILED,
  REASON_PRECHECK_BLACKLIST_CONFLICT,
  REASON_PRECHECK_WHITELIST_CONFLICT
} from './PeripheralViewModelReasons'

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

  resetUpdatingState(): void {
    this.updatingKeys = []
  }

  async changePolicy(deviceId: string, deviceType: PeripheralType, policyIndex: number): Promise<string | null> {
    const parsed = parseUsbDeviceId(deviceId)
    if (!parsed) {
      return REASON_INVALID_DEVICE_ID
    }

    const deviceKey = formatUsbDeviceId(parsed.vendorId, parsed.productId).toUpperCase()
    this.startUpdate(deviceKey)
    try {
      const result = PeripheralService.switchUsbDevicePolicyWithResult(
        { vendorId: parsed.vendorId, productId: parsed.productId },
        deviceType,
        policyIndex === 0 ? PeripheralService.USB_DEVICE_POLICY_ALLOW : PeripheralService.USB_DEVICE_POLICY_DENY
      )
      return result.success ? null : this.normalizeReason(result.stage)
    } catch (err) {
      hilog.error(DOMAIN, TAG, `changePolicy failed: ${JSON.stringify(err)}`)
      return REASON_POLICY_CHANGE_FAILED
    } finally {
      this.endUpdate(deviceKey)
    }
  }

  async exportRecords(context: common.UIAbilityContext | null): Promise<string | null> {
    if (this.records.length === 0) {
      return REASON_EMPTY_POLICY_RECORDS
    }
    if (!context) {
      return REASON_EXPORT_ENV_NOT_READY
    }

    try {
      await LogStorageService.init(context)
      const csvContent = this.buildPolicyCsv(this.records)
      const result = await LogStorageService.exportToCsvFile({
        csvContent,
        fileNamePrefix: 'peripheral_policy_list'
      })
      return result.success ? null : REASON_EXPORT_POLICY_RECORDS_FAILED
    } catch (err) {
      hilog.error(DOMAIN, TAG, `exportRecords failed: ${JSON.stringify(err)}`)
      return REASON_EXPORT_POLICY_RECORDS_FAILED
    }
  }

  private startUpdate(deviceId: string): void {
    if (!this.updatingKeys.includes(deviceId)) {
      this.updatingKeys = [...this.updatingKeys, deviceId]
    }
  }

  private endUpdate(deviceId: string): void {
    this.updatingKeys = this.updatingKeys.filter((item: string) => item !== deviceId)
  }

  private normalizeReason(stage: string | undefined): string {
    switch (stage) {
      case REASON_PRECHECK_BLACKLIST_CONFLICT:
        return REASON_PRECHECK_BLACKLIST_CONFLICT
      case REASON_PRECHECK_WHITELIST_CONFLICT:
        return REASON_PRECHECK_WHITELIST_CONFLICT
      case REASON_INFER_BLACKLIST_TYPE_FAILED:
        return REASON_INFER_BLACKLIST_TYPE_FAILED
      default:
        return stage || REASON_POLICY_CHANGE_FAILED
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

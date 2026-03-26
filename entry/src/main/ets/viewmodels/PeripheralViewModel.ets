/**
 * Peripheral page ViewModel.
 */
import { common } from '@kit.AbilityKit'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  AdminActivationState,
  formatLogTimestamp,
  formatUsbDeviceId,
  getLogEventResultLabel,
  getPeripheralRecordActionLabel,
  getPeripheralRecordPolicyHitLabel,
  getPeripheralRecordSourceLabel,
  getPeripheralTypeLabel,
  inferUsbBaseClass,
  LogExportFormat,
  parseUsbDeviceId,
  PeripheralConnectionRecord,
  PeripheralPolicyRecord,
  PeripheralType
} from '../models/DataModels'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { LogContentExportOptions, LogStorageService } from '../services/LogStorageService'
import { PeripheralConnectionRecordService } from '../services/PeripheralConnectionRecordService'
import { PeripheralService } from '../services/PeripheralService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'

const TAG = 'PeripheralViewModel'
const DOMAIN = 0x0013

interface InterfaceControlState {
  usbDisabled: boolean
  btDisabled: boolean
  wifiDisabled: boolean
  hdcDisabled: boolean
  networkDisabled: boolean
  printerDisabled: boolean
  microphoneDisabled: boolean
  cameraDisabled: boolean
  usbStoragePolicyIndex: number
}

interface WhitelistBlacklistState {
  usbWhitelist: edmUsbManager.UsbDeviceId[]
  usbBlacklist: edmUsbManager.UsbDeviceType[]
  btWhitelist: string[]
}

interface ConnectionHistoryItem {
  time: string
  policy: string
  result: string
}

interface ConnectionDetailDialogState {
  visible: boolean
  record: PeripheralConnectionRecord | null
  historyItems: ConnectionHistoryItem[]
}

@Observed
class PeripheralViewModel {
  adminState: AdminActivationState = {
    activated: false,
    enableCommand: EnterpriseAdminService.buildEnableCommand(),
    adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE
  }

  interfaceState: InterfaceControlState = {
    usbDisabled: false,
    btDisabled: false,
    wifiDisabled: false,
    hdcDisabled: false,
    networkDisabled: false,
    printerDisabled: false,
    microphoneDisabled: false,
    cameraDisabled: false,
    usbStoragePolicyIndex: 1
  }

  whitelistBlacklistState: WhitelistBlacklistState = {
    usbWhitelist: [],
    usbBlacklist: [],
    btWhitelist: []
  }

  deviceRecords: PeripheralConnectionRecord[] = []
  peripheralPolicyRecords: PeripheralPolicyRecord[] = []
  isLoading: boolean = false
  errorMessage: string | null = null
  interfaceControlProcessingKey: string = ''
  policyUpdatingKeys: string[] = []
  connectionDetailDialog: ConnectionDetailDialogState = {
    visible: false,
    record: null,
    historyItems: []
  }
  currentTab: number = 0

  private traceStorageListenerId: number = -1
  private appContext: common.UIAbilityContext | null = null
  private readonly usbRecordTypes: PeripheralType[] = [
    PeripheralType.USB_STORAGE,
    PeripheralType.USB_CAMERA,
    PeripheralType.USB_PRINTER,
    PeripheralType.USB_HID,
    PeripheralType.USB_OTHER
  ]

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.isLoading = true
    this.appContext = context
    try {
      await this.reloadAllData()
      this.traceStorageListenerId = PeripheralTraceRepository.addChangeListener(() => {
        this.reloadDeviceRecords()
      })
    } catch (err) {
      this.errorMessage = `外设管理初始化失败：${JSON.stringify(err)}`
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
  }

  async reloadAllData(): Promise<void> {
    this.refreshAdminActivationState()
    this.reloadInterfaceState()
    this.reloadWhitelistBlacklist()
    this.reloadDeviceRecords()
  }

  refreshAdminActivationState(): void {
    this.adminState = EnterpriseAdminService.probeActivation()
  }

  ensureAdminReady(action: string): boolean {
    this.refreshAdminActivationState()
    if (this.adminState.activated) {
      return true
    }
    this.errorMessage = `${action}未完成，请先激活企业管理员`
    return false
  }

  reloadDeviceRecords(): void {
    try {
      this.deviceRecords = PeripheralConnectionRecordService.queryRecords()
      this.loadPeripheralPolicyData()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `reloadDeviceRecords failed: ${JSON.stringify(err)}`)
      this.deviceRecords = []
      this.peripheralPolicyRecords = []
    }
  }

  async toggleInterface(feature: string, disallow: boolean): Promise<boolean> {
    if (!this.ensureAdminReady('设置接口策略')) {
      return false
    }

    try {
      const result = PeripheralService.setInterfaceDisabledWithResult(feature, disallow)
      if (!result.success) {
        this.errorMessage = result.userMessage?.trim() || result.errorMessage || '设置接口策略失败'
        return false
      }
      this.reloadInterfaceState()
      this.errorMessage = null
      return true
    } catch (err) {
      this.errorMessage = `设置接口策略失败：${JSON.stringify(err)}`
      return false
    }
  }

  async setUsbStoragePolicy(index: number): Promise<boolean> {
    if (!this.ensureAdminReady('设置 USB 存储策略')) {
      return false
    }

    try {
      const policy = index === 0
        ? edmUsbManager.UsbPolicy.READ_ONLY
        : index === 1
          ? edmUsbManager.UsbPolicy.READ_WRITE
          : edmUsbManager.UsbPolicy.DISABLED
      const result = PeripheralService.setUsbStoragePolicyWithCleanupResult(policy)
      if (!result.success) {
        this.errorMessage = result.userMessage?.trim() || result.errorMessage || '设置 USB 存储策略失败'
        return false
      }
      this.interfaceState.usbStoragePolicyIndex = index
      this.reloadWhitelistBlacklist()
      this.loadPeripheralPolicyData()
      this.errorMessage = null
      return true
    } catch (err) {
      this.errorMessage = `设置 USB 存储策略失败：${JSON.stringify(err)}`
      return false
    }
  }

  async handlePeripheralPolicyChange(deviceId: string, deviceType: PeripheralType, policyIndex: number): Promise<boolean> {
    if (!this.ensureAdminReady('修改设备策略')) {
      return false
    }

    const parsed = parseUsbDeviceId(deviceId)
    if (!parsed) {
      this.errorMessage = '无法识别当前设备标识'
      return false
    }

    const deviceKey = formatUsbDeviceId(parsed.vendorId, parsed.productId).toUpperCase()
    this.startPeripheralPolicyUpdate(deviceKey)
    try {
      const result = PeripheralService.switchUsbDevicePolicyWithResult(
        { vendorId: parsed.vendorId, productId: parsed.productId },
        deviceType,
        policyIndex === 0 ? PeripheralService.USB_DEVICE_POLICY_ALLOW : PeripheralService.USB_DEVICE_POLICY_DENY
      )
      if (!result.success) {
        this.errorMessage = result.userMessage?.trim() || result.errorMessage || '修改设备策略失败'
        return false
      }
      await this.reloadAllData()
      this.errorMessage = null
      return true
    } catch (err) {
      this.errorMessage = `修改设备策略失败：${JSON.stringify(err)}`
      return false
    } finally {
      this.endPeripheralPolicyUpdate(deviceKey)
    }
  }

  isPeripheralPolicyUpdating(deviceId: string): boolean {
    return this.policyUpdatingKeys.includes(deviceId) || this.policyUpdatingKeys.includes(deviceId.toUpperCase())
  }

  startPeripheralPolicyUpdate(deviceId: string): void {
    if (!this.policyUpdatingKeys.includes(deviceId)) {
      this.policyUpdatingKeys = [...this.policyUpdatingKeys, deviceId]
    }
  }

  endPeripheralPolicyUpdate(deviceId: string): void {
    this.policyUpdatingKeys = this.policyUpdatingKeys.filter((item: string) => item !== deviceId)
  }

  openConnectionDetailDialog(record: PeripheralConnectionRecord): void {
    this.connectionDetailDialog = {
      visible: true,
      record: record,
      historyItems: this.getConnectionHistoryItems(record)
    }
  }

  closeConnectionDetailDialog(): void {
    this.connectionDetailDialog = {
      visible: false,
      record: null,
      historyItems: []
    }
  }

  async exportConnectionHistory(): Promise<boolean> {
    if (this.deviceRecords.length === 0) {
      this.errorMessage = '没有可导出的设备连接记录'
      return false
    }
    if (!this.appContext) {
      this.errorMessage = '导出环境未初始化'
      return false
    }

    try {
      hilog.info(DOMAIN, TAG, `exportConnectionHistory start, count=${this.deviceRecords.length}`)
      await LogStorageService.init(this.appContext)
      const exportOptions: LogContentExportOptions = {
        fileNamePrefix: 'peripheral_connection_history',
        count: this.deviceRecords.length,
        emptyErrorMessage: '无可导出的设备连接记录'
      }
      const result = await LogStorageService.exportContentToFile(
        this.buildConnectionHistoryCsv(this.deviceRecords),
        LogExportFormat.CSV,
        'manual',
        exportOptions
      )
      if (!result.success) {
        this.errorMessage = result.errorMessage || '导出历史记录失败，请稍后重试'
        return false
      }
      this.errorMessage = null
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `exportConnectionHistory failed: ${JSON.stringify(err)}`)
      this.errorMessage = '导出历史记录失败，请稍后重试'
      return false
    }
  }

  async exportPeripheralPolicyRecords(): Promise<boolean> {
    if (this.peripheralPolicyRecords.length === 0) {
      this.errorMessage = '暂无可导出的设备策略记录'
      return false
    }
    if (!this.appContext) {
      this.errorMessage = '导出环境未初始化'
      return false
    }

    try {
      await LogStorageService.init(this.appContext)
      const result = await LogStorageService.exportContentToFile(
        this.buildPeripheralPolicyCsv(this.peripheralPolicyRecords),
        LogExportFormat.CSV,
        'manual',
        {
          fileNamePrefix: 'peripheral_policy_list',
          count: this.peripheralPolicyRecords.length,
          emptyErrorMessage: '暂无可导出的设备策略记录'
        }
      )
      if (!result.success) {
        this.errorMessage = result.errorMessage || '导出策略记录失败，请稍后重试'
        return false
      }
      this.errorMessage = null
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `exportPeripheralPolicyRecords failed: ${JSON.stringify(err)}`)
      this.errorMessage = '导出策略记录失败，请稍后重试'
      return false
    }
  }

  switchToTab(index: number): void {
    if (index < 0 || index > 2 || index === this.currentTab) {
      return
    }
    this.currentTab = index
  }

  private reloadInterfaceState(): void {
    try {
      const usbState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_USB)
      const btState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_BLUETOOTH)
      const wifiState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_WIFI)
      const hdcState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_HDC)
      const networkState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_NETWORK)
      const printerState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_PRINTER)
      const microphoneState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_MICROPHONE)
      const cameraState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_CAMERA)
      const storagePolicy = PeripheralService.getUsbStoragePolicyWithResult()

      this.interfaceState.usbDisabled = usbState.data ?? false
      this.interfaceState.btDisabled = btState.data ?? false
      this.interfaceState.wifiDisabled = wifiState.data ?? false
      this.interfaceState.hdcDisabled = hdcState.data ?? false
      this.interfaceState.networkDisabled = networkState.data ?? false
      this.interfaceState.printerDisabled = printerState.data ?? false
      this.interfaceState.microphoneDisabled = microphoneState.data ?? false
      this.interfaceState.cameraDisabled = cameraState.data ?? false
      this.interfaceState.usbStoragePolicyIndex = this.getUsbStoragePolicyIndex(
        storagePolicy.data ?? edmUsbManager.UsbPolicy.READ_WRITE
      )
    } catch (err) {
      hilog.error(DOMAIN, TAG, `reloadInterfaceState failed: ${JSON.stringify(err)}`)
    }
  }

  private reloadWhitelistBlacklist(): void {
    try {
      this.whitelistBlacklistState.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.whitelistBlacklistState.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.whitelistBlacklistState.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
    } catch (err) {
      hilog.error(DOMAIN, TAG, `reloadWhitelistBlacklist failed: ${JSON.stringify(err)}`)
      this.whitelistBlacklistState = {
        usbWhitelist: [],
        usbBlacklist: [],
        btWhitelist: []
      }
    }
  }

  private loadPeripheralPolicyData(): void {
    const whitelistKeys: Set<string> = new Set(
      this.whitelistBlacklistState.usbWhitelist.map((device: edmUsbManager.UsbDeviceId) => {
        return formatUsbDeviceId(device.vendorId, device.productId).toUpperCase()
      })
    )
    const blacklistKeys: Set<string> = new Set(
      this.whitelistBlacklistState.usbBlacklist.map((deviceType: edmUsbManager.UsbDeviceType) => {
        return `${deviceType.baseClass}|${deviceType.subClass}|${deviceType.protocol}`
      })
    )
    const items: Map<string, PeripheralPolicyRecord> = new Map()

    for (const record of this.deviceRecords) {
      if (this.usbRecordTypes.indexOf(record.deviceType) < 0) {
        continue
      }
      const parsed = parseUsbDeviceId(record.deviceId)
      if (!parsed) {
        continue
      }
      const deviceKey = formatUsbDeviceId(parsed.vendorId, parsed.productId).toUpperCase()
      const existing = items.get(deviceKey)
      if (existing && existing.lastSeenAt >= record.timestamp) {
        continue
      }

      let policyIndex = 0
      const baseClass = inferUsbBaseClass(record.deviceType)
      if (baseClass > 0 && blacklistKeys.has(`${baseClass}|0|0`)) {
        policyIndex = 1
      } else if (whitelistKeys.has(deviceKey)) {
        policyIndex = 0
      }

      items.set(deviceKey, {
        deviceName: record.deviceName,
        deviceType: record.deviceType,
        deviceId: formatUsbDeviceId(parsed.vendorId, parsed.productId),
        lastSeenAt: record.timestamp,
        lastSeenLabel: this.formatTimestamp(record.timestamp),
        policyIndex: policyIndex
      })
    }

    this.peripheralPolicyRecords = Array.from(items.values()).sort((left: PeripheralPolicyRecord, right: PeripheralPolicyRecord) => {
      return right.lastSeenAt - left.lastSeenAt
    })
  }

  private getConnectionHistoryItems(record: PeripheralConnectionRecord | null): ConnectionHistoryItem[] {
    if (!record) {
      return []
    }

    const deviceKey = record.deviceId.replace(/\s+/g, '').toUpperCase()
    const history: ConnectionHistoryItem[] = []
    for (const item of this.deviceRecords) {
      if (item.timestamp <= 0) {
        continue
      }
      if (item.deviceId.replace(/\s+/g, '').toUpperCase() !== deviceKey) {
        continue
      }
      const nextItem: ConnectionHistoryItem = {
        time: this.formatConnectionTime(item),
        policy: this.getConnectionPolicyHitLabel(item),
        result: this.getConnectionResultLabel(item)
      }
      if (!history.some((existing: ConnectionHistoryItem) => {
        return existing.time === nextItem.time &&
          existing.policy === nextItem.policy &&
          existing.result === nextItem.result
      })) {
        history.push(nextItem)
      }
    }
    return history
  }

  private getUsbStoragePolicyIndex(policy: edmUsbManager.UsbPolicy): number {
    if (policy === edmUsbManager.UsbPolicy.READ_ONLY) {
      return 0
    }
    if (policy === edmUsbManager.UsbPolicy.READ_WRITE) {
      return 1
    }
    return 2
  }

  private formatTimestamp(timestamp: number): string {
    if (timestamp <= 0) {
      return '--'
    }
    return formatLogTimestamp(timestamp)
  }

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    return this.formatTimestamp(record.timestamp)
  }

  private getConnectionPolicyHitLabel(record: PeripheralConnectionRecord): string {
    if (record.source === 'policy_snapshot') {
      return '未审计'
    }
    if (record.matchedPolicyKind && record.matchedPolicyKind !== 'unknown') {
      return this.getMatchedPolicyKindLabel(record)
    }
    return getPeripheralRecordPolicyHitLabel(record.policyHit)
  }

  private getConnectionResultLabel(record: PeripheralConnectionRecord): string {
    if (record.source === 'policy_snapshot') {
      return '快照'
    }
    return getLogEventResultLabel(record.result)
  }

  private getMatchedPolicyKindLabel(record: PeripheralConnectionRecord): string {
    switch (record.matchedPolicyKind) {
      case 'usb_disabled':
        return 'USB 接口禁用'
      case 'usb_storage_disabled':
        return 'USB 存储已禁用'
      case 'usb_storage_read_only':
        return 'USB 存储只读'
      case 'usb_whitelist':
        return '命中 USB 白名单'
      case 'usb_blacklist':
        return '命中 USB 黑名单'
      case 'default_allow':
        return '默认允许'
      case 'disconnect_event':
        return '断开事件'
      default:
        return getPeripheralRecordPolicyHitLabel(record.policyHit)
    }
  }

  private buildConnectionHistoryCsv(records: PeripheralConnectionRecord[]): string {
    const headers: string[] = [
      '时间',
      '设备名称',
      '设备类型',
      '设备标识',
      '连接事件',
      '策略命中',
      '结果状态',
      '事件来源'
    ]
    const rows = records.map((record: PeripheralConnectionRecord) => {
      return [
        this.formatConnectionTime(record),
        record.deviceName,
        getPeripheralTypeLabel(record.deviceType),
        record.deviceId,
        getPeripheralRecordActionLabel(record.action),
        this.getConnectionPolicyHitLabel(record),
        this.getConnectionResultLabel(record),
        getPeripheralRecordSourceLabel(record.source)
      ].map((value: string) => this.escapeCsvValue(value)).join(',')
    })
    return `\uFEFF${headers.map((value: string) => this.escapeCsvValue(value)).join(',')}\n${rows.join('\n')}`
  }

  private buildPeripheralPolicyCsv(records: PeripheralPolicyRecord[]): string {
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
        this.getPeripheralPolicyLabel(record.policyIndex)
      ].map((value: string) => this.escapeCsvValue(value)).join(',')
    })
    return `\uFEFF${headers.map((value: string) => this.escapeCsvValue(value)).join(',')}\n${rows.join('\n')}`
  }

  private getPeripheralPolicyLabel(policyIndex: number): string {
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

export { PeripheralViewModel }

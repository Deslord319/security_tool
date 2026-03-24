import { AppColors, AppStyles } from '../constants/AppConstants'
import { PeripheralService } from '../services/PeripheralService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { PeripheralRuntimeEventService } from '../services/PeripheralRuntimeEventService'
import { PeripheralConnectionRecordService } from '../services/PeripheralConnectionRecordService'
import { InterfaceControlItem } from '../components/InterfaceControlItem'
import { AddWhitelistDialog } from '../components/AddWhitelistDialog'
import { AddBlacklistDialog } from '../components/AddBlacklistDialog'
import {
  AdminActivationState,
  DeviceRecord,
  DeviceControlRecord,
  PeripheralPolicyRecord,
  PeripheralBlacklistTemplate,
  PeripheralCandidateSource,
  PeripheralConnectionRecord,
  PeripheralMatchedPolicyKind,
  PeripheralWhitelistCandidate,
  OperationResult,
  PeripheralType,
  PeripheralRecordAction,
  LogEventResult,
  LogExportFormat,
  UsbStoragePolicy,
  formatLogTimestamp,
  getLogEventResultLabel,
  getPeripheralRecordActionLabel,
  getPeripheralCandidateSourceLabel,
  getPeripheralRecordPolicyHitLabel,
  getPeripheralRecordSourceLabel,
  getPeripheralTypeLabel,
  getUsbStoragePolicyLabel,
  ParsedUsbId,
  parseUsbDeviceId,
  parseBluetoothMac,
  formatUsbDeviceId,
  inferUsbBaseClass,
  inferPeripheralTypeFromBaseClass
} from '../models/DataModels'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { common } from '@kit.AbilityKit'
import { BusinessError, usbManager as hostUsbManager } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { SymbolGlyphModifier, TextModifier } from '@kit.ArkUI'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { LogContentExportOptions, LogStorageService } from '../services/LogStorageService'
import { BackNavButton } from '../components/BackNavButton'
import { HoverUtils } from '../utils/HoverUtils'
import { FormControlUtils } from '../utils/FormControlUtils'
import { ResultMessageBox, ResultMessageStatus } from '../components/ResultMessageBox'
import { ResultDialogHelper } from '../utils/ResultDialogHelper'

const TAG = 'PeripheralPage'
const DOMAIN = 0x0013
const MIN_USB_LOADING_DIALOG_DURATION_MS = 500
type PeripheralResultData =
  boolean |
  number |
  string |
  edmUsbManager.UsbPolicy |
  edmUsbManager.UsbDeviceId[] |
  edmUsbManager.UsbDeviceType[] |
  void

interface UsbBlacklistDefaultTemplate {
  title: string
  description: string
  baseClass: number
}

interface ConnectionHistoryItem {
  time: string
  policy: string
  result: string
}

@CustomDialog
struct PeripheralUsbLoadingDialog {
  controller: CustomDialogController
  message: string = '正在更新 USB 策略，请稍候'
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 14 }) {
      LoadingProgress()
        .width(44)
        .height(44)
      Text(this.message)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .textAlign(TextAlign.Center)
    }
    .width(280)
    .padding({ left: 24, right: 24, top: 28, bottom: 28 })
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow({
      radius: 20,
      color: this.currentTheme === ThemeMode.DARK ? 'rgba(0,0,0,0.36)' : 'rgba(0,0,0,0.14)',
      offsetX: 0,
      offsetY: 10
    })
  }
}

@Component
export struct PeripheralPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State currentTab: number = 0
  @State hoveredPanelIndex: number = -1
  @State hoveredDeviceRecordIndex: number = -1
  @State hoveredPolicyRecordIndex: number = -1
  @State isLoading: boolean = false
  @State adminState: AdminActivationState = {
    activated: false,
    enableCommand: EnterpriseAdminService.buildEnableCommand(),
    adminType: EnterpriseAdminService.DEFAULT_ADMIN_TYPE
  }

  // 接口管控状态
  @State usbDisabled: boolean = false
  @State btDisabled: boolean = false
  @State wifiDisabled: boolean = false
  @State hdcDisabled: boolean = false
  @State networkDisabled: boolean = false
  @State printerDisabled: boolean = false
  @State microphoneDisabled: boolean = false
  @State cameraDisabled: boolean = false
  @State usbStoragePolicyIndex: number = 0
  @State interfaceControlSyncToken: number = 0
  @State interfaceControlProcessingKey: string = ''

  // 黑白名单数据
  @State usbWhitelist: edmUsbManager.UsbDeviceId[] = []
  @State usbBlacklist: edmUsbManager.UsbDeviceType[] = []
  @State btWhitelist: string[] = []
  @State connectedUsbDevices: hostUsbManager.USBDevice[] = []

  // 设备连接记录（本地模拟数据）
  @State deviceRecords: PeripheralConnectionRecord[] = []
  @State recordFilterTypeIndex: number = 0
  @State recordFilterResultIndex: number = 0
  @State recordFilterSourceIndex: number = 1
  @State recordFilterKeyword: string = ''
  @State recordHintMessage: string = ''
  @State lastRecordHintToastMessage: string = ''
  @State isConnectionDetailDialogVisible: boolean = false
  @State selectedConnectionRecord: PeripheralConnectionRecord | null = null
  @State connectionDetailHostWidth: number = 0
  private recordStorageListenerId: number = -1
  private traceStorageListenerId: number = -1
  private recordAutoRefreshTimerId: number = -1
  private readonly recordAutoRefreshIntervalMs: number = 2000
  private readonly connectionDetailCompactWidthThreshold: number = 1200
  private readonly usbStorageControlKey: string = 'usb-storage-policy'
  private readonly recordTypeFilterOptions: SelectOption[] = [
    { value: '全部类型' },
    { value: 'USB' },
    { value: '蓝牙' }
  ]
  private readonly recordResultFilterOptions: SelectOption[] = [
    { value: '全部结果' },
    { value: '成功' },
    { value: '已阻止' },
    { value: '失败' }
  ]
  private readonly recordSourceFilterOptions: SelectOption[] = [
    { value: '全部来源' },
    { value: '实时事件' },
    { value: '仅运行时' },
    { value: '仅审计' },
    { value: '仅快照' }
  ]
  private readonly usbRecordTypes: PeripheralType[] = [
    PeripheralType.USB_STORAGE,
    PeripheralType.USB_CAMERA,
    PeripheralType.USB_PRINTER,
    PeripheralType.USB_HID,
    PeripheralType.USB_OTHER
  ]

  // 设备管控记录（独立数据源）
  @State deviceControlRecords: DeviceControlRecord[] = []
  @State peripheralPolicyRecords: PeripheralPolicyRecord[] = []
  @State policyUpdatingKeys: string[] = []
  @State peripheralPolicyRenderVersion: number = 0
  private resultDialogController: CustomDialogController = new CustomDialogController({
    builder: ResultMessageBox({
      onConfirm: () => {
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  })
  private usbLoadingDialogController?: CustomDialogController
  private isUsbLoadingDialogOpen: boolean = false
  private usbLoadingDialogOpenedAt: number = 0
  private deviceControlPolicyOptions: SelectOption[] = [
    { value: '允许' },
    { value: '禁止' },
    { value: '未配置' }
  ]
  // 弹窗控制器
  private policyListOptions: SelectOption[] = [
    { value: '允许接入' },
    { value: '禁止访问' }
  ]
  private usbWhitelistDialogController: CustomDialogController = new CustomDialogController({
    builder: AddWhitelistDialog({
      mode: 'usb',
      getCandidates: (): PeripheralWhitelistCandidate[] => this.getUsbWhitelistCandidates(),
      emptyHint: '暂无可添加的 USB 设备，请先连接设备或使用手动录入。',
      onConfirmUsb: (vendorId: number, productId: number, _remark: string) => {
        this.handleAddUsbWhitelist(vendorId, productId)
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  private btWhitelistDialogController: CustomDialogController = new CustomDialogController({
    builder: AddWhitelistDialog({
      mode: 'bluetooth',
      getCandidates: (): PeripheralWhitelistCandidate[] => this.getBluetoothWhitelistCandidates(),
      emptyHint: '暂无蓝牙候选设备，请先产生连接记录或使用手动录入。',
      onConfirmBluetooth: (mac: string, _remark: string) => {
        this.handleAddBluetoothWhitelist(mac)
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  private blacklistDialogController: CustomDialogController = new CustomDialogController({
    builder: AddBlacklistDialog({
      getTemplates: (): PeripheralBlacklistTemplate[] => this.getUsbBlacklistTemplates(),
      onConfirm: (baseClass: number, subClass: number, protocol: number, _desc: string) => {
        this.handleAddUsbBlacklist(baseClass, subClass, protocol)
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  aboutToAppear() {
    this.refreshAdminActivationState()
    this.loadAllData()
    this.subscribeTraceStorageChange()
  }

  private showResultDialog(status: ResultMessageStatus, message: string): void {
    ResultDialogHelper.prepareResultDialog(status, message)
    try {
      this.resultDialogController.close()
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to close result dialog: ${JSON.stringify(err)}`)
    }
    this.resultDialogController.open()
  }

  private openUsbLoadingDialog(message: string): void {
    this.closeUsbLoadingDialog()
    this.usbLoadingDialogController = new CustomDialogController({
      builder: PeripheralUsbLoadingDialog({
        message: message
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      customStyle: true
    })
    this.usbLoadingDialogOpenedAt = Date.now()
    this.usbLoadingDialogController.open()
    this.isUsbLoadingDialogOpen = true
  }

  private closeUsbLoadingDialog(): void {
    if (!this.isUsbLoadingDialogOpen) {
      this.usbLoadingDialogOpenedAt = 0
      this.usbLoadingDialogController = undefined
      return
    }
    try {
      this.usbLoadingDialogController?.close()
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to close USB loading dialog: ${JSON.stringify(err)}`)
    } finally {
      this.isUsbLoadingDialogOpen = false
      this.usbLoadingDialogOpenedAt = 0
      this.usbLoadingDialogController = undefined
    }
  }

  private async waitForUsbLoadingDialogMinimumDuration(): Promise<void> {
    if (!this.isUsbLoadingDialogOpen) {
      return
    }
    let elapsed = Date.now() - this.usbLoadingDialogOpenedAt
    let remainingDuration = MIN_USB_LOADING_DIALOG_DURATION_MS - elapsed
    if (remainingDuration <= 0) {
      return
    }
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve()
      }, remainingDuration)
    })
  }

  private async runUsbOperationWithLoading<T>(message: string, operation: () => T): Promise<T> {
    this.openUsbLoadingDialog(message)
    try {
      return operation()
    } finally {
      await this.waitForUsbLoadingDialogMinimumDuration()
      this.closeUsbLoadingDialog()
    }
  }

  aboutToDisappear() {
    this.closeUsbLoadingDialog()
    this.unsubscribeTraceStorageChange()
  }

  private loadConnectedUsbDevices(): void {
    try {
      this.connectedUsbDevices = hostUsbManager.getDevices() || []
    } catch (err) {
      let error = err as BusinessError
      this.connectedUsbDevices = []
      hilog.warn(0x0002, TAG, `loadConnectedUsbDevices failed: code=${error.code}, message=${error.message}`)
    }
  }

  private openUsbWhitelistDialog(): void {
    this.loadConnectedUsbDevices()
    this.usbWhitelistDialogController.open()
  }

  private openBtWhitelistDialog(): void {
    this.btWhitelistDialogController.open()
  }

  private openUsbBlacklistDialog(): void {
    this.loadConnectedUsbDevices()
    this.blacklistDialogController.open()
  }

  private normalizeMac(rawMac: string): string {
    return rawMac.toUpperCase().replace(/-/g, ':').trim()
  }

  private formatTimestamp(timestamp: number): string {
    return timestamp > 0 ? formatLogTimestamp(timestamp) : '--'
  }

  private getCandidateSortWeight(source: PeripheralCandidateSource): number {
    if (source === 'connected_usb') {
      return 0
    }
    if (source === 'runtime_event') {
      return 1
    }
    if (source === 'audit_event') {
      return 2
    }
    return 3
  }

  private compareCandidateTime(left: PeripheralWhitelistCandidate, right: PeripheralWhitelistCandidate): number {
    if (left.timestamp === right.timestamp) {
      return this.getCandidateSortWeight(left.source) - this.getCandidateSortWeight(right.source)
    }
    return right.timestamp - left.timestamp
  }

  private getUsbWhitelistCandidates(): PeripheralWhitelistCandidate[] {
    let items: Map<string, PeripheralWhitelistCandidate> = new Map()
    let disabledKeys: string[] = this.usbWhitelist.map((device: edmUsbManager.UsbDeviceId) => {
      return formatUsbDeviceId(device.vendorId, device.productId).toUpperCase()
    })

    for (let device of this.connectedUsbDevices) {
      let deviceId = formatUsbDeviceId(device.vendorId, device.productId)
      let key = deviceId.toUpperCase()
      if (items.has(key)) {
        continue
      }
      let type = inferPeripheralTypeFromBaseClass(device.clazz)
      let name = this.buildUsbDisplayName(
        device.manufacturerName,
        device.productName,
        device.vendorId,
        device.productId
      )
      items.set(key, {
        id: `usb_connected_${key}`,
        deviceName: name,
        deviceType: type,
        deviceId: deviceId,
        timestamp: Date.now(),
        source: 'connected_usb',
        vendorId: device.vendorId,
        productId: device.productId,
        isConnected: true,
        disabled: disabledKeys.includes(key)
      })
    }

    for (let record of this.deviceRecords) {
      let parsed = parseUsbDeviceId(record.deviceId)
      if (!parsed) {
        continue
      }
      let key = formatUsbDeviceId(parsed.vendorId, parsed.productId).toUpperCase()
      if (items.has(key)) {
        continue
      }
      items.set(key, {
        id: `usb_history_${record.id}`,
        deviceName: record.deviceName,
        deviceType: record.deviceType,
        deviceId: formatUsbDeviceId(parsed.vendorId, parsed.productId),
        timestamp: record.timestamp,
        source: record.source,
        vendorId: parsed.vendorId,
        productId: parsed.productId,
        disabled: disabledKeys.includes(key)
      })
    }

    return Array.from(items.values()).sort((left: PeripheralWhitelistCandidate, right: PeripheralWhitelistCandidate) => {
      return this.compareCandidateTime(left, right)
    })
  }

  private getBluetoothWhitelistCandidates(): PeripheralWhitelistCandidate[] {
    let items: Map<string, PeripheralWhitelistCandidate> = new Map()
    let disabledKeys: string[] = this.btWhitelist.map((mac: string) => this.normalizeMac(mac))

    for (let record of this.deviceRecords) {
      let mac = parseBluetoothMac(record.deviceId)
      if (!mac) {
        continue
      }
      let normalizedMac = this.normalizeMac(mac)
      if (items.has(normalizedMac)) {
        continue
      }
      items.set(normalizedMac, {
        id: `bt_${record.id}`,
        deviceName: record.deviceName,
        deviceType: PeripheralType.BLUETOOTH,
        deviceId: `MAC: ${normalizedMac}`,
        timestamp: record.timestamp,
        source: record.source,
        mac: normalizedMac,
        disabled: disabledKeys.includes(normalizedMac)
      })
    }

    return Array.from(items.values()).sort((left: PeripheralWhitelistCandidate, right: PeripheralWhitelistCandidate) => {
      return this.compareCandidateTime(left, right)
    })
  }

  private buildBlacklistTemplateKey(baseClass: number, subClass: number, protocol: number): string {
    return `${baseClass}|${subClass}|${protocol}`
  }

  private appendBlacklistTemplate(
    items: Map<string, PeripheralBlacklistTemplate>,
    disabledKeys: string[],
    title: string,
    description: string,
    baseClass: number,
    subClass: number,
    protocol: number,
    fromConnectedDevice: boolean
  ): void {
    let key = this.buildBlacklistTemplateKey(baseClass, subClass, protocol)
    if (items.has(key)) {
      return
    }
    items.set(key, {
      id: `usb_blacklist_${key}`,
      title: title,
      description: description,
      baseClass: baseClass,
      subClass: subClass,
      protocol: protocol,
      fromConnectedDevice: fromConnectedDevice,
      disabled: disabledKeys.includes(key)
    })
  }

  private getUsbBlacklistTemplates(): PeripheralBlacklistTemplate[] {
    let items: Map<string, PeripheralBlacklistTemplate> = new Map()
    let disabledKeys: string[] = this.usbBlacklist.map((item: edmUsbManager.UsbDeviceType) => {
      return this.buildBlacklistTemplateKey(item.baseClass, item.subClass, item.protocol)
    })

    for (let device of this.connectedUsbDevices) {
      let title = this.buildUsbDisplayName(
        device.manufacturerName,
        device.productName,
        device.vendorId,
        device.productId
      )
      let description = `${formatUsbDeviceId(device.vendorId, device.productId)} · 当前连接 USB 设备`
      this.appendBlacklistTemplate(
        items,
        disabledKeys,
        title,
        description,
        device.clazz,
        device.subClass,
        device.protocol,
        true
      )
    }

    let defaults: UsbBlacklistDefaultTemplate[] = [
      { title: 'USB 存储设备', description: '通用大容量存储设备模板', baseClass: 0x08 },
      { title: 'USB 打印设备', description: '通用打印设备模板', baseClass: 0x07 },
      { title: 'USB 摄像设备', description: '通用摄像设备模板', baseClass: 0x0E }
    ]
    for (let item of defaults) {
      this.appendBlacklistTemplate(
        items,
        disabledKeys,
        item.title,
        item.description,
        item.baseClass,
        0,
        0,
        false
      )
    }

    for (let record of this.deviceRecords) {
      let baseClass = inferUsbBaseClass(record.deviceType)
      if (baseClass <= 0) {
        continue
      }
      this.appendBlacklistTemplate(
        items,
        disabledKeys,
        `${record.deviceName} 类型模板`,
        `${getPeripheralCandidateSourceLabel(record.source)} · ${this.formatTimestamp(record.timestamp)}`,
        baseClass,
        0,
        0,
        false
      )
    }

    let templates = Array.from(items.values())
    templates.sort((left: PeripheralBlacklistTemplate, right: PeripheralBlacklistTemplate) => {
      if (left.fromConnectedDevice === right.fromConnectedDevice) {
        return left.title.localeCompare(right.title)
      }
      return left.fromConnectedDevice ? -1 : 1
    })
    return templates
  }

  private subscribeTraceStorageChange(): void {
    this.unsubscribeTraceStorageChange()
    this.traceStorageListenerId = PeripheralTraceRepository.addChangeListener(() => {
      this.reloadDeviceRecords()
    })
  }

  private unsubscribeTraceStorageChange(): void {
    if (this.traceStorageListenerId < 0) {
      return
    }
    PeripheralTraceRepository.removeChangeListener(this.traceStorageListenerId)
    this.traceStorageListenerId = -1
  }
  private reloadDeviceRecords(): void {
    this.deviceRecords = PeripheralConnectionRecordService.queryRecords()
    this.loadPeripheralPolicyData()
  }
  private buildPreviewConnectionRecordsLegacy(): PeripheralConnectionRecord[] {
    let now = Date.now()
    return [
      {
        id: 'preview-camera-connect',
        timestamp: now - 5 * 60 * 1000,
        collectAt: now - 5 * 60 * 1000 + 800,
        deviceName: 'ShineOptics FHD Camera',
        deviceType: PeripheralType.USB_CAMERA,
        deviceId: 'VID:2B7E PID:B5A2',
        action: 'connect',
        result: LogEventResult.SUCCESS,
        policyHit: 'allow',
        source: 'runtime_event',
        summary: '允许接入',
        correlationId: 'preview-camera-1',
        policyVersion: 'preview-v1',
        rawEventName: 'usb_device_attached',
        rawOutcome: 'allowed',
        rawAction: 'connect',
        rawPayload: '{"vendorId":"2B7E","productId":"B5A2"}',
        detail: '摄像头接入后已通过策略校验，允许继续使用。',
        processName: 'CameraService',
        usbPolicy: undefined
      },
      {
        id: 'preview-storage-block',
        timestamp: now - 18 * 60 * 1000,
        collectAt: now - 18 * 60 * 1000 + 1200,
        deviceName: 'SanDisk Ultra USB 3.0',
        deviceType: PeripheralType.USB_STORAGE,
        deviceId: 'VID:0781 PID:5583',
        action: 'intercept',
        result: LogEventResult.BLOCKED,
        policyHit: 'deny',
        source: 'audit_event',
        summary: '策略阻止',
        correlationId: 'preview-storage-1',
        policyVersion: 'preview-v1',
        rawEventName: 'usb_mass_storage_attach',
        rawOutcome: 'blocked',
        rawAction: 'mount',
        rawPayload: '{"vendorId":"0781","productId":"5583"}',
        detail: '检测到可移动存储设备接入，按只读外设策略阻止访问。',
        processName: 'UsbPolicyGuard',
        usbPolicy: UsbStoragePolicy.DISABLED
      },
      {
        id: 'preview-printer-disconnect',
        timestamp: now - 46 * 60 * 1000,
        collectAt: now - 46 * 60 * 1000 + 600,
        deviceName: 'HP LaserJet Pro M404',
        deviceType: PeripheralType.USB_PRINTER,
        deviceId: 'VID:03F0 PID:0C17',
        action: 'disconnect',
        result: LogEventResult.SUCCESS,
        policyHit: 'allow',
        source: 'runtime_event',
        summary: '允许接入',
        correlationId: 'preview-printer-1',
        policyVersion: 'preview-v1',
        rawEventName: 'usb_printer_detached',
        rawOutcome: 'completed',
        rawAction: 'disconnect',
        rawPayload: '{"vendorId":"03F0","productId":"0C17"}',
        detail: '打印机已安全断开，未触发额外限制。',
        processName: 'PrintSpooler',
        usbPolicy: undefined
      },
      {
        id: 'preview-keyboard-connect',
        timestamp: now - 85 * 60 * 1000,
        collectAt: now - 85 * 60 * 1000 + 500,
        deviceName: 'Logitech MX Keys',
        deviceType: PeripheralType.BLUETOOTH,
        deviceId: 'MAC: AA:BB:CC:DD:EE:01',
        action: 'connect',
        result: LogEventResult.SUCCESS,
        policyHit: 'allow',
        source: 'runtime_event',
        summary: '允许接入',
        correlationId: 'preview-bt-1',
        policyVersion: 'preview-v1',
        rawEventName: 'bluetooth_device_connected',
        rawOutcome: 'allowed',
        rawAction: 'pair',
        rawPayload: '{"mac":"AA:BB:CC:DD:EE:01"}',
        detail: '蓝牙键盘已完成配对并加入可信设备列表。',
        processName: 'BluetoothService',
        usbPolicy: undefined
      },
      {
        id: 'preview-keyboard-history',
        timestamp: now - 140 * 60 * 1000,
        collectAt: now - 140 * 60 * 1000 + 700,
        deviceName: 'Logitech MX Keys',
        deviceType: PeripheralType.BLUETOOTH,
        deviceId: 'MAC: AA:BB:CC:DD:EE:01',
        action: 'disconnect',
        result: LogEventResult.SUCCESS,
        policyHit: 'allow',
        source: 'audit_event',
        summary: '允许接入',
        correlationId: 'preview-bt-2',
        policyVersion: 'preview-v1',
        rawEventName: 'bluetooth_device_disconnected',
        rawOutcome: 'completed',
        rawAction: 'disconnect',
        rawPayload: '{"mac":"AA:BB:CC:DD:EE:01"}',
        detail: '蓝牙键盘连接结束，保留历史记录用于界面预览。',
        processName: 'BluetoothService',
        usbPolicy: undefined
      }
    ]
  }

  private buildRuntimeDegradeHintLegacy(): string {
    let runtimeStatus = PeripheralRuntimeEventService.getStatus()
    if (runtimeStatus.capabilities.usbRuntimeEvents) {
      return ''
    }
    return '当前版本未启用运行时采集，已使用审计事件和策略快照。'
  }
  private updateRecordHintMessageLegacy(message: string): void {
    this.recordHintMessage = message
    if (message.length === 0) {
      this.lastRecordHintToastMessage = ''
      return
    }
    if (this.lastRecordHintToastMessage === message) {
      return
    }
    this.lastRecordHintToastMessage = message
    try {
      hilog.info(0x0002, TAG, `record hint: ${message}`)
    } catch (e) {
      hilog.error(0x0002, TAG, `record hint log failed: ${JSON.stringify(e)}`)
    }
  }

  private refreshAdminActivationState(): void {
    this.adminState = EnterpriseAdminService.probeActivation()
  }

  private ensureAdminReady(action: string): boolean {
    this.refreshAdminActivationState()
    if (this.adminState.activated) {
      return true
    }
    this.showResultDialog(
      'failure',
      ResultDialogHelper.displayReason(this.adminState.errorMessage, `${action}未完成，请先激活企业管理员`)
    )
    return false
  }

  private showOperationFailure(action: string, result: OperationResult<PeripheralResultData>): void {
    let dialogMessage: string = result.isAdminMissing
      ? ResultDialogHelper.displayReason(result.errorMessage, '企业管理员未激活')
      : ResultDialogHelper.displayReason(result.errorMessage, `${action}未完成，请稍后重试`)
    this.showResultDialog('failure', dialogMessage)
  }

  loadAllData() {
    this.isLoading = true
    this.refreshAdminActivationState()

    if (this.adminState.activated) {
      // 加载接口管控状态
      let usbState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_USB)
      let btState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_BLUETOOTH)
      let wifiState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_WIFI)
      let hdcState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_HDC)
      let networkState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_NETWORK)
      let printerState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_PRINTER)
      let microphoneState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_MICROPHONE)
      let cameraState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_CAMERA)
      this.usbDisabled = usbState.data ?? false
      this.btDisabled = btState.data ?? false
      this.wifiDisabled = wifiState.data ?? false
      this.hdcDisabled = hdcState.data ?? false
      this.networkDisabled = networkState.data ?? false
      this.printerDisabled = printerState.data ?? false
      this.microphoneDisabled = microphoneState.data ?? false
      this.cameraDisabled = cameraState.data ?? false

      // 加载 USB 存储策略
      let policyResult = PeripheralService.getUsbStoragePolicyWithResult()
      let policy = policyResult.data ?? edmUsbManager.UsbPolicy.READ_WRITE
      if (policy === edmUsbManager.UsbPolicy.READ_ONLY) {
        this.usbStoragePolicyIndex = 0
      } else if (policy === edmUsbManager.UsbPolicy.READ_WRITE) {
        this.usbStoragePolicyIndex = 1
      } else {
        this.usbStoragePolicyIndex = 2
      }

      // 加载黑白名单
      this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
    } else {
      this.usbDisabled = false
      this.btDisabled = false
      this.wifiDisabled = false
      this.hdcDisabled = false
      this.networkDisabled = false
      this.printerDisabled = false
      this.microphoneDisabled = false
      this.cameraDisabled = false
      this.usbStoragePolicyIndex = 1
      this.usbWhitelist = []
      this.usbBlacklist = []
      this.btWhitelist = []
    }

    // 模拟设备连接记录
    this.loadConnectedUsbDevices()
    this.reloadDeviceRecords()
    /*
      {
        deviceName: 'ShineOptics FHD Camera',
        deviceType: PeripheralType.USB_CAMERA,
        deviceId: 'VID:2B7E PID:B5A2',
        connectTime: '2026-02-09 16:01:19',
        policy: '允许'
      },
      {
        deviceName: 'SanDisk Ultra USB 3.0',
        deviceType: PeripheralType.USB_STORAGE,
        deviceId: 'VID:0781 PID:5583',
        connectTime: '2026-02-09 14:30:08',
        policy: '拒绝'
      },
      {
        deviceName: 'HP LaserJet Pro M404',
        deviceType: PeripheralType.USB_PRINTER,
        deviceId: 'VID:03F0 PID:0C17',
        connectTime: '2026-02-09 10:15:42',
        policy: '允许'
      },
      {
        deviceName: 'Logitech MX Keys',
        deviceType: PeripheralType.BLUETOOTH,
        deviceId: 'MAC: AA:BB:CC:DD:EE:01',
        connectTime: '2026-02-09 09:00:05',
        policy: '允许'
      }
    ]
    */

    // 从 MDM API 加载设备管控记录
    this.deviceControlRecords = []

    this.isLoading = false
  }

  // ========== 设备管控数据加载 ==========

  // 常见设备 VID/PID -> 名称映射
  private getInterfaceControlKey(feature: string): string {
    return `feature:${feature}`
  }

  private isInterfaceControlProcessing(controlKey: string): boolean {
    return this.interfaceControlProcessingKey === controlKey
  }

  private mapUsbStoragePolicyToIndex(policy: edmUsbManager.UsbPolicy): number {
    if (policy === edmUsbManager.UsbPolicy.READ_ONLY) {
      return 0
    }
    if (policy === edmUsbManager.UsbPolicy.READ_WRITE) {
      return 1
    }
    return 2
  }

  private getUsbStoragePolicyLogValue(index: number): string {
    let values: string[] = ['read_only', 'read_write', 'disabled']
    return values[index] ?? `unknown_${index}`
  }

  private reloadInterfaceControlState(reason: string): void {
    hilog.info(0x0002, TAG, `interfaceControl reload start, reason=${reason}`)
    let usbState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_USB)
    let btState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_BLUETOOTH)
    let wifiState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_WIFI)
    let hdcState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_HDC)
    let networkState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_NETWORK)
    let printerState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_PRINTER)
    let microphoneState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_MICROPHONE)
    let cameraState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_CAMERA)
    let policyResult = PeripheralService.getUsbStoragePolicyWithResult()
    let policy = policyResult.data ?? edmUsbManager.UsbPolicy.READ_WRITE

    this.usbDisabled = usbState.data ?? false
    this.btDisabled = btState.data ?? false
    this.wifiDisabled = wifiState.data ?? false
    this.hdcDisabled = hdcState.data ?? false
    this.networkDisabled = networkState.data ?? false
    this.printerDisabled = printerState.data ?? false
    this.microphoneDisabled = microphoneState.data ?? false
    this.cameraDisabled = cameraState.data ?? false
    this.usbStoragePolicyIndex = this.mapUsbStoragePolicyToIndex(policy)
    this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
    this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
    this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
    this.interfaceControlSyncToken += 1

    hilog.info(
      0x0002,
      TAG,
      `interfaceControl reload done, reason=${reason}, usb=${this.usbDisabled ? 1 : 0}, usbStorage=${this.getUsbStoragePolicyLogValue(this.usbStoragePolicyIndex)}, bt=${this.btDisabled ? 1 : 0}, wifi=${this.wifiDisabled ? 1 : 0}, hdc=${this.hdcDisabled ? 1 : 0}, network=${this.networkDisabled ? 1 : 0}, printer=${this.printerDisabled ? 1 : 0}, microphone=${this.microphoneDisabled ? 1 : 0}, camera=${this.cameraDisabled ? 1 : 0}`
    )
  }

  private static USB_DEVICE_NAMES: Map<string, string> = new Map([
    ['2B7E_B5A2', 'ShineOptics FHD Camera'],
    ['0781_5583', 'SanDisk Ultra USB 3.0'],
    ['03F0_0C17', 'HP LaserJet Pro M404'],
    ['046D_C52B', 'Logitech Unifying Receiver'],
    ['8087_0026', 'Intel Wireless Bluetooth'],
    ['0BDA_8153', 'Realtek USB Ethernet'],
  ])

  private static BT_DEVICE_NAMES: Map<string, string> = new Map([
    ['AA:BB:CC:DD:EE:01', 'Logitech MX Keys'],
  ])

  inferUsbDeviceName(vendorId: number, productId: number): string {
    let key = `${vendorId.toString(16).toUpperCase().padStart(4, '0')}_${productId.toString(16).toUpperCase().padStart(4, '0')}`
    let name = PeripheralPage.USB_DEVICE_NAMES.get(key)
    if (name) {
      return name
    }
    return `USB 设备 (${formatUsbDeviceId(vendorId, productId)})`
  }

  private buildUsbDisplayName(manufacturerName?: string, productName?: string, vendorId?: number, productId?: number): string {
    let manufacturer = manufacturerName ? manufacturerName.trim() : ''
    let product = productName ? productName.trim() : ''
    if (manufacturer.length > 0 && product.length > 0) {
      return `${manufacturer} ${product}`
    }
    if (manufacturer.length > 0) {
      return manufacturer
    }
    if (product.length > 0) {
      return product
    }
    if (typeof vendorId === 'number' && typeof productId === 'number') {
      return this.inferUsbDeviceName(vendorId, productId)
    }
    return 'USB Device'
  }

  inferBluetoothDeviceName(mac: string): string {
    let name = PeripheralPage.BT_DEVICE_NAMES.get(mac)
    if (name) {
      return name
    }
    return `蓝牙设备 (${mac})`
  }

  loadDeviceControlData() {
    let records: DeviceControlRecord[] = []

    // 1. 从 USB 白名单加载（策略=允许）
    let usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
    for (let device of usbWhitelist) {
      records.push({
        deviceName: this.inferUsbDeviceName(device.vendorId, device.productId),
        deviceType: PeripheralType.USB_OTHER,
        deviceId: formatUsbDeviceId(device.vendorId, device.productId),
        connectTime: '--',
        policyIndex: 0
      })
    }

    // 2. 尝试从 USB 黑名单推断设备类型并更新已有记录
    let usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
    for (let deviceType of usbBlacklist) {
      // 更新匹配设备的类型
      for (let i = 0; i < records.length; i++) {
        if (records[i].deviceType === PeripheralType.USB_OTHER) {
          // 暂保留 USB_OTHER，后续可扩展
        }
      }
    }

    // 3. 从蓝牙白名单加载（策略=允许）
    let btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
    for (let mac of btWhitelist) {
      records.push({
        deviceName: this.inferBluetoothDeviceName(mac),
        deviceType: PeripheralType.BLUETOOTH,
        deviceId: `MAC: ${mac}`,
        connectTime: '--',
        policyIndex: 0
      })
    }

    this.deviceControlRecords = records
    hilog.info(0x0002, TAG, `loadDeviceControlData: ${records.length} devices loaded`)
  }

  private loadPeripheralPolicyData(): void {
    let whitelistKeys: Set<string> = new Set(
      this.usbWhitelist.map((device: edmUsbManager.UsbDeviceId) => {
        return formatUsbDeviceId(device.vendorId, device.productId).toUpperCase()
      })
    )
    let blacklistKeys: Set<string> = new Set(
      this.usbBlacklist.map((deviceType: edmUsbManager.UsbDeviceType) => {
        return `${deviceType.baseClass}|${deviceType.subClass}|${deviceType.protocol}`
      })
    )
    let items: Map<string, PeripheralPolicyRecord> = new Map()

    for (let record of this.deviceRecords) {
      if (this.usbRecordTypes.indexOf(record.deviceType) < 0) {
        continue
      }
      let parsed = parseUsbDeviceId(record.deviceId)
      if (!parsed) {
        continue
      }

      let deviceKey = formatUsbDeviceId(parsed.vendorId, parsed.productId).toUpperCase()
      let existing = items.get(deviceKey)
      if (existing && existing.lastSeenAt >= record.timestamp) {
        continue
      }

      let baseClass = inferUsbBaseClass(record.deviceType)
      let policyIndex = 0
      if (baseClass > 0 && blacklistKeys.has(`${baseClass}|0|0`)) {
        policyIndex = 1
      } else if (whitelistKeys.has(deviceKey)) {
        policyIndex = 0
      }

      items.set(deviceKey, {
        deviceName: record.deviceName,
        deviceType: record.deviceType,
        deviceId: record.deviceId,
        lastSeenAt: record.timestamp,
        lastSeenLabel: this.formatTimestamp(record.timestamp),
        policyIndex: policyIndex
      })
    }

    this.peripheralPolicyRecords = Array.from(items.values()).sort((left: PeripheralPolicyRecord, right: PeripheralPolicyRecord) => {
      return right.lastSeenAt - left.lastSeenAt
    })
  }

  private async exportPeripheralPolicyRecords(): Promise<void> {
    if (this.peripheralPolicyRecords.length === 0) {
      this.showResultDialog('failure', '暂无可导出的设备策略记录')
      return
    }

    try {
      let context = getContext(this) as common.UIAbilityContext
      await LogStorageService.init(context)
      let result = await LogStorageService.exportContentToFile(
        this.buildPeripheralPolicyCsv(this.peripheralPolicyRecords),
        LogExportFormat.CSV,
        'manual',
        {
          fileNamePrefix: 'peripheral_policy_list',
          count: this.peripheralPolicyRecords.length,
          emptyErrorMessage: '暂无可导出的设备策略记录'
        }
      )
      if (result.success) {
        this.showPolicyRecordExportSuccessDialog()
        return
      }
      this.showPolicyRecordExportFailureDialog(result.errorMessage)
    } catch (err) {
      hilog.error(0x0008, TAG, `exportPeripheralPolicyRecords failed: ${JSON.stringify(err)}`)
      this.showPolicyRecordExportFailureDialog()
    }
  }

  private buildPeripheralPolicyCsv(records: PeripheralPolicyRecord[]): string {
    let headers: string[] = [
      '设备名称',
      '设备类型',
      '设备标识',
      '最近连接时间',
      '当前策略'
    ]
    let rows = records.map((record: PeripheralPolicyRecord) => {
      return [
        record.deviceName,
        getPeripheralTypeLabel(record.deviceType),
        record.deviceId,
        record.lastSeenLabel,
        this.getPeripheralPolicyLabel(record.policyIndex)
      ].map((value: string) => this.escapeCsvValue(value)).join(',')
    })
    return `\﻿${headers.map((item: string) => this.escapeCsvValue(item)).join(',')}\n${rows.join('\n')}`
  }

  private getPeripheralPolicyLabel(policyIndex: number): string {
    let selected = this.policyListOptions[policyIndex]
    if (selected && typeof selected.value === 'string') {
      return selected.value
    }
    return this.policyListOptions[0].value as string
  }

  private refreshPeripheralPolicyRecords(): void {
    this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
    this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
    this.loadPeripheralPolicyData()
    this.peripheralPolicyRenderVersion += 1
  }

  private isPeripheralPolicyUpdating(deviceId: string): boolean {
    return this.policyUpdatingKeys.indexOf(deviceId) >= 0
  }

  private markPeripheralPolicyUpdating(deviceId: string, updating: boolean): void {
    if (updating) {
      if (!this.isPeripheralPolicyUpdating(deviceId)) {
        this.policyUpdatingKeys = [...this.policyUpdatingKeys, deviceId]
      }
      return
    }
    this.policyUpdatingKeys = this.policyUpdatingKeys.filter((item: string) => item !== deviceId)
  }

  private async handlePeripheralPolicyChange(recordIndex: number, policyIndex: number): Promise<void> {
    if (!this.ensureAdminReady('修改设备策略')) {
      return
    }
    let record = this.peripheralPolicyRecords[recordIndex]
    if (!record) {
      return
    }
    if (record.policyIndex === policyIndex) {
      return
    }
    if (this.isPeripheralPolicyUpdating(record.deviceId)) {
      return
    }
    let parsed = parseUsbDeviceId(record.deviceId)
    if (!parsed) {
      this.showResultDialog('failure', '无法识别当前设备标识')
      return
    }

    let device: edmUsbManager.UsbDeviceId = {
      vendorId: parsed.vendorId,
      productId: parsed.productId
    }
    let targetPolicy = policyIndex === 0 ?
      PeripheralService.USB_DEVICE_POLICY_ALLOW :
      PeripheralService.USB_DEVICE_POLICY_DENY
    this.markPeripheralPolicyUpdating(record.deviceId, true)
    try {
      hilog.info(
        0x0002,
        TAG,
        `peripheralPolicy update start, device=${record.deviceId}, target=${this.getPeripheralPolicyLabel(policyIndex)}`
      )
      let result = await this.runUsbOperationWithLoading(
        '正在更新 USB 设备策略，请稍候',
        (): OperationResult<void> => {
          let actionResult = PeripheralService.switchUsbDevicePolicyWithResult(device, record.deviceType, targetPolicy)
          this.refreshPeripheralPolicyRecords()
          if (actionResult.success) {
            this.reloadDeviceRecords()
          }
          return actionResult
        }
      )

      if (!result.success) {
        hilog.error(
          0x0002,
          TAG,
          `peripheralPolicy update failed, device=${record.deviceId}, target=${this.getPeripheralPolicyLabel(policyIndex)}, code=${result.errorCode ?? -1}, adminMissing=${result.isAdminMissing ? 1 : 0}`
        )
        let userMessage = result.userMessage?.trim()
        if (userMessage) {
          this.showResultDialog('failure', userMessage)
          return
        }
        this.showOperationFailure('修改设备策略', result)
        return
      }

      hilog.info(
        0x0002,
        TAG,
        `peripheralPolicy update success, device=${record.deviceId}, target=${this.getPeripheralPolicyLabel(policyIndex)}`
      )
    } finally {
      this.markPeripheralPolicyUpdating(record.deviceId, false)
    }
  }

  // ========== 接口管控操作 ==========

  async handleInterfaceToggle(feature: string, disallow: boolean): Promise<void> {
    if (!this.ensureAdminReady('接口管控')) {
      return
    }

    let controlKey: string = this.getInterfaceControlKey(feature)
    let targetValue: string = disallow ? 'disabled' : 'enabled'
    this.interfaceControlProcessingKey = controlKey
    hilog.info(0x0002, TAG, `interfaceControl update start, key=${controlKey}, target=${targetValue}`)
    try {
      let result: OperationResult<void>
      if (feature === PeripheralService.FEATURE_USB) {
        result = await this.runUsbOperationWithLoading(
          '正在切换 USB 接口策略，请稍候',
          (): OperationResult<void> => {
            let actionResult = PeripheralService.setInterfaceDisabledWithResult(feature, disallow)
            this.reloadInterfaceControlState(`toggle:${feature}`)
            return actionResult
          }
        )
      } else {
        result = PeripheralService.setInterfaceDisabledWithResult(feature, disallow)
        this.reloadInterfaceControlState(`toggle:${feature}`)
      }

      if (result.success) {
        hilog.info(0x0002, TAG, `interfaceControl update success, key=${controlKey}, target=${targetValue}`)
        let featureLabel = this.getInterfaceFeatureLabel(feature)
        hilog.info(0x0002, TAG, `${featureLabel}${disallow ? '已禁用' : '已启用'}`)
      } else {
        hilog.error(
          0x0002,
          TAG,
          `interfaceControl update failed, key=${controlKey}, target=${targetValue}, code=${result.errorCode ?? -1}, adminMissing=${result.isAdminMissing ? 1 : 0}`
        )
        this.showOperationFailure('接口管控', result)
      }
    } finally {
      this.interfaceControlProcessingKey = ''
    }
    return
  }

  private getInterfaceFeatureLabel(feature: string): string {
    if (feature === PeripheralService.FEATURE_USB) {
      return 'USB 接口'
    }
    if (feature === PeripheralService.FEATURE_BLUETOOTH) {
      return '蓝牙'
    }
    if (feature === PeripheralService.FEATURE_WIFI) {
      return 'Wi-Fi'
    }
    if (feature === PeripheralService.FEATURE_HDC) {
      return 'HDC 调试接口'
    }
    if (feature === PeripheralService.FEATURE_NETWORK) {
      return '网络'
    }
    if (feature === PeripheralService.FEATURE_PRINTER) {
      return '打印机'
    }
    if (feature === PeripheralService.FEATURE_MICROPHONE) {
      return '麦克风'
    }
    if (feature === PeripheralService.FEATURE_CAMERA) {
      return '摄像头'
    }
    return feature
  }

  async handleUsbStoragePolicyChange(index: number): Promise<void> {
    if (!this.ensureAdminReady('设置 USB 存储策略')) {
      return
    }
    let controlKey: string = this.usbStorageControlKey
    this.interfaceControlProcessingKey = controlKey
    hilog.info(
      0x0002,
      TAG,
      `usbStoragePolicy update start, key=${controlKey}, target=${this.getUsbStoragePolicyLogValue(index)}`
    )
    let policyMap: edmUsbManager.UsbPolicy[] = [
      edmUsbManager.UsbPolicy.READ_ONLY,
      edmUsbManager.UsbPolicy.READ_WRITE,
      edmUsbManager.UsbPolicy.DISABLED
    ]
    try {
      let result = await this.runUsbOperationWithLoading(
        '正在设置 USB 存储策略，请稍候',
        (): OperationResult<void> => {
          let actionResult = PeripheralService.setUsbStoragePolicyWithCleanupResult(policyMap[index])
          this.reloadInterfaceControlState('toggle:usb_storage_policy')
          return actionResult
        }
      )
      if (result.success) {
        hilog.info(
          0x0002,
          TAG,
          `usbStoragePolicy update success, key=${controlKey}, target=${this.getUsbStoragePolicyLogValue(index)}`
        )
        return
      }
      hilog.error(
        0x0002,
        TAG,
        `usbStoragePolicy update failed, key=${controlKey}, target=${this.getUsbStoragePolicyLogValue(index)}, code=${result.errorCode ?? -1}, adminMissing=${result.isAdminMissing ? 1 : 0}`
      )
      this.showOperationFailure('设置 USB 存储策略', result)
    } finally {
      this.interfaceControlProcessingKey = ''
    }
  }

  // ========== 白名单操作 ==========

  handleAddUsbWhitelist(vendorId: number, productId: number) {
    if (!this.ensureAdminReady('添加 USB 白名单')) {
      return
    }
    let device: edmUsbManager.UsbDeviceId = { vendorId: vendorId, productId: productId }
    let result = PeripheralService.addUsbWhitelistWithResult([device])
    if (result.success) {
      this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.reloadDeviceRecords()
      hilog.info(0x0002, TAG, 'USB 白名单已添加')
    } else {
      this.showOperationFailure('添加 USB 白名单', result)
    }
  }

  handleRemoveUsbWhitelist(device: edmUsbManager.UsbDeviceId) {
    if (!this.ensureAdminReady('移除 USB 白名单')) {
      return
    }
    let result = PeripheralService.removeUsbWhitelistWithResult([device])
    if (result.success) {
      this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.reloadDeviceRecords()
      hilog.info(0x0002, TAG, 'USB 白名单项已移除')
      return
    }
    this.showOperationFailure('移除 USB 白名单', result)
  }

  handleAddBluetoothWhitelist(mac: string) {
    if (!this.ensureAdminReady('添加蓝牙白名单')) {
      return
    }
    let result = PeripheralService.addBluetoothWhitelistWithResult([mac])
    if (result.success) {
      this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
      this.reloadDeviceRecords()
      hilog.info(0x0002, TAG, '蓝牙白名单已添加')
    } else {
      this.showOperationFailure('添加蓝牙白名单', result)
    }
  }

  handleRemoveBluetoothWhitelist(mac: string) {
    if (!this.ensureAdminReady('移除蓝牙白名单')) {
      return
    }
    let result = PeripheralService.removeBluetoothWhitelistWithResult([mac])
    if (result.success) {
      this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
      this.reloadDeviceRecords()
      hilog.info(0x0002, TAG, '蓝牙白名单项已移除')
      return
    }
    this.showOperationFailure('移除蓝牙白名单', result)
  }

  // ========== 黑名单操作 ==========

  handleAddUsbBlacklist(baseClass: number, subClass: number, protocol: number) {
    if (!this.ensureAdminReady('添加 USB 黑名单')) {
      return
    }
    let deviceType: edmUsbManager.UsbDeviceType = {
      baseClass: baseClass,
      subClass: subClass,
      protocol: protocol,
      descriptor: edmUsbManager.Descriptor.INTERFACE
    }
    let result = PeripheralService.addUsbBlacklistWithResult([deviceType])
    if (result.success) {
      this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.reloadDeviceRecords()
      hilog.info(0x0002, TAG, 'USB 黑名单已添加')
    } else {
      this.showOperationFailure('添加 USB 黑名单', result)
    }
  }

  handleRemoveUsbBlacklist(deviceType: edmUsbManager.UsbDeviceType) {
    if (!this.ensureAdminReady('移除 USB 黑名单')) {
      return
    }
    let result = PeripheralService.removeUsbBlacklistWithResult([deviceType])
    if (result.success) {
      this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.reloadDeviceRecords()
      hilog.info(0x0002, TAG, 'USB 黑名单项已移除')
      return
    }
    this.showOperationFailure('移除 USB 黑名单', result)
  }

  // ========== 设备管控操作 ==========

  handleDeviceControlPolicyChange(recordIndex: number, policyIndex: number) {
    if (!this.ensureAdminReady('修改设备管控策略')) {
      return
    }
    let record = this.deviceControlRecords[recordIndex]
    let success = false
    let failedResult: OperationResult<PeripheralResultData> | undefined = undefined
    let policyLabels: string[] = ['允许', '禁止', '未配置']

    if (record.deviceType === PeripheralType.BLUETOOTH) {
      // 蓝牙设备策略变更
      let mac = parseBluetoothMac(record.deviceId)
      if (!mac) {
        hilog.error(0x0002, TAG, `parseBluetoothMac failed: ${record.deviceId}`)
        return
      }
      if (policyIndex === 0) {
        let result = PeripheralService.addBluetoothWhitelistWithResult([mac])
        success = result.success
        if (!result.success) {
          failedResult = result
        }
      } else {
        let result = PeripheralService.removeBluetoothWhitelistWithResult([mac])
        success = result.success
        if (!result.success) {
          failedResult = result
        }
      }
    } else {
      // USB 设备策略变更
      let parsed = parseUsbDeviceId(record.deviceId)
      if (!parsed) {
        hilog.error(0x0002, TAG, `parseUsbDeviceId failed: ${record.deviceId}`)
        return
      }
      let device: edmUsbManager.UsbDeviceId = {
        vendorId: parsed.vendorId,
        productId: parsed.productId
      }
      if (policyIndex === 0) {
        // 允许：加入白名单
        let result = PeripheralService.addUsbWhitelistWithResult([device])
        success = result.success
        if (!result.success) {
          failedResult = result
        }
      } else if (policyIndex === 1) {
        // 禁用：从白名单移除 + 按类型加入黑名单
        let removeResult = PeripheralService.removeUsbWhitelistWithResult([device])
        if (!removeResult.success) {
          failedResult = removeResult
        }
        let baseClass = inferUsbBaseClass(record.deviceType)
        if (baseClass > 0) {
          let deviceType: edmUsbManager.UsbDeviceType = {
            baseClass: baseClass,
            subClass: 0,
            protocol: 0,
            descriptor: edmUsbManager.Descriptor.INTERFACE
          }
          let addBlackResult = PeripheralService.addUsbBlacklistWithResult([deviceType])
          if (!addBlackResult.success) {
            failedResult = addBlackResult
          }
        }
        success = failedResult === undefined
      } else {
        // 未配置：从白名单移除
        let result = PeripheralService.removeUsbWhitelistWithResult([device])
        success = result.success
        if (!result.success) {
          failedResult = result
        }
      }
    }

    if (success) {
      // 重新从 MDM API 加载设备列表
      this.loadDeviceControlData()
      // 同步刷新黑白名单 tab 数据
      this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
      this.reloadDeviceRecords()
      try {
        hilog.info(0x0002, TAG, `${record.deviceName} 策略已设置为${policyLabels[policyIndex]}`)
      } catch (e) {
        hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
      }
    } else {
      this.showOperationFailure('修改设备管控策略', failedResult || {
        success: false,
        errorMessage: '修改设备策略失败'
      } as OperationResult<PeripheralResultData>)
    }
  }

  // ========== Tab Builder ==========

  @Builder
  tabBuilder(title: string, index: number) {
    Text(title)
      .fontSize(AppStyles.FONT_SIZE_BODY)
      .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.currentTab === index ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
      .opacity(this.currentTab === index ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  formatHex(num: number): string {
    return '0x' + num.toString(16).toUpperCase().padStart(2, '0')
  }

  // ========== Build ==========

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
      // 页面头部
      Row() {
        Row({ space: 8 }) {
          BackNavButton({
            onBack: () => {
              this.onBack()
            }
          })

          Column({ space: 4 }) {
            Text('外设管理')
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            Text('管控 USB、蓝牙、Wi-Fi 等外设接口，配置设备黑白名单策略')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top)

        if (this.currentTab === 1) {
          this.pageHeaderActions()
        } else if (this.currentTab === 2) {
          this.policyListHeaderActions()
        }
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_LG })

      // Tab 切换
      Tabs({ barPosition: BarPosition.Start }) {
        TabContent() {
          this.interfaceControlBuilder()
        }.tabBar(this.tabBuilder('接口管控', 0))

        TabContent() {
          this.deviceRecordsBuilder()
        }.tabBar(this.tabBuilder('设备连接记录', 1))

        TabContent() {
          this.peripheralPolicyListBuilder()
        }.tabBar(this.tabBuilder('黑白名单', 2))
      }
      .barMode(BarMode.Fixed)
      .barWidth('100%')
      .onChange((index: number) => {
        this.currentTab = index
        if (index === 2) {
          this.loadConnectedUsbDevices()
        }
      })
      .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)

      if (this.isConnectionDetailDialogVisible) {
        this.connectionRecordDetailDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ==================== Tab 1: 设备连接记录 ====================
  private openConnectionDetailDialog(record: PeripheralConnectionRecord): void {
    let historyCount = this.getConnectionHistoryItems(record).length
    hilog.info(
      0x0002,
      TAG,
      `openConnectionDetailDialog type=${record.deviceType}, action=${record.action}, source=${record.source}, result=${this.getConnectionResultLabel(record)}, historyCount=${historyCount}`
    )
    this.selectedConnectionRecord = record
    this.isConnectionDetailDialogVisible = true
  }

  private closeConnectionDetailDialog(): void {
    if (this.selectedConnectionRecord) {
      hilog.info(
        0x0002,
        TAG,
        `closeConnectionDetailDialog type=${this.selectedConnectionRecord.deviceType}, action=${this.selectedConnectionRecord.action}, source=${this.selectedConnectionRecord.source}`
      )
    } else {
      hilog.info(0x0002, TAG, 'closeConnectionDetailDialog without active record')
    }
    this.isConnectionDetailDialogVisible = false
    this.selectedConnectionRecord = null
  }

  private async exportConnectionHistory(): Promise<void> {
    if (this.deviceRecords.length === 0) {
      this.showResultDialog('failure', '没有可导出的设备连接记录')
      return
    }

    try {
      hilog.info(0x0008, TAG, `exportConnectionHistory start, count=${this.deviceRecords.length}`)
      let context = getContext(this) as common.UIAbilityContext
      await LogStorageService.init(context)
      let exportOptions: LogContentExportOptions = {
        fileNamePrefix: 'peripheral_connection_history',
        count: this.deviceRecords.length,
        emptyErrorMessage: '无可导出的设备连接记录'
      }
      let result = await LogStorageService.exportContentToFile(
        this.buildConnectionHistoryCsvV2(this.deviceRecords),
        LogExportFormat.CSV,
        'manual',
        exportOptions
      )
      hilog.info(0x0008, TAG, `exportConnectionHistory result=${JSON.stringify(result)}`)
      if (result.success) {
        this.showConnectionHistoryExportSuccessDialog()
        return
      }
      this.showConnectionHistoryExportFailureDialog(result.errorMessage)
    } catch (err) {
      hilog.error(0x0008, TAG, `exportConnectionHistory failed: ${JSON.stringify(err)}`)
      this.showConnectionHistoryExportFailureDialog()
      return
      this.showResultDialog('failure', '导出历史记录失败，请稍后重试')
    }
  }

  private showClearConnectionHistoryConfirmDialog(): void {
    if (this.deviceRecords.length === 0) {
      this.showResultDialog('failure', '暂无可清理的历史记录')
      return
    }

    void this.getUIContext().showAlertDialog({
      title: '清理历史记录',
      message: '将清空当前设备连接历史记录，且无法恢复。是否继续？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清理',
        action: () => {
          void this.clearConnectionHistory()
        }
      }
    })
  }

  private async clearConnectionHistory(): Promise<void> {
    try {
      let context = getContext(this) as common.UIAbilityContext
      await PeripheralTraceRepository.init(context)
      let success = await PeripheralTraceRepository.clearAll()
      if (!success) {
        this.showResultDialog('failure', '清理未完成，请稍后重试')
        return
      }
      this.closeConnectionDetailDialog()
      this.recordHintMessage = ''
      this.lastRecordHintToastMessage = ''
      this.reloadDeviceRecords()
      this.showResultDialog('success', '历史记录已清理')
    } catch (err) {
      hilog.error(0x0008, TAG, `clearConnectionHistory failed: ${JSON.stringify(err)}`)
      this.showResultDialog('failure', '清理未完成，请稍后重试')
    }
  }

  private buildConnectionHistoryCsvV2(records: PeripheralConnectionRecord[]): string {
    let headers: string[] = [
      '设备名称',
      '设备类型',
      '设备标识',
      '连接事件',
      '策略',
      '连接时间',
      '事件来源',
      '命中类型',
      '结果状态'
    ]
    let rows = records.map((record: PeripheralConnectionRecord) => {
      return [
        record.deviceName,
        getPeripheralTypeLabel(record.deviceType),
        record.deviceId,
        this.getConnectionEventLabel(record),
        this.getExecutedUsbPolicyDisplay(record),
        this.formatConnectionTime(record),
        getPeripheralRecordSourceLabel(record.source),
        this.getMatchedPolicyKindLabel(record),
        this.getConnectionResultLabel(record)
      ].map((value: string) => this.escapeCsvValue(value)).join(',')
    })
    return `\﻿${headers.map((item: string) => this.escapeCsvValue(item)).join(',')}\n${rows.join('\n')}`
  }

  private escapeCsvValue(value: string): string {
    let normalized = value.replace(/"/g, '""')
    if (/[",\r\n]/.test(normalized)) {
      return `"${normalized}"`
    }
    return normalized
  }

  private showConnectionHistoryExportSuccessDialog(): void {
    this.showResultDialog('success', '历史记录已导出，保存位置：下载/安全管理中心')
  }

  private showConnectionHistoryExportFailureDialog(reason?: string): void {
    this.showResultDialog(
      'failure',
      `历史记录导出失败，${ResultDialogHelper.displayReason(reason, '请稍后重试')}`
    )
  }

  private showPolicyRecordExportSuccessDialog(): void {
    this.showResultDialog('success', '策略记录已导出，保存位置：下载/安全管理中心')
  }

  private showPolicyRecordExportFailureDialog(reason?: string): void {
    this.showResultDialog(
      'failure',
      `策略记录导出失败，${ResultDialogHelper.displayReason(reason, '请稍后重试')}`
    )
  }

  private getConnectionEventLabel(record: PeripheralConnectionRecord | null): string {
    if (!record) {
      return '--'
    }
    return getPeripheralRecordActionLabel(record.action)
  }

  private getConnectionEventTagTextColor(action: PeripheralRecordAction): string {
    let colors = AppColors.getColors(this.currentTheme)
    switch (action) {
      case 'connect':
        return colors.TAG_GREEN_TEXT
      case 'disconnect':
        return colors.TAG_ORANGE_TEXT
      case 'intercept':
        return colors.TAG_RED_TEXT
      default:
        return colors.TAG_GRAY_TEXT
    }
  }

  private getConnectionEventTagBackgroundColor(action: PeripheralRecordAction): string {
    let colors = AppColors.getColors(this.currentTheme)
    switch (action) {
      case 'connect':
        return colors.TAG_GREEN_BG
      case 'disconnect':
        return colors.TAG_ORANGE_BG
      case 'intercept':
        return colors.TAG_RED_BG
      default:
        return colors.TAG_GRAY_BG
    }
  }

  private getConnectionPolicyDisplay(record: PeripheralConnectionRecord | null): string {
    if (!record) {
      return '--'
    }
    if (record.summary && record.summary.trim().length > 0) {
      return record.summary
    }
    return this.getConnectionPolicyHitLabel(record)
  }

  private getExecutedUsbPolicyDisplay(record: PeripheralConnectionRecord | null): string {
    if (!record) {
      return '--'
    }
    if (record.effectivePolicyLabel && record.effectivePolicyLabel.trim().length > 0) {
      return record.effectivePolicyLabel
    }
    if (record.deviceType === PeripheralType.USB_STORAGE && record.usbPolicy !== undefined) {
      return getUsbStoragePolicyLabel(record.usbPolicy)
    }
    if (record.deviceType === PeripheralType.BLUETOOTH) {
      return '--'
    }
    return this.usbDisabled ? '禁用' : '启用'
  }

  private getMatchedPolicyKindLabel(record: PeripheralConnectionRecord): string {
    switch (record.matchedPolicyKind as PeripheralMatchedPolicyKind | undefined) {
      case 'usb_disabled':
        return 'USB 接口禁用'
      case 'usb_storage_disabled':
        return 'USB 存储已禁止访问'
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
        return this.getConnectionPolicyHitLabel(record)
    }
  }

  private getConnectionHistoryItems(record: PeripheralConnectionRecord | null): ConnectionHistoryItem[] {
    if (!record) {
      return []
    }
    let deviceKey = record.deviceId.replace(/\s+/g, '').toUpperCase()
    let history: ConnectionHistoryItem[] = []
    for (let item of this.deviceRecords) {
      if (item.timestamp <= 0) {
        continue
      }
      if (item.deviceId.replace(/\s+/g, '').toUpperCase() !== deviceKey) {
        continue
      }
      let historyItem: ConnectionHistoryItem = {
        time: this.formatConnectionTime(item),
        policy: this.getConnectionPolicyHitLabel(item),
        result: this.getConnectionResultLabel(item)
      }
      if (!history.some((existing: ConnectionHistoryItem) => {
        return existing.time === historyItem.time &&
          existing.policy === historyItem.policy &&
          existing.result === historyItem.result
      })) {
        history.push(historyItem)
      }
    }
    return history
  }

  private normalizeConnectionDetailValue(value?: string): string {
    if (!value) {
      return '--'
    }
    let normalized = value.trim()
    return normalized.length > 0 ? normalized : '--'
  }

  private isCompactConnectionDetailDialog(): boolean {
    return this.connectionDetailHostWidth > 0 && this.connectionDetailHostWidth < this.connectionDetailCompactWidthThreshold
  }

  private getConnectionDetailDialogMaxWidth(): number {
    return this.isCompactConnectionDetailDialog() ? 620 : 760
  }

  private getConnectionDetailDialogMaxHeight(): number {
    return this.isCompactConnectionDetailDialog() ? 470 : 560
  }

  private getConnectionDetailDialogContentMaxHeight(): number {
    return this.isCompactConnectionDetailDialog() ? 372 : 452
  }

  private getConnectionDetailHistoryMaxHeight(): number {
    return this.isCompactConnectionDetailDialog() ? 108 : 136
  }

  @Builder
  private connectionDetailMetricField(label: string, value: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      Text(value)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private connectionTableHeader() {
    Row({ space: 12 }) {
      Text('设备名称')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(2.1)
      Text('设备类型')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.2)
      Text('连接事件')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.1)
      Text('策略')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.8)
      Text('连接时间')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1.6)
      Text('操作')
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(0.9)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 14 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private connectionRecordTableRow(record: PeripheralConnectionRecord, index: number) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(record.deviceName)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(record.deviceId)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(2.1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text(getPeripheralTypeLabel(record.deviceType))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .layoutWeight(1.2)

      Row() {
        Text(this.getConnectionEventLabel(record))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(this.getConnectionEventTagTextColor(record.action))
          .backgroundColor(this.getConnectionEventTagBackgroundColor(record.action))
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .layoutWeight(1.1)

      Row() {
        Text(this.getExecutedUsbPolicyDisplay(record))
          .fontSize(AppStyles.FONT_SIZE_SMALL)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1.8)

      Text(this.formatConnectionTime(record))
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .layoutWeight(1.6)

      Button('详情')
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(Color.White)
        .backgroundColor(AppColors.BRAND_PRIMARY)
        .borderRadius(AppStyles.RADIUS_MD)
        .height(32)
        .layoutWeight(0.9)
        .onClick(() => {
          this.openConnectionDetailDialog(record)
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .translate({ y: HoverUtils.getTranslateY(this.hoveredDeviceRecordIndex === index, 2) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredDeviceRecordIndex = isHover ? index : -1
      })
    })
  }

  @Builder
  private pageHeaderActions() {
    Row({ space: 8 }) {
      Button() {
        Row({ space: 6 }) {
          Image($r('app.media.save'))
            .width(14)
            .height(14)
            .fillColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)

          Text('导出历史记录')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
        }
        .alignItems(VerticalAlign.Center)
      }
      .type(ButtonType.Normal)
      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
      .borderRadius(AppStyles.RADIUS_SM)
      .height(32)
      .padding({ left: 10, right: 10 })
      .onClick(() => {
        void this.exportConnectionHistory()
      })

      Button() {
        Row({ space: 6 }) {
          Image($r('app.media.trash'))
            .width(14)
            .height(14)
            .fillColor(AppColors.getColors(this.currentTheme).TAG_RED_TEXT)

          Text('清理历史记录')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
        }
        .alignItems(VerticalAlign.Center)
      }
      .type(ButtonType.Normal)
      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG)
      .borderRadius(AppStyles.RADIUS_SM)
      .height(32)
      .padding({ left: 10, right: 10 })
      .onClick(() => {
        this.showClearConnectionHistoryConfirmDialog()
      })
    }
  }

  @Builder
  private policyListHeaderActions() {
    Row({ space: 8 }) {
      Button() {
        Row({ space: 6 }) {
          Image($r('app.media.save'))
            .width(14)
            .height(14)
            .fillColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)

          Text('导出策略记录')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
        }
        .alignItems(VerticalAlign.Center)
      }
      .type(ButtonType.Normal)
      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
      .borderRadius(AppStyles.RADIUS_SM)
      .height(32)
      .padding({ left: 10, right: 10 })
      .onClick(() => {
        void this.exportPeripheralPolicyRecords()
      })
    }
  }

  @Builder
  private connectionRecordDetailDialog() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#66000000')
      .onClick(() => {
        this.closeConnectionDetailDialog()
      })

      Column({ space: 8 }) {
        Row() {
          Text('设备详情')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          Blank()
          Button('关闭')
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
            .borderRadius(AppStyles.RADIUS_MD)
            .height(32)
            .onClick(() => {
              this.closeConnectionDetailDialog()
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (!this.selectedConnectionRecord) {
          Column({ space: 8 }) {
            Text('当前没有可展示的连接记录。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .width('100%')
        } else {
          Scroll() {
            Column({ space: 8 }) {
              Column({ space: 8 }) {
                Text('关键信息')
                  .fontSize(AppStyles.FONT_SIZE_BODY)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)

                Column({ space: 8 }) {
                  Row({ space: 12 }) {
                    this.connectionDetailMetricField('设备标识', this.normalizeConnectionDetailValue((this.selectedConnectionRecord as PeripheralConnectionRecord).deviceId))
                    this.connectionDetailMetricField('最近时间', this.formatConnectionTime(this.selectedConnectionRecord as PeripheralConnectionRecord))
                  }
                  .width('100%')

                  Row({ space: 12 }) {
                    this.connectionDetailMetricField('连接事件', this.getConnectionEventLabel(this.selectedConnectionRecord))
                    this.connectionDetailMetricField('事件来源', getPeripheralRecordSourceLabel((this.selectedConnectionRecord as PeripheralConnectionRecord).source))
                  }
                  .width('100%')

                  Row({ space: 12 }) {
                    this.connectionDetailMetricField('策略结论', this.getConnectionPolicyDisplay(this.selectedConnectionRecord))
                    this.connectionDetailMetricField('实际执行策略', this.getExecutedUsbPolicyDisplay(this.selectedConnectionRecord))
                  }
                  .width('100%')

                  Row({ space: 12 }) {
                    this.connectionDetailMetricField('命中类型', this.getConnectionPolicyHitLabel(this.selectedConnectionRecord as PeripheralConnectionRecord))
                    this.connectionDetailMetricField('结果状态', this.getConnectionResultLabel(this.selectedConnectionRecord as PeripheralConnectionRecord))
                  }
                  .width('100%')
                }
                .width('100%')
              }
              .width('100%')
              .padding(12)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
              .borderRadius(AppStyles.RADIUS_LG)

              Column({ space: 8 }) {
                Row() {
                  Text('历史连接记录')
                    .fontSize(AppStyles.FONT_SIZE_BODY)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  Blank()
                  Text(`${this.getConnectionHistoryItems(this.selectedConnectionRecord).length} 条`)
                    .fontSize(AppStyles.FONT_SIZE_CAPTION)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
                }
                .width('100%')

                if (this.getConnectionHistoryItems(this.selectedConnectionRecord).length === 0) {
                  Text('暂无历史连接记录')
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
                } else {
                  Scroll() {
                    Column({ space: 10 }) {
                      ForEach(this.getConnectionHistoryItems(this.selectedConnectionRecord), (item: ConnectionHistoryItem, index: number) => {
                        Row({ space: 12 }) {
                          Stack({ alignContent: Alignment.Center }) {
                            Text(`${index + 1}`)
                              .fontSize(AppStyles.FONT_SIZE_CAPTION)
                              .fontWeight(FontWeight.Medium)
                              .fontColor(AppColors.BRAND_PRIMARY)
                          }
                          .width(28)
                          .height(28)
                          .borderRadius(14)
                          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)

                          Column({ space: 4 }) {
                            Text(item.time)
                              .fontSize(AppStyles.FONT_SIZE_SMALL)
                              .fontWeight(FontWeight.Medium)
                              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                            Text(`${item.policy} · ${item.result}`)
                              .fontSize(AppStyles.FONT_SIZE_CAPTION)
                              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                              .maxLines(2)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                          }
                          .layoutWeight(1)
                          .alignItems(HorizontalAlign.Start)
                        }
                        .width('100%')
                        .padding(10)
                        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
                        .borderRadius(AppStyles.RADIUS_MD)
                      })
                    }
                    .width('100%')
                  }
                  .width('100%')
                  .constraintSize({ maxHeight: this.getConnectionDetailHistoryMaxHeight() })
                  .scrollBar(BarState.Auto)
                }
              }
              .width('100%')
              .padding(12)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
              .borderRadius(AppStyles.RADIUS_LG)
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: this.getConnectionDetailDialogContentMaxHeight() })
          .scrollBar(BarState.Auto)
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: this.getConnectionDetailDialogMaxWidth(), maxHeight: this.getConnectionDetailDialogMaxHeight() })
      .padding(16)
      .margin({ left: 16, right: 16, top: 16, bottom: 16 })
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
      .borderRadius(AppStyles.RADIUS_XL)
      .shadow(HoverUtils.getShadow(this.currentTheme, true, true))
      .onClick(() => {
      })
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldValue, newValue) => {
      let nextWidth = Number(newValue.width)
      if (nextWidth > 0 && nextWidth !== this.connectionDetailHostWidth) {
        this.connectionDetailHostWidth = nextWidth
      }
    })
  }

  private getDeviceRecordPolicyTextColor(policy: string | undefined): string {
    return policy === '允许'
      ? AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
      : AppColors.getColors(this.currentTheme).TAG_RED_TEXT
  }

  private getDeviceRecordPolicyBgColor(policy: string | undefined): string {
    return policy === '允许'
      ? AppColors.getColors(this.currentTheme).TAG_GREEN_BG
      : AppColors.getColors(this.currentTheme).TAG_RED_BG
  }

  private getDeviceRecordPolicySummary(policy: string | undefined): string {
    return policy === '允许' ? '已按当前接口策略放行' : '已被当前接口策略拦截'
  }

  @Builder
  deviceRecordItem(record: DeviceRecord, index: number) {
    Row({ space: 16 }) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(record.deviceName)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(getPeripheralTypeLabel(record.deviceType))
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
            .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
            .borderRadius(AppStyles.RADIUS_SM)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }

        Text(record.deviceId)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 20 }) {
          Column({ space: 4 }) {
            Text('连接时间')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            Text(record.connectTime)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('策略结果')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            Text(this.getDeviceRecordPolicySummary(record.policy))
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text(record.policy)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getDeviceRecordPolicyTextColor(record.policy))
          .backgroundColor(this.getDeviceRecordPolicyBgColor(record.policy))
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })

        Text(record.policy === '允许' ? '命中白名单 / 默认放行' : '命中限制规则')
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .textAlign(TextAlign.End)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .translate({ y: HoverUtils.getTranslateY(this.hoveredDeviceRecordIndex === index, 2) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredDeviceRecordIndex = isHover ? index : -1
      })
    })
  }

  @Builder
  deviceRecordsPanel() {
    Scroll() {
      Column({ space: 0 }) {
        Column({ space: 0 }) {
          if (this.deviceRecords.length === 0) {
            Column({ space: 10 }) {
              Text('暂无设备连接记录')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

              Text('请连接 USB 或蓝牙设备以生成记录。')
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 42, bottom: 42 })
            .alignItems(HorizontalAlign.Center)
          } else {
            Column({ space: 0 }) {
              ForEach(this.deviceRecords, (record: DeviceRecord, index: number) => {
                Column({ space: 0 }) {
                  this.deviceRecordItem(record, index)
                  if (index < this.deviceRecords.length - 1) {
                    Divider()
                      .color(AppColors.getColors(this.currentTheme).BORDER)
                      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                      .margin({ left: 20, right: 20 })
                  }
                }
              })
            }
            .width('100%')
          }
        }
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 0, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 0, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 0 : -1
          })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  private getConnectionRuntimeCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => record.source === 'runtime_event').length
  }

  private getConnectionAuditCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => record.source === 'audit_event').length
  }

  private getConnectionSnapshotCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => record.source === 'policy_snapshot').length
  }

  private getConnectionConnectCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => {
      return record.source !== 'policy_snapshot' && record.action === 'connect'
    }).length
  }

  private getConnectionDisconnectCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => {
      return record.source !== 'policy_snapshot' && record.action === 'disconnect'
    }).length
  }

  private getConnectionInterceptCount(): number {
    return this.deviceRecords.filter((record: PeripheralConnectionRecord) => {
      return record.source !== 'policy_snapshot' && record.action === 'intercept'
    }).length
  }

  private getConnectionTypeFilterLabel(): string {
    let option = this.recordTypeFilterOptions[this.recordFilterTypeIndex]
    return option ? option.value as string : this.recordTypeFilterOptions[0].value as string
  }

  private getConnectionResultFilterLabel(): string {
    let option = this.recordResultFilterOptions[this.recordFilterResultIndex]
    return option ? option.value as string : this.recordResultFilterOptions[0].value as string
  }

  private getConnectionSourceFilterLabel(): string {
    let option = this.recordSourceFilterOptions[this.recordFilterSourceIndex]
    return option ? option.value as string : this.recordSourceFilterOptions[0].value as string
  }

  private getConnectionResultLabel(record: PeripheralConnectionRecord): string {
    if (record.source === 'policy_snapshot') {
      return '快照'
    }
    return getLogEventResultLabel(record.result)
  }

  private getConnectionResultTextColor(record: PeripheralConnectionRecord): string {
    if (record.source === 'policy_snapshot') {
      return AppColors.getColors(this.currentTheme).TAG_GRAY_TEXT
    }
    if (record.result === LogEventResult.SUCCESS) {
      return AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
    }
    if (record.result === LogEventResult.BLOCKED) {
      return AppColors.getColors(this.currentTheme).TAG_RED_TEXT
    }
    return AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT
  }

  private getConnectionResultBgColor(record: PeripheralConnectionRecord): string {
    if (record.source === 'policy_snapshot') {
      return AppColors.getColors(this.currentTheme).TAG_GRAY_BG
    }
    if (record.result === LogEventResult.SUCCESS) {
      return AppColors.getColors(this.currentTheme).TAG_GREEN_BG
    }
    if (record.result === LogEventResult.BLOCKED) {
      return AppColors.getColors(this.currentTheme).TAG_RED_BG
    }
    return AppColors.getColors(this.currentTheme).TAG_ORANGE_BG
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

  private formatConnectionTime(record: PeripheralConnectionRecord): string {
    if (record.timestamp <= 0) {
      return '--'
    }
    return formatLogTimestamp(record.timestamp)
  }

  @Builder
  private connectionStatItem(title: string, value: string, valueColor: string) {
    Column({ space: 4 }) {
      Text(title)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      Text(value)
        .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
        .fontWeight(FontWeight.Medium)
        .fontColor(valueColor)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_MD)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private connectionRecordFilterToolbar() {
    Row({ space: 8 }) {
      Select(this.recordTypeFilterOptions)
        .selected(this.recordFilterTypeIndex)
        .value(this.getConnectionTypeFilterLabel())
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
        .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(120)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => {
          this.recordFilterTypeIndex = index
          this.reloadDeviceRecords()
        })

      Select(this.recordResultFilterOptions)
        .selected(this.recordFilterResultIndex)
        .value(this.getConnectionResultFilterLabel())
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
        .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(120)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => {
          this.recordFilterResultIndex = index
          this.reloadDeviceRecords()
        })

      Select(this.recordSourceFilterOptions)
        .selected(this.recordFilterSourceIndex)
        .value(this.getConnectionSourceFilterLabel())
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
        .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(140)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => {
          this.recordFilterSourceIndex = index
          this.reloadDeviceRecords()
        })

      TextInput({ placeholder: '按关键字或设备 ID 过滤', text: this.recordFilterKeyword })
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(FormControlUtils.text(this.currentTheme))
        .placeholderColor(FormControlUtils.placeholder(this.currentTheme))
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.recordFilterKeyword = value
          this.reloadDeviceRecords()
        })

      Button('刷新')
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .onClick(() => {
          this.reloadDeviceRecords()
        })
    }
    .width('100%')
    .padding({
      left: AppStyles.PADDING_LG,
      right: AppStyles.PADDING_LG,
      top: AppStyles.PADDING_SM
    })
  }
  @Builder
  connectionRecordItem(record: PeripheralConnectionRecord, index: number) {
    Row({ space: 16 }) {
      Column({ space: 8 }) {
        Row({ space: 8 }) {
          Text(record.deviceName)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(getPeripheralTypeLabel(record.deviceType))
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
            .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
            .borderRadius(AppStyles.RADIUS_SM)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }

        Text(record.deviceId)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row({ space: 8 }) {
          Text(getPeripheralRecordSourceLabel(record.source))
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT)
            .backgroundColor(AppColors.getColors(this.currentTheme).TAG_BLUE_BG)
            .borderRadius(AppStyles.RADIUS_SM)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })

          Text(getPeripheralRecordActionLabel(record.action))
            .fontSize(AppStyles.FONT_SIZE_CAPTION)
            .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
            .backgroundColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_BG)
            .borderRadius(AppStyles.RADIUS_SM)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }

        Row({ space: 20 }) {
          Column({ space: 4 }) {
            Text('连接时间')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            Text(this.formatConnectionTime(record))
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('策略说明')
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            Text(record.summary)
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text(this.getConnectionResultLabel(record))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getConnectionResultTextColor(record))
          .backgroundColor(this.getConnectionResultBgColor(record))
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })

        Text(this.getConnectionPolicyHitLabel(record))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .textAlign(TextAlign.End)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .translate({ y: HoverUtils.getTranslateY(this.hoveredDeviceRecordIndex === index, 2) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredDeviceRecordIndex = isHover ? index : -1
      })
    })
  }

  @Builder
  private connectionRecordsPanel() {
    Scroll() {
      Column({ space: 0 }) {
        Column({ space: 0 }) {
          if (this.deviceRecords.length === 0) {
            Column({ space: 10 }) {
              Text('暂无设备连接记录')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)

              Text('暂无实时记录，请重新插拔设备后刷新。')
                .fontSize(AppStyles.FONT_SIZE_CAPTION)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 42, bottom: 42 })
            .alignItems(HorizontalAlign.Center)
          } else {
            Column({ space: 0 }) {
              this.connectionTableHeader()
              Column({ space: 0 }) {
                ForEach(this.deviceRecords, (record: PeripheralConnectionRecord, index: number) => {
                  Column({ space: 0 }) {
                    this.connectionRecordTableRow(record, index)
                    if (index < this.deviceRecords.length - 1) {
                      Divider()
                        .color(AppColors.getColors(this.currentTheme).BORDER)
                        .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                        .margin({ left: 20, right: 20 })
                    }
                  }
                })
              }
              .width('100%')
            }
            .width('100%')
          }
        }
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 0, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 0, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 0 : -1
          })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_MD,
        bottom: AppStyles.PADDING_MD
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  @Builder
  deviceRecordsBuilder() {
    if (true) {
      this.connectionRecordsPanel()
    } else {
      /*
      Column() {
      if (this.deviceRecords.length === 0) {
        Column({ space: 12 }) {
          Text('暂无设备连接记录')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius({ bottomLeft: AppStyles.RADIUS_LG, bottomRight: AppStyles.RADIUS_LG })
      } else {
        // 表头
        Row() {
          Text('设备名称').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('设备类型').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1.5)
          Text('设备标识').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('连接时间').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('策略').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
        .borderRadius({ topLeft: AppStyles.RADIUS_LG, topRight: AppStyles.RADIUS_LG })

        // 数据列表
        List() {
          ForEach(this.deviceRecords, (record: DeviceRecord) => {
            ListItem() {
              Row() {
                Text(record.deviceName)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                  .layoutWeight(2)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(getPeripheralTypeLabel(record.deviceType))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
                  .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
                  .borderRadius(4)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .layoutWeight(1.5)

                Text(record.deviceId)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(2)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(record.connectTime)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(2)

                Text(record.policy)
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(record.policy === '允许' ? AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT : AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
                  .backgroundColor(record.policy === '允许' ? AppColors.getColors(this.currentTheme).TAG_GREEN_BG : AppColors.getColors(this.currentTheme).TAG_RED_BG)
                  .borderRadius(4)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .border({
                width: { bottom: 1 },
                color: AppColors.getColors(this.currentTheme).BORDER
              })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: AppColors.getColors(this.currentTheme).BORDER, startMargin: 0, endMargin: 0 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius({ bottomLeft: AppStyles.RADIUS_LG, bottomRight: AppStyles.RADIUS_LG })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
    .border({
      width: 1,
      color: this.hoveredPanelIndex === 0 ? AppColors.BRAND_PRIMARY : Color.Transparent
    })
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 0, true))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 0, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredPanelIndex = isHover ? 0 : -1
      })
    })
      */
    }
  }

  // ==================== Tab 2: 接口控制 ====================
  @Builder
  interfaceControlBuilder() {
    Scroll() {
      Column({ space: 0 }) {
        Column() {
          InterfaceControlItem({
            label: 'USB 接口',
            description: '启用或禁用 USB 接口。禁用后，USB 接口相关外设将无法接入。',
            options: ['启用', '禁用'],
            selectedIndex: this.usbDisabled ? 1 : 0,
            isProcessing: this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_USB)),
            syncToken: this.interfaceControlSyncToken,
            onSelect: (index: number) => {
              this.handleInterfaceToggle(PeripheralService.FEATURE_USB, index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: 'USB 存储设备',
            description: '设置 USB 存储设备的访问权限，可选只读、读写或禁止访问。',
            options: ['只读', '读写', '禁止访问'],
            selectedIndex: this.usbStoragePolicyIndex,
            isProcessing: this.isInterfaceControlProcessing(this.usbStorageControlKey),
            syncToken: this.interfaceControlSyncToken,
            onSelect: (index: number) => {
              this.handleUsbStoragePolicyChange(index)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: '蓝牙',
            description: '启用或禁用蓝牙接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.btDisabled ? 1 : 0,
            isProcessing: this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_BLUETOOTH)),
            syncToken: this.interfaceControlSyncToken,
            onSelect: (index: number) => {
              this.handleInterfaceToggle(PeripheralService.FEATURE_BLUETOOTH, index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: 'Wi-Fi',
            description: '启用或禁用 Wi-Fi 接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.wifiDisabled ? 1 : 0,
            isProcessing: this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_WIFI)),
            syncToken: this.interfaceControlSyncToken,
            onSelect: (index: number) => {
              this.handleInterfaceToggle(PeripheralService.FEATURE_WIFI, index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: 'HDC 调试',
            description: '启用或禁用 HDC 调试接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.hdcDisabled ? 1 : 0,
            isProcessing: this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_HDC)),
            syncToken: this.interfaceControlSyncToken,
            onSelect: (index: number) => {
              this.handleInterfaceToggle(PeripheralService.FEATURE_HDC, index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: '网络共享',
            description: '启用或禁用网络共享接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.networkDisabled ? 1 : 0,
            isProcessing: this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_NETWORK)),
            syncToken: this.interfaceControlSyncToken,
            onSelect: (index: number) => {
              this.handleInterfaceToggle(PeripheralService.FEATURE_NETWORK, index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: '打印机',
            description: '启用或禁用打印机接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.printerDisabled ? 1 : 0,
            isProcessing: this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_PRINTER)),
            syncToken: this.interfaceControlSyncToken,
            onSelect: (index: number) => {
              this.handleInterfaceToggle(PeripheralService.FEATURE_PRINTER, index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: '麦克风',
            description: '启用或禁用麦克风接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.microphoneDisabled ? 1 : 0,
            isProcessing: this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_MICROPHONE)),
            syncToken: this.interfaceControlSyncToken,
            onSelect: (index: number) => {
              this.handleInterfaceToggle(PeripheralService.FEATURE_MICROPHONE, index === 1)
            }
          })

          Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

          InterfaceControlItem({
            label: '摄像头',
            description: '启用或禁用摄像头接口。',
            options: ['启用', '禁用'],
            selectedIndex: this.cameraDisabled ? 1 : 0,
            isProcessing: this.isInterfaceControlProcessing(this.getInterfaceControlKey(PeripheralService.FEATURE_CAMERA)),
            syncToken: this.interfaceControlSyncToken,
            onSelect: (index: number) => {
              this.handleInterfaceToggle(PeripheralService.FEATURE_CAMERA, index === 1)
            }
          })
        }
        .borderRadius(AppStyles.RADIUS_LG)
        .clip(true)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 1, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 1, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 1 : -1
          })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  @Builder
  deviceControlBuilder() {
    Column() {
      if (this.deviceControlRecords.length === 0) {
        Column({ space: 12 }) {
          Text('暂无已纳管设备，请在「黑白名单」中添加设备')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        // 表头
        Row() {
          Text('设备名称').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('设备类型').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1.5)
          Text('设备标识').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('场景').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(2)
          Text('管控策略').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1.5)
          Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(0.8)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
        .borderRadius({ topLeft: AppStyles.RADIUS_LG, topRight: AppStyles.RADIUS_LG })

        List() {
          ForEach(this.deviceControlRecords, (record: DeviceControlRecord, index: number) => {
            ListItem() {
              Row() {
                Text(record.deviceName)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                  .layoutWeight(2)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(getPeripheralTypeLabel(record.deviceType))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
                  .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
                  .borderRadius(4)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .layoutWeight(1.5)

                Text(record.deviceId)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(2)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(record.connectTime)
                  .fontSize(AppStyles.FONT_SIZE_SMALL)
                  .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                  .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                  .layoutWeight(2)

                // 管控策略下拉选择框
                Select(this.deviceControlPolicyOptions)
                  .selected(record.policyIndex)
                  .value(this.deviceControlPolicyOptions[record.policyIndex].value as string)
                  .font({ size: AppStyles.FONT_SIZE_CAPTION })
                  .fontColor(FormControlUtils.text(this.currentTheme))
                  .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
                  .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
                  .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION })
                  .optionFont({ size: AppStyles.FONT_SIZE_CAPTION })
                  .backgroundColor(FormControlUtils.background(this.currentTheme))
                  .borderRadius(AppStyles.RADIUS_SM)
                  .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
                  .layoutWeight(1.5)
                  .onSelect((selectIndex: number) => {
                    this.handleDeviceControlPolicyChange(index, selectIndex)
                  })

                // 操作列：详情按钮
                Text('详情')
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(AppColors.BRAND_PRIMARY)
                  .layoutWeight(0.8)
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    try {
                      this.showResultDialog('failure', '场景详情功能开发中')
                    } catch (e) {
                      hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
                    }
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 10 })
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 1, color: AppColors.getColors(this.currentTheme).BORDER, startMargin: 0, endMargin: 0 })

        // 底部操作栏
        Divider().color(AppColors.getColors(this.currentTheme).BORDER).opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
        Row() {
          Text('下载设备管控模板')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontColor(AppColors.BRAND_PRIMARY)
            .onClick(() => {
              try {
                this.showResultDialog('failure', '下载模板功能开发中')
              } catch (e) {
                hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
              }
            })
          Text('导入设备管控清单')
            .fontSize(AppStyles.FONT_SIZE_SMALL)
            .fontColor(AppColors.BRAND_PRIMARY)
            .onClick(() => {
              try {
                this.showResultDialog('failure', '导入清单功能开发中')
              } catch (e) {
                hilog.error(0x0002, TAG, `showToast failed: ${JSON.stringify(e)}`)
              }
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .justifyContent(FlexAlign.SpaceBetween)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD })
    .border({
      width: 1,
      color: this.hoveredPanelIndex === 2 ? AppColors.SUCCESS : Color.Transparent
    })
    .borderRadius(AppStyles.RADIUS_LG)
    .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 2, true))
    .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 2, 4) })
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        this.hoveredPanelIndex = isHover ? 2 : -1
      })
    })
  }

  // ==================== Tab 4: 黑白名单 ====================
  @Builder
  peripheralPolicyListBuilder() {
    Scroll() {
      Column() {
        if (this.peripheralPolicyRecords.length === 0) {
          Column({ space: 12 }) {
            Text('暂无可管理的 USB 设备记录')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
            Text('设备接入后会按最近记录去重展示，并可直接设置允许接入或禁止访问。')
              .fontSize(AppStyles.FONT_SIZE_SMALL)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .width('100%')
          .padding(24)
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .borderRadius(AppStyles.RADIUS_LG)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        } else {
          Column({ space: 0 }) {
            Row({ space: 12 }) {
              Text('设备名称')
                .fontSize(AppStyles.FONT_SIZE_SMALL)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                .layoutWeight(1.8)
              Text('设备类型')
                .fontSize(AppStyles.FONT_SIZE_SMALL)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                .layoutWeight(1.1)
              Text('设备标识')
                .fontSize(AppStyles.FONT_SIZE_SMALL)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                .layoutWeight(1.6)
              Text('最近连接时间')
                .fontSize(AppStyles.FONT_SIZE_SMALL)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                .layoutWeight(1.3)
              Text('当前策略')
                .fontSize(AppStyles.FONT_SIZE_SMALL)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
                .layoutWeight(1.2)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
            .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)

            Column({ space: 0 }) {
              ForEach(this.peripheralPolicyRecords, (record: PeripheralPolicyRecord, index: number) => {
                Column({ space: 0 }) {
                  Row({ space: 12 }) {
                    Text(record.deviceName)
                      .fontSize(AppStyles.FONT_SIZE_BODY)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                      .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                      .layoutWeight(1.8)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Row() {
                      Text(getPeripheralTypeLabel(record.deviceType))
                        .fontSize(AppStyles.FONT_SIZE_CAPTION)
                        .fontColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT)
                        .backgroundColor(AppColors.getColors(this.currentTheme).TAG_PURPLE_BG)
                        .borderRadius(AppStyles.RADIUS_SM)
                        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    }
                    .layoutWeight(1.1)

                    Text(record.deviceId)
                      .fontSize(AppStyles.FONT_SIZE_CAPTION)
                      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                      .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
                      .layoutWeight(1.6)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(record.lastSeenLabel)
                      .fontSize(AppStyles.FONT_SIZE_CAPTION)
                      .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                      .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
                      .layoutWeight(1.3)

                    Select(this.policyListOptions)
                      .selected(record.policyIndex)
                      .value(this.getPeripheralPolicyLabel(record.policyIndex))
                      .font({ size: AppStyles.FONT_SIZE_CAPTION })
                      .fontColor(FormControlUtils.text(this.currentTheme))
                      .textModifier(new TextModifier().fontColor(FormControlUtils.text(this.currentTheme)))
                      .arrowModifier(new SymbolGlyphModifier().fontColor([FormControlUtils.selectArrow(this.currentTheme)]))
                      .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION })
                      .optionFont({ size: AppStyles.FONT_SIZE_CAPTION })
                      .backgroundColor(FormControlUtils.background(this.currentTheme))
                      .borderRadius(AppStyles.RADIUS_SM)
                      .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
                      .layoutWeight(1.2)
                      .enabled(!this.isPeripheralPolicyUpdating(record.deviceId))
                      .opacity(this.isPeripheralPolicyUpdating(record.deviceId) ? 0.6 : 1)
                      .onSelect((selectIndex: number) => {
                        this.handlePeripheralPolicyChange(index, selectIndex)
                      })
                  }
                  .width('100%')
                  .padding({ left: 20, right: 20, top: 16, bottom: 16 })
                  .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
                  .translate({ y: HoverUtils.getTranslateY(this.hoveredPolicyRecordIndex === index, 2) })
                  .onHover((isHover: boolean) => {
                    HoverUtils.animate(() => {
                      this.hoveredPolicyRecordIndex = isHover ? index : -1
                    })
                  })

                  if (index < this.peripheralPolicyRecords.length - 1) {
                    Divider()
                      .color(AppColors.getColors(this.currentTheme).BORDER)
                      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)
                      .margin({ left: 20, right: 20 })
                  }
                }
              }, (record: PeripheralPolicyRecord) => `${record.deviceId}-${record.policyIndex}-${this.peripheralPolicyRenderVersion}`)
            }
            .width('100%')
          }
          .width('100%')
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
          .borderRadius(AppStyles.RADIUS_LG)
          .clip(true)
          .border({
            width: 1,
            color: AppColors.getColors(this.currentTheme).BORDER
          })
          .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 3, true))
          .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 3, 4) })
          .onHover((isHover: boolean) => {
            HoverUtils.animate(() => {
              this.hoveredPanelIndex = isHover ? 3 : -1
            })
          })
        }
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_LG })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }

  @Builder
  blackWhiteListBuilder() {
    Scroll() {
      Column({ space: 24 }) {
        // USB 设备白名单
        Column({ space: 12 }) {
          Row() {
            Text('USB 设备白名单（按设备ID）')
              .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              .layoutWeight(1)
            Button('+ 添加')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(Color.White)
              .backgroundColor(AppColors.BRAND_PRIMARY)
              .borderRadius(AppStyles.RADIUS_MD)
              .height(32)
              .onClick(() => {
                this.openUsbWhitelistDialog()
              })
          }
          .width('100%')

          // 表头
          Row() {
            Text('厂商 ID').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('产品 ID').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius({ topLeft: AppStyles.RADIUS_MD, topRight: AppStyles.RADIUS_MD })

          if (this.usbWhitelist.length === 0) {
            Text('暂无 USB 白名单项。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              .padding(24)
              .width('100%')
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
          } else {
            Column() {
              ForEach(this.usbWhitelist, (device: edmUsbManager.UsbDeviceId) => {
                Row() {
                  Text(this.formatHex(device.vendorId))
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text(this.formatHex(device.productId))
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text('删除')
                    .fontSize(AppStyles.FONT_SIZE_CAPTION)
                    .fontColor(AppColors.DANGER)
                    .layoutWeight(1)
                    .onClick(() => {
                      this.handleRemoveUsbWhitelist(device)
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              })
            }
            .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
            .clip(true)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 3, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 3, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 3 : -1
          })
        })

        // USB 设备类型黑名单
        Column({ space: 12 }) {
          Row() {
            Text('USB 设备黑名单（按设备类型）')
              .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              .layoutWeight(1)
            Button('+ 添加')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(Color.White)
              .backgroundColor(AppColors.BRAND_PRIMARY)
              .borderRadius(AppStyles.RADIUS_MD)
              .height(32)
              .onClick(() => {
                this.openUsbBlacklistDialog()
              })
          }
          .width('100%')

          Row() {
            Text('基础类').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('子类').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('协议').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius({ topLeft: AppStyles.RADIUS_MD, topRight: AppStyles.RADIUS_MD })

          if (this.usbBlacklist.length === 0) {
            Text('暂无 USB 黑名单项。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              .padding(24)
              .width('100%')
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
          } else {
            Column() {
              ForEach(this.usbBlacklist, (dt: edmUsbManager.UsbDeviceType) => {
                Row() {
                  Text(this.formatHex(dt.baseClass))
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text(this.formatHex(dt.subClass))
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text(this.formatHex(dt.protocol))
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text('删除')
                    .fontSize(AppStyles.FONT_SIZE_CAPTION)
                    .fontColor(AppColors.DANGER)
                    .layoutWeight(1)
                    .onClick(() => {
                      this.handleRemoveUsbBlacklist(dt)
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              })
            }
            .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
            .clip(true)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 4, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 4, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 4 : -1
          })
        })

        // 蓝牙白名单
        Column({ space: 12 }) {
          Row() {
            Text('蓝牙设备白名单（按MAC地址）')
              .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
              .layoutWeight(1)
            Button('+ 添加')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(Color.White)
              .backgroundColor(AppColors.BRAND_PRIMARY)
              .borderRadius(AppStyles.RADIUS_MD)
              .height(32)
              .onClick(() => {
                this.openBtWhitelistDialog()
              })
          }
          .width('100%')

          Row() {
            Text('MAC 地址').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
            Text('操作').fontSize(AppStyles.FONT_SIZE_SMALL).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY).layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 10, bottom: 10 })
          .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
          .borderRadius({ topLeft: AppStyles.RADIUS_MD, topRight: AppStyles.RADIUS_MD })

          if (this.btWhitelist.length === 0) {
            Text('暂无蓝牙白名单项。')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
              .padding(24)
              .width('100%')
              .textAlign(TextAlign.Center)
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
          } else {
            Column() {
              ForEach(this.btWhitelist, (mac: string) => {
                Row() {
                  Text(mac)
                    .fontSize(AppStyles.FONT_SIZE_SMALL)
                    .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                    .layoutWeight(1)
                  Text('删除')
                    .fontSize(AppStyles.FONT_SIZE_CAPTION)
                    .fontColor(AppColors.DANGER)
                    .layoutWeight(1)
                    .onClick(() => {
                      this.handleRemoveBluetoothWhitelist(mac)
                    })
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
              })
            }
            .borderRadius({ bottomLeft: AppStyles.RADIUS_MD, bottomRight: AppStyles.RADIUS_MD })
            .clip(true)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(16)
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
        .borderRadius(AppStyles.RADIUS_LG)
        .border({
          width: 1,
          color: AppColors.getColors(this.currentTheme).BORDER
        })
        .shadow(HoverUtils.getShadow(this.currentTheme, this.hoveredPanelIndex === 5, true))
        .translate({ y: HoverUtils.getTranslateY(this.hoveredPanelIndex === 5, 4) })
        .onHover((isHover: boolean) => {
          HoverUtils.animate(() => {
            this.hoveredPanelIndex = isHover ? 5 : -1
          })
        })
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_LG })
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .align(Alignment.Top)
  }
}

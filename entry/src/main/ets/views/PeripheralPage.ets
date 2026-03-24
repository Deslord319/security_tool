import { AppColors, AppStyles } from '../constants/AppConstants'
import { PeripheralService } from '../services/PeripheralService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { PeripheralConnectionRecordService } from '../services/PeripheralConnectionRecordService'
import { InterfaceControlItem } from '../components/InterfaceControlItem'
import { AddWhitelistDialog } from '../components/AddWhitelistDialog'
import { AddBlacklistDialog } from '../components/AddBlacklistDialog'
import { EmptyStatePanel } from '../components/EmptyStatePanel'
import {
  AdminActivationState,
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
import { PeripheralViewModel } from '../viewmodels/PeripheralViewModel'
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
  private viewModel: PeripheralViewModel = new PeripheralViewModel()
  private tabsController: TabsController = new TabsController()
  private touchStartTab: number = 0
  @State currentTab: number = 0
  @State hoveredPanelIndex: number = -1
  @State touchStartX: number = 0
  @State touchStartY: number = 0
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

  // 设备连接记录
  @State deviceRecords: PeripheralConnectionRecord[] = []
  @State isConnectionDetailDialogVisible: boolean = false
  @State selectedConnectionRecord: PeripheralConnectionRecord | null = null
  @State connectionDetailHostWidth: number = 0
  private traceStorageListenerId: number = -1
  private readonly connectionDetailCompactWidthThreshold: number = 1200
  private readonly usbStorageControlKey: string = 'usb-storage-policy'
  private readonly usbRecordTypes: PeripheralType[] = [
    PeripheralType.USB_STORAGE,
    PeripheralType.USB_CAMERA,
    PeripheralType.USB_PRINTER,
    PeripheralType.USB_HID,
    PeripheralType.USB_OTHER
  ]

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



    if (source === 'runtime_event') {
      return 1
    }
    if (source === 'audit_event') {
      return 2
    }
    return 3
  }

    return right.timestamp - left.timestamp
  }

  private setPanelHover(index: number, isHover: boolean): void {
    HoverUtils.animate(() => {
      this.hoveredPanelIndex = isHover ? index : -1
    })
  }

  /**
   * Switch to target tab with optional animation.
   * @param index Target tab index (0-2)
   * @param enableAnimation Whether to animate the transition (default: true)
   */
  private switchToTab(index: number, enableAnimation: boolean = true): void {
    if (index < 0 || index > 2 || index === this.currentTab) {
      return
    }

    this.currentTab = index
    this.tabsController.changeIndex(index)
    if (index === 2) {
      this.loadConnectedUsbDevices()
    }
  }

  /**
   * Handle swipe gesture for cyclic tab navigation.
   * Supports 3-tab cyclic navigation: Tab 0 ↔ Tab 1 ↔ Tab 2 ↔ Tab 0
   */
  private handlePageTouch(event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      if (event.touches.length === 0) {
        return
      }
      this.touchStartTab = this.currentTab
      this.touchStartX = event.touches[0].x
      this.touchStartY = event.touches[0].y
      return
    }

    if (event.type !== TouchType.Up || event.changedTouches.length === 0) {
      return
    }

    let offsetX = event.changedTouches[0].x - this.touchStartX
    let offsetY = event.changedTouches[0].y - this.touchStartY
    if (Math.abs(offsetX) < 120 || Math.abs(offsetX) <= Math.abs(offsetY)) {
      return
    }

    // 向右滑动：去序号更大的 Tab（循环：Tab 2 → Tab 0）
    if (offsetX > 0) {
      if (this.touchStartTab === 0) {
        this.switchToTab(1, true)
      } else if (this.touchStartTab === 1) {
        this.switchToTab(2, true)
      } else if (this.touchStartTab === 2) {
        // 循环到 Tab 0，禁用动画避免闪过 Tab 1
        this.switchToTab(0, false)
      }
      return
    }

    // 向左滑动：去序号更小的 Tab（循环：Tab 0 → Tab 2）
    if (offsetX < 0) {
      if (this.touchStartTab === 0) {
        // 循环到 Tab 2，禁用动画避免闪过 Tab 1
        this.switchToTab(2, false)
      } else if (this.touchStartTab === 1) {
        this.switchToTab(0, true)
      } else if (this.touchStartTab === 2) {
        this.switchToTab(1, true)
      }
    }
  }
)

    for (let device of this.connectedUsbDevices) {
      let deviceId = formatUsbDeviceId(device.vendorId, device.productId)
      let key = deviceId.toUpperCase()
      if (items.has(key)) {
        continue
      }
      let type = inferPeripheralTypeFromBaseClass(device.clazz)
      let name = this.viewModel.buildUsbDisplayName(
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
|${subClass}|${protocol}`
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
)

    for (let device of this.connectedUsbDevices) {
      let title = this.viewModel.buildUsbDisplayName(
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
    this.viewModel.reloadDeviceRecords()
    this.loadPeripheralPolicyData()
  }
  private refreshAdminActivationState(): void {
    this.viewModel.refreshAdminActivationState()
    this.adminState = this.viewModel.adminState
  }

  private ensureAdminReady(action: string): boolean {
    if (this.viewModel.ensureAdminReady(action)) {
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

    // 加载设备连接记录
    this.loadConnectedUsbDevices()
    this.reloadDeviceRecords()

    this.isLoading = false
  }

  // ========== 设备管控数据加载 ==========

  // 常见设备 VID/PID -> 名称映射`
  }

  private isInterfaceControlProcessing(controlKey: string): boolean {
    return this.interfaceControlProcessingKey === controlKey
  }

    if (policy === edmUsbManager.UsbPolicy.READ_WRITE) {
      return 1
    }
    return 2
  }
`
  }

  private reloadInterfaceControlState(reason: string): void {
    hilog.info(0x0002, TAG, `interfaceControl reload start, reason=${reason}`)
    this.viewModel.reloadAllData()
    // Sync state from ViewModel to Page
    this.usbDisabled = this.viewModel.usbDisabled
    this.btDisabled = this.viewModel.btDisabled
    this.wifiDisabled = this.viewModel.wifiDisabled
    this.hdcDisabled = this.viewModel.hdcDisabled
    this.networkDisabled = this.viewModel.networkDisabled
    this.printerDisabled = this.viewModel.printerDisabled
    this.microphoneDisabled = this.viewModel.microphoneDisabled
    this.cameraDisabled = this.viewModel.cameraDisabled
    this.usbStoragePolicyIndex = this.viewModel.usbStoragePolicyIndex
    this.usbWhitelist = this.viewModel.usbWhitelist
    this.usbBlacklist = this.viewModel.usbBlacklist
    this.btWhitelist = this.viewModel.btWhitelist
    this.interfaceControlSyncToken += 1
    hilog.info(0x0002, TAG, `interfaceControl reload done, reason=${reason}`)
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
)
    return `\﻿${headers.map((item: string) => this.escapeCsvValue(item)).join(',')}\n${rows.join('\n')}`
  }

    return this.policyListOptions[0].value as string
  }



      return
    }
    this.policyUpdatingKeys = this.policyUpdatingKeys.filter((item: string) => item !== deviceId)
  }

  private async handlePeripheralPolicyChange(recordIndex: number, policyIndex: number): Promise<void> {
    const record = this.peripheralPolicyRecords[recordIndex]
    if (!record) return
    if (record.policyIndex === policyIndex) return

    const success = await this.viewModel.handlePeripheralPolicyChange(record.deviceId, record.deviceType, policyIndex)
    if (!success) {
      this.showResultDialog('failure', this.viewModel.errorMessage || '修改设备策略失败')
    }
  }

  // ========== 接口管控操作 ==========

  async handleInterfaceToggle(feature: string, disallow: boolean): Promise<void> {
    const success = await this.viewModel.toggleInterface(feature, disallow)
    if (!success) {
      this.showResultDialog('failure', this.viewModel.errorMessage || '接口管控失败')
    }
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

  async handleAddUsbWhitelist(vendorId: number, productId: number) {
    const success = await this.viewModel.addToUsbWhitelist(vendorId, productId)
    if (!success) {
      this.showResultDialog('failure', this.viewModel.errorMessage || '添加 USB 白名单失败')
    }
  }

  async handleRemoveUsbWhitelist(device: edmUsbManager.UsbDeviceId) {
    const success = await this.viewModel.removeFromUsbWhitelist(device)
    if (!success) {
      this.showResultDialog('failure', this.viewModel.errorMessage || '移除 USB 白名单失败')
    }
  }

  async handleAddBluetoothWhitelist(mac: string) {
    const success = await this.viewModel.addToBluetoothWhitelist(mac)
    if (!success) {
      this.showResultDialog('failure', this.viewModel.errorMessage || '添加蓝牙白名单失败')
    }
  }

  async handleRemoveBluetoothWhitelist(mac: string) {
    const success = await this.viewModel.removeFromBluetoothWhitelist(mac)
    if (!success) {
      this.showResultDialog('failure', this.viewModel.errorMessage || '移除蓝牙白名单失败')
    }
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

  async handleRemoveUsbBlacklist(deviceType: edmUsbManager.UsbDeviceType) {
    const success = await this.viewModel.removeFromUsbBlacklist(deviceType)
    if (!success) {
      this.showResultDialog('failure', this.viewModel.errorMessage || '移除 USB 黑名单失败')
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
      Tabs({ barPosition: BarPosition.Start, controller: this.tabsController }) {
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
    .onTouch((event: TouchEvent) => {
      this.handlePageTouch(event)
    })
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
      this.reloadDeviceRecords()
      this.showResultDialog('success', '历史记录已清理')
    } catch (err) {
      hilog.error(0x0008, TAG, `clearConnectionHistory failed: ${JSON.stringify(err)}`)
      this.showResultDialog('failure', '清理未完成，请稍后重试')
    }
  }
)
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

  private getConnectionResultLabel(record: PeripheralConnectionRecord): string {
    if (record.source === 'policy_snapshot') {
      return '快照'
    }
    return getLogEventResultLabel(record.result)
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

  @Builder
  private deviceRecordsBuilder() {
    Scroll() {
      Column({ space: 0 }) {
        if (this.deviceRecords.length === 0) {
          EmptyStatePanel({
            title: '暂无设备连接记录',
            description: '暂无实时记录，请重新插拔设备后刷新。',
            radius: AppStyles.RADIUS_LG,
            verticalPadding: 24
          })
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
            this.setPanelHover(0, isHover)
          })
        }
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
          this.setPanelHover(1, isHover)
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

  // ==================== Tab 3: 黑白名单 ====================
  @Builder
  peripheralPolicyListBuilder() {
    Scroll() {
      Column() {
        if (this.peripheralPolicyRecords.length === 0) {
          EmptyStatePanel({
            title: '暂无可管理的 USB 设备记录',
            description: '设备接入后会按最近记录去重展示，并可直接设置允许接入或禁止访问。',
            radius: AppStyles.RADIUS_LG,
            verticalPadding: 24
          })
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
            this.setPanelHover(3, isHover)
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
}
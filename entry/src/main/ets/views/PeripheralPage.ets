import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BackNavButton } from '../components/BackNavButton'
import { ResultMessageBox, ResultMessageStatus } from '../components/ResultMessageBox'
import {
  ConnectionDetailDialog,
  ConnectionHistoryItem
} from '../components/peripheral/ConnectionDetailDialog'
import { DeviceRecordList } from '../components/peripheral/DeviceRecordList'
import { InterfaceControlTab } from '../components/peripheral/InterfaceControlTab'
import { PageHeaderActions } from '../components/peripheral/PageHeaderActions'
import { PolicyList, PolicyOption } from '../components/peripheral/PolicyList'
import { TabBuilder } from '../components/peripheral/TabBuilder'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { PeripheralConnectionRecord, PeripheralPolicyRecord } from '../models/DataModels'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { PeripheralRuntimeEventService } from '../services/PeripheralRuntimeEventService'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'
import { ResultDialogHelper } from '../utils/ResultDialogHelper'
import { PeripheralViewModel } from '../viewmodels/PeripheralViewModel'
import {
  REASON_ADMIN_REQUIRED,
  REASON_EMPTY_CONNECTION_HISTORY,
  REASON_EMPTY_POLICY_RECORDS,
  REASON_EXPORT_CONNECTION_HISTORY_FAILED,
  REASON_EXPORT_ENV_NOT_READY,
  REASON_EXPORT_POLICY_RECORDS_FAILED,
  REASON_INFER_BLACKLIST_TYPE_FAILED,
  REASON_INIT_FAILED,
  REASON_INVALID_DEVICE_ID,
  REASON_POLICY_CHANGE_FAILED,
  REASON_PRECHECK_BLACKLIST_CONFLICT,
  REASON_PRECHECK_WHITELIST_CONFLICT,
  REASON_READ_USB_BLACKLIST_FAILED,
  REASON_READ_USB_STATUS_FAILED,
  REASON_READ_USB_STORAGE_POLICY_FAILED,
  REASON_READ_USB_WHITELIST_FAILED,
  REASON_SET_USB_INTERFACE_CONFLICT,
  REASON_SET_USB_STORAGE_POLICY_CONFLICT,
  REASON_TOGGLE_INTERFACE_FAILED,
  REASON_USB_STORAGE_POLICY_FAILED
} from '../viewmodels/PeripheralViewModelReasons'

const TAG = 'PeripheralPage'
const DOMAIN = 0x0013
const MIN_USB_LOADING_DIALOG_DURATION_MS = 500

@CustomDialog
struct PeripheralUsbLoadingDialog {
  controller: CustomDialogController
  message: string = '正在更新 USB 策略，请稍候...'
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 14 }) {
      LoadingProgress().width(44).height(44)
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
    .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
  }
}

@Component
export struct PeripheralPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State viewModel: PeripheralViewModel = new PeripheralViewModel()
  @State hoveredPanelIndex: number = -1
  @State renderVersion: number = 0
  @State detailVisible: boolean = false
  @State detailRecord: PeripheralConnectionRecord | null = null
  @State detailHistoryItems: ConnectionHistoryItem[] = []

  private tabsController: TabsController = new TabsController()
  private policyListOptions: PolicyOption[] = [{ value: '允许接入' }, { value: '禁止访问' }]
  private resultDialogController: CustomDialogController = new CustomDialogController({
    builder: ResultMessageBox({ onConfirm: () => {} }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  })
  private usbLoadingDialogController?: CustomDialogController
  private isUsbLoadingDialogOpen: boolean = false
  private usbLoadingDialogOpenedAt: number = 0

  aboutToAppear() {
    void this.initViewModel()
  }

  aboutToDisappear() {
    this.closeUsbLoadingDialog()
    this.closeDetailDialog()
    this.viewModel.onRefresh = undefined
    this.viewModel.destroy()
  }

  private async initViewModel(): Promise<void> {
    try {
      this.viewModel.onRefresh = () => {
        this.renderVersion++
      }
      const context = getContext(this) as common.UIAbilityContext
      await PeripheralRuntimeEventService.init(context)
      await PeripheralRuntimeEventService.start()
      await this.viewModel.initialize(context)
      this.renderVersion++
    } catch (err) {
      hilog.error(DOMAIN, TAG, `initViewModel failed: ${JSON.stringify(err)}`)
      this.showResultDialog('failure', this.resolveReason(REASON_INIT_FAILED))
    }
  }

  private resolveReason(reason?: string | null): string {
    switch (reason) {
      case REASON_ADMIN_REQUIRED:
        return '请先激活企业管理员权限'
      case REASON_INIT_FAILED:
        return '外设管理初始化失败，请稍后重试'
      case REASON_INVALID_DEVICE_ID:
        return '无法识别当前设备标识'
      case REASON_EXPORT_ENV_NOT_READY:
        return '导出环境尚未初始化，请稍后重试'
      case REASON_EMPTY_CONNECTION_HISTORY:
        return '没有可导出的设备连接记录'
      case REASON_EMPTY_POLICY_RECORDS:
        return '暂无可导出的设备策略记录'
      case REASON_TOGGLE_INTERFACE_FAILED:
        return '接口管控设置失败，请稍后重试'
      case REASON_USB_STORAGE_POLICY_FAILED:
        return '设置 USB 存储策略失败，请稍后重试'
      case REASON_POLICY_CHANGE_FAILED:
        return '修改设备策略失败，请稍后重试'
      case REASON_EXPORT_CONNECTION_HISTORY_FAILED:
        return '导出历史记录失败，请稍后重试'
      case REASON_EXPORT_POLICY_RECORDS_FAILED:
        return '导出策略记录失败，请稍后重试'
      case REASON_READ_USB_STATUS_FAILED:
        return '读取 USB 状态失败，请稍后重试'
      case REASON_READ_USB_STORAGE_POLICY_FAILED:
        return '读取 USB 存储策略失败，请稍后重试'
      case REASON_READ_USB_WHITELIST_FAILED:
        return '读取 USB 白名单失败，请稍后重试'
      case REASON_READ_USB_BLACKLIST_FAILED:
        return '读取 USB 黑名单失败，请稍后重试'
      case REASON_PRECHECK_BLACKLIST_CONFLICT:
        return '当前存在 USB 禁止访问规则冲突，请先清理后再设置允许接入'
      case REASON_PRECHECK_WHITELIST_CONFLICT:
        return '当前存在 USB 允许接入规则冲突，请先清理后再设置禁止访问'
      case REASON_INFER_BLACKLIST_TYPE_FAILED:
        return '当前设备类型暂不支持设置为禁止访问'
      case REASON_SET_USB_INTERFACE_CONFLICT:
        return '系统检测到仍存在 USB 冲突规则，暂时无法完成 USB 接口设置，请稍后重试'
      case REASON_SET_USB_STORAGE_POLICY_CONFLICT:
        return '系统检测到仍存在 USB 冲突规则，暂时无法完成存储策略设置，请稍后重试'
      default:
        return reason && reason.trim().length > 0 ? reason : '请稍后重试'
    }
  }

  private showResultDialog(status: ResultMessageStatus, message: string): void {
    ResultDialogHelper.prepareResultDialog(status, message)
    try {
      this.resultDialogController.close()
    } catch (_err) {
    }
    this.resultDialogController.open()
  }

  private showAdminRequiredDialog(action: string): void {
    this.showResultDialog('failure', `${action}未完成，请先激活企业管理员权限`)
  }

  private showConnectionHistoryExportSuccessDialog(): void {
    this.showResultDialog('success', '历史记录已导出，保存位置：下载/安全管理中心')
  }

  private showPolicyRecordExportSuccessDialog(): void {
    this.showResultDialog('success', '策略记录已导出，保存位置：下载/安全管理中心')
  }

  private openUsbLoadingDialog(message: string): void {
    this.closeUsbLoadingDialog()
    this.usbLoadingDialogController = new CustomDialogController({
      builder: PeripheralUsbLoadingDialog({ message: message }),
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
      this.usbLoadingDialogController = undefined
      this.usbLoadingDialogOpenedAt = 0
      return
    }
    try {
      this.usbLoadingDialogController?.close()
    } catch (_err) {
    } finally {
      this.usbLoadingDialogController = undefined
      this.usbLoadingDialogOpenedAt = 0
      this.isUsbLoadingDialogOpen = false
    }
  }

  private async runUsbOperationWithLoading(message: string, operation: () => Promise<boolean>): Promise<boolean> {
    this.openUsbLoadingDialog(message)
    try {
      return await operation()
    } finally {
      const remaining = MIN_USB_LOADING_DIALOG_DURATION_MS - (Date.now() - this.usbLoadingDialogOpenedAt)
      if (remaining > 0) {
        await new Promise<void>((resolve: () => void) => setTimeout(() => resolve(), remaining))
      }
      this.closeUsbLoadingDialog()
    }
  }

  private setPanelHover(index: number, isHover: boolean): void {
    HoverUtils.animate(() => {
      this.hoveredPanelIndex = isHover ? index : -1
    })
  }

  private handleTabChange(index: number): void {
    this.viewModel.switchToTab(index)
    this.renderVersion++
  }

  private openDetailDialog(record: PeripheralConnectionRecord): void {
    this.viewModel.openConnectionDetailDialog(record)
    this.detailRecord = this.viewModel.records.connectionDetailDialog.record
    this.detailHistoryItems = [...this.viewModel.records.connectionDetailDialog.historyItems]
    this.detailVisible = this.detailRecord !== null
    this.renderVersion++
  }

  private closeDetailDialog(): void {
    this.viewModel.closeConnectionDetailDialog()
    this.detailVisible = false
    this.detailRecord = null
    this.detailHistoryItems = []
    this.renderVersion++
  }

  @Builder
  private tabBarBuilder(title: string, index: number) {
    TabBuilder({ title: title, index: index, currentTab: this.viewModel.currentTab, currentTheme: this.currentTheme })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Text(`${this.renderVersion}`)
        .fontSize(0)
        .width(0)
        .height(0)
        .opacity(0)

      Column() {
        this.header()
        this.tabs()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)

      if (this.detailVisible && this.detailRecord) {
        ConnectionDetailDialog({
          selectedRecord: this.detailRecord,
          historyItems: this.detailHistoryItems,
          currentTheme: this.currentTheme,
          onClose: () => this.closeDetailDialog()
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private header() {
    Row() {
      Row({ space: 8 }) {
        BackNavButton({ onBack: () => this.onBack() })
        Column({ space: 4 }) {
          Text('外设管理')
            .fontSize(AppStyles.FONT_SIZE_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          Text('管控 USB、蓝牙、Wi-Fi 等外设接口，配置设备访问策略')
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Top)

      if (this.viewModel.currentTab === 1) {
        PageHeaderActions({
          currentTheme: this.currentTheme,
          exportLabel: '导出历史记录',
          clearLabel: '清理历史记录',
          onExport: () => void this.handleExportConnectionHistory(),
          onClear: () => this.showClearHistoryConfirmDialog(),
          showClear: true
        })
      } else if (this.viewModel.currentTab === 2) {
        PageHeaderActions({
          currentTheme: this.currentTheme,
          exportLabel: '导出策略记录',
          clearLabel: '删除策略记录',
          onExport: () => void this.handleExportPeripheralPolicyRecords(),
          onClear: () => this.showClearPolicyRecordsConfirmDialog(),
          showClear: true
        })
      }
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_LG })
  }

  @Builder
  private tabs() {
    Tabs({ barPosition: BarPosition.Start, controller: this.tabsController }) {
      TabContent() { this.interfaceTab() }.tabBar(this.tabBarBuilder('接口管控', 0))
      TabContent() { this.deviceTab() }.tabBar(this.tabBarBuilder('设备连接记录', 1))
      TabContent() { this.policyTab() }.tabBar(this.tabBarBuilder('黑白名单', 2))
    }
    .barMode(BarMode.Fixed)
    .barWidth('100%')
    .onChange((index: number) => this.handleTabChange(index))
    .layoutWeight(1)
  }

  @Builder
  private interfaceTab() {
    Column() {
      InterfaceControlTab({
        usbDisabled: this.viewModel.interfaceControl.state.usbDisabled,
        btDisabled: this.viewModel.interfaceControl.state.btDisabled,
        wifiDisabled: this.viewModel.interfaceControl.state.wifiDisabled,
        hdcDisabled: this.viewModel.interfaceControl.state.hdcDisabled,
        networkDisabled: this.viewModel.interfaceControl.state.networkDisabled,
        printerDisabled: this.viewModel.interfaceControl.state.printerDisabled,
        microphoneDisabled: this.viewModel.interfaceControl.state.microphoneDisabled,
        cameraDisabled: this.viewModel.interfaceControl.state.cameraDisabled,
        usbStoragePolicyIndex: this.viewModel.interfaceControl.state.usbStoragePolicyIndex,
        interfaceControlProcessingKey: this.viewModel.interfaceControl.processingKey,
        usbStorageControlKey: 'usb-storage-policy',
        interfaceControlSyncToken: this.viewModel.interfaceControl.syncVersion,
        currentTheme: this.currentTheme,
        hoveredPanelIndex: this.hoveredPanelIndex,
        onInterfaceToggle: (feature: string, disallow: boolean) => void this.handleInterfaceToggle(feature, disallow),
        onUsbStoragePolicyChange: (index: number) => void this.handleUsbStoragePolicyChange(index),
        onPanelHover: (isHover: boolean) => this.setPanelHover(0, isHover)
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  private deviceTab() {
    Column() {
      DeviceRecordList({
        deviceRecords: this.viewModel.records.records,
        currentTheme: this.currentTheme,
        hoveredPanelIndex: this.hoveredPanelIndex,
        refreshVersion: this.renderVersion,
        onRecordClick: (record: PeripheralConnectionRecord) => this.openDetailDialog(record),
        onPanelHover: (isHover: boolean) => this.setPanelHover(1, isHover)
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  private policyTab() {
    Column() {
      PolicyList({
        policyRecords: this.viewModel.policy.records,
        policyListOptions: this.policyListOptions,
        currentTheme: this.currentTheme,
        hoveredPanelIndex: this.hoveredPanelIndex,
        refreshVersion: this.renderVersion,
        onPolicyChange: (index: number, policyIndex: number) => {
          const record: PeripheralPolicyRecord | undefined = this.viewModel.policy.records[index]
          if (record) {
            void this.handlePolicyChange(record, policyIndex)
          }
        },
        getPolicyLabel: (index: number) => this.policyListOptions[index].value,
        isUpdating: (deviceId: string) => this.viewModel.policy.isUpdating(deviceId.toUpperCase()),
        onPanelHover: (isHover: boolean) => this.setPanelHover(2, isHover)
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  private async handleInterfaceToggle(feature: string, disallow: boolean): Promise<void> {
    const success = await this.viewModel.toggleInterface(feature, disallow)
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        this.showAdminRequiredDialog('设置接口策略')
      } else {
        this.showResultDialog('failure', this.resolveReason(this.viewModel.reasonCode))
      }
      return
    }
    this.renderVersion++
  }

  private async handleUsbStoragePolicyChange(index: number): Promise<void> {
    const success = await this.runUsbOperationWithLoading('正在设置 USB 存储策略，请稍候...', async () => {
      return await this.viewModel.setUsbStoragePolicy(index)
    })
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        this.showAdminRequiredDialog('设置 USB 存储策略')
      } else {
        this.showResultDialog('failure', this.resolveReason(this.viewModel.reasonCode))
      }
      return
    }
    this.renderVersion++
  }

  private async handlePolicyChange(record: PeripheralPolicyRecord, policyIndex: number): Promise<void> {
    const success = await this.viewModel.handlePeripheralPolicyChange(record.deviceId, record.deviceType, policyIndex)
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        this.showAdminRequiredDialog('修改设备策略')
      } else {
        this.showResultDialog('failure', this.resolveReason(this.viewModel.reasonCode))
      }
      return
    }
    this.renderVersion++
  }

  private async handleExportConnectionHistory(): Promise<void> {
    const success = await this.viewModel.exportConnectionHistory()
    if (success) {
      this.showConnectionHistoryExportSuccessDialog()
    } else {
      this.showResultDialog('failure', this.resolveReason(this.viewModel.reasonCode))
    }
  }

  private async handleExportPeripheralPolicyRecords(): Promise<void> {
    const success = await this.viewModel.exportPeripheralPolicyRecords()
    if (success) {
      this.showPolicyRecordExportSuccessDialog()
    } else {
      this.showResultDialog('failure', this.resolveReason(this.viewModel.reasonCode))
    }
  }

  private showClearHistoryConfirmDialog(): void {
    if (this.viewModel.records.records.length === 0) {
      this.showResultDialog('failure', '暂无可清理的历史记录')
      return
    }
    void this.getUIContext().showAlertDialog({
      title: '清理历史记录',
      message: '将清空当前设备连接历史记录，且无法恢复。是否继续？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '清理', action: () => void this.clearConnectionHistory() }
    })
  }

  private showClearPolicyRecordsConfirmDialog(): void {
    if (this.viewModel.policy.records.length === 0) {
      this.showResultDialog('failure', '暂无可清理的策略记录')
      return
    }
    void this.getUIContext().showAlertDialog({
      title: '删除策略记录',
      message: '将清空当前策略记录列表，且无法恢复。是否继续？',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '删除', action: () => void this.clearPolicyRecords() }
    })
  }

  private async clearConnectionHistory(): Promise<void> {
    try {
      await PeripheralTraceRepository.init(getContext(this) as common.UIAbilityContext)
      const success = await PeripheralTraceRepository.clearAll()
      if (!success) {
        this.showResultDialog('failure', '清理未完成，请稍后重试')
        return
      }
      this.closeDetailDialog()
      this.viewModel.reloadDeviceRecords()
      this.renderVersion++
      this.showResultDialog('success', '历史记录已清理')
    } catch (err) {
      hilog.error(DOMAIN, TAG, `clearConnectionHistory failed: ${JSON.stringify(err)}`)
      this.showResultDialog('failure', '清理未完成，请稍后重试')
    }
  }

  private async clearPolicyRecords(): Promise<void> {
    const success = await this.viewModel.clearPeripheralPolicyRecords()
    if (!success) {
      this.showResultDialog('failure', '清理未完成，请稍后重试')
      return
    }
    this.closeDetailDialog()
    this.renderVersion++
    this.showResultDialog('success', '策略记录已清理')
  }
}

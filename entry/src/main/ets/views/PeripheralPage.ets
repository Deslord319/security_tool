import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BackNavButton } from '../components/BackNavButton'
import { ResultMessageBox, ResultMessageStatus } from '../components/ResultMessageBox'
import { ConnectionDetailDialog } from '../components/peripheral/ConnectionDetailDialog'
import { DeviceRecordList } from '../components/peripheral/DeviceRecordList'
import { InterfaceControlTab } from '../components/peripheral/InterfaceControlTab'
import { PageHeaderActions } from '../components/peripheral/PageHeaderActions'
import { PolicyList, PolicyOption } from '../components/peripheral/PolicyList'
import { TabBuilder } from '../components/peripheral/TabBuilder'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { PeripheralPolicyRecord } from '../models/DataModels'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'
import { ResultDialogHelper } from '../utils/ResultDialogHelper'
import { PeripheralViewModel } from '../viewmodels/PeripheralViewModel'

const TAG = 'PeripheralPage'
const DOMAIN = 0x0013
const MIN_USB_LOADING_DIALOG_DURATION_MS = 500

@CustomDialog
struct PeripheralUsbLoadingDialog {
  controller: CustomDialogController
  message: string = '正在更新 USB 策略，请稍候'
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
    this.viewModel.destroy()
  }

  private async initViewModel(): Promise<void> {
    try {
      await this.viewModel.initialize(getContext(this) as common.UIAbilityContext)
    } catch (err) {
      hilog.error(DOMAIN, TAG, `initViewModel failed: ${JSON.stringify(err)}`)
      this.showResultDialog('failure', '外设管理初始化失败，请稍后重试')
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
    this.showResultDialog('failure', `${action}未完成，${ResultDialogHelper.displayReason(this.viewModel.errorMessage ?? undefined, '请先激活企业管理员')}`)
  }

  private showConnectionHistoryExportSuccessDialog(): void {
    this.showResultDialog('success', '历史记录已导出，保存位置：下载/安全管理中心')
  }

  private showConnectionHistoryExportFailureDialog(reason?: string): void {
    this.showResultDialog('failure', `历史记录导出失败，${ResultDialogHelper.displayReason(reason, '请稍后重试')}`)
  }

  private showPolicyRecordExportSuccessDialog(): void {
    this.showResultDialog('success', '策略记录已导出，保存位置：下载/安全管理中心')
  }

  private showPolicyRecordExportFailureDialog(reason?: string): void {
    this.showResultDialog('failure', `策略记录导出失败，${ResultDialogHelper.displayReason(reason, '请稍后重试')}`)
  }

  private openUsbLoadingDialog(message: string): void {
    this.closeUsbLoadingDialog()
    this.usbLoadingDialogController = new CustomDialogController({
      builder: PeripheralUsbLoadingDialog({ message }),
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
  }

  @Builder
  private tabBarBuilder(title: string, index: number) {
    TabBuilder({ title, index, currentTab: this.viewModel.currentTab, currentTheme: this.currentTheme })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        this.header()
        this.tabs()
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)

      if (this.viewModel.connectionDetailDialog.visible) {
        ConnectionDetailDialog({
          selectedRecord: this.viewModel.connectionDetailDialog.record,
          historyItems: this.viewModel.connectionDetailDialog.historyItems,
          currentTheme: this.currentTheme,
          onClose: () => this.viewModel.closeConnectionDetailDialog()
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
          onExport: () => void this.handleExportPeripheralPolicyRecords(),
          onClear: () => {},
          showClear: false
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
    Column()
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    {
      InterfaceControlTab({
        usbDisabled: this.viewModel.interfaceState.usbDisabled,
        btDisabled: this.viewModel.interfaceState.btDisabled,
        wifiDisabled: this.viewModel.interfaceState.wifiDisabled,
        hdcDisabled: this.viewModel.interfaceState.hdcDisabled,
        networkDisabled: this.viewModel.interfaceState.networkDisabled,
        printerDisabled: this.viewModel.interfaceState.printerDisabled,
        microphoneDisabled: this.viewModel.interfaceState.microphoneDisabled,
        cameraDisabled: this.viewModel.interfaceState.cameraDisabled,
        usbStoragePolicyIndex: this.viewModel.interfaceState.usbStoragePolicyIndex,
        interfaceControlProcessingKey: this.viewModel.interfaceControlProcessingKey,
        usbStorageControlKey: 'usb-storage-policy',
        interfaceControlSyncToken: 0,
        currentTheme: this.currentTheme,
        hoveredPanelIndex: this.hoveredPanelIndex,
        onInterfaceToggle: (feature: string, disallow: boolean) => void this.handleInterfaceToggle(feature, disallow),
        onUsbStoragePolicyChange: (index: number) => void this.handleUsbStoragePolicyChange(index),
        onPanelHover: (isHover: boolean) => this.setPanelHover(0, isHover)
      })
    }
  }

  @Builder
  private deviceTab() {
    Column()
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    {
      DeviceRecordList({
        deviceRecords: this.viewModel.deviceRecords,
        currentTheme: this.currentTheme,
        hoveredPanelIndex: this.hoveredPanelIndex,
        onRecordClick: (record) => this.viewModel.openConnectionDetailDialog(record),
        onPanelHover: (isHover: boolean) => this.setPanelHover(1, isHover)
      })
    }
  }

  @Builder
  private policyTab() {
    Column()
      .width('100%')
      .height('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_LG })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
    {
      PolicyList({
        policyRecords: this.viewModel.peripheralPolicyRecords,
        policyListOptions: this.policyListOptions,
        currentTheme: this.currentTheme,
        hoveredPanelIndex: this.hoveredPanelIndex,
        onPolicyChange: (index: number, policyIndex: number) => {
          const record: PeripheralPolicyRecord | undefined = this.viewModel.peripheralPolicyRecords[index]
          if (record) {
            void this.handlePolicyChange(record, policyIndex)
          }
        },
        getPolicyLabel: (index: number) => this.policyListOptions[index].value,
        isUpdating: (deviceId: string) => this.viewModel.isPeripheralPolicyUpdating(deviceId.toUpperCase()),
        onPanelHover: (isHover: boolean) => this.setPanelHover(2, isHover)
      })
    }
  }

  private async handleInterfaceToggle(feature: string, disallow: boolean): Promise<void> {
    this.viewModel.interfaceControlProcessingKey = feature
    const success = await this.viewModel.toggleInterface(feature, disallow)
    this.viewModel.interfaceControlProcessingKey = ''
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        this.showAdminRequiredDialog('设置接口策略')
      } else {
        this.showResultDialog('failure', this.viewModel.errorMessage || '接口控制失败')
      }
    }
  }

  private async handleUsbStoragePolicyChange(index: number): Promise<void> {
    this.viewModel.interfaceControlProcessingKey = 'usb-storage-policy'
    const success = await this.runUsbOperationWithLoading('正在设置 USB 存储策略，请稍候', async () => await this.viewModel.setUsbStoragePolicy(index))
    this.viewModel.interfaceControlProcessingKey = ''
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        this.showAdminRequiredDialog('设置 USB 存储策略')
      } else {
        this.showResultDialog('failure', this.viewModel.errorMessage || '设置 USB 存储策略失败')
      }
    }
  }

  private async handlePolicyChange(record: PeripheralPolicyRecord, policyIndex: number): Promise<void> {
    const success = await this.viewModel.handlePeripheralPolicyChange(record.deviceId, record.deviceType, policyIndex)
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        this.showAdminRequiredDialog('修改设备策略')
      } else {
        this.showResultDialog('failure', this.viewModel.errorMessage || '修改设备策略失败')
      }
    }
  }

  private async handleExportConnectionHistory(): Promise<void> {
    const success = await this.viewModel.exportConnectionHistory()
    if (success) {
      this.showConnectionHistoryExportSuccessDialog()
    } else {
      this.showConnectionHistoryExportFailureDialog(this.viewModel.errorMessage ?? undefined)
    }
  }

  private async handleExportPeripheralPolicyRecords(): Promise<void> {
    const success = await this.viewModel.exportPeripheralPolicyRecords()
    if (success) {
      this.showPolicyRecordExportSuccessDialog()
    } else {
      this.showPolicyRecordExportFailureDialog(this.viewModel.errorMessage ?? undefined)
    }
  }

  private showClearHistoryConfirmDialog(): void {
    if (this.viewModel.deviceRecords.length === 0) {
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

  private async clearConnectionHistory(): Promise<void> {
    try {
      await PeripheralTraceRepository.init(getContext(this) as common.UIAbilityContext)
      const success = await PeripheralTraceRepository.clearAll()
      if (!success) {
        this.showResultDialog('failure', '清理未完成，请稍后重试')
        return
      }
      this.viewModel.closeConnectionDetailDialog()
      this.viewModel.reloadDeviceRecords()
      this.showResultDialog('success', '历史记录已清理')
    } catch (err) {
      hilog.error(DOMAIN, TAG, `clearConnectionHistory failed: ${JSON.stringify(err)}`)
      this.showResultDialog('failure', '清理未完成，请稍后重试')
    }
  }
}

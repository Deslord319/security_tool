import { common } from '@kit.AbilityKit'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AddBlacklistDialog } from '../components/AddBlacklistDialog'
import { AddWhitelistDialog } from '../components/AddWhitelistDialog'
import { BackNavButton } from '../components/BackNavButton'
import { EmptyStatePanel } from '../components/EmptyStatePanel'
import { ResultMessageBox, ResultMessageStatus } from '../components/ResultMessageBox'
import { ConnectionDetailDialog } from '../components/peripheral/ConnectionDetailDialog'
import { DeviceRecordList } from '../components/peripheral/DeviceRecordList'
import { InterfaceControlTab } from '../components/peripheral/InterfaceControlTab'
import { PageHeaderActions } from '../components/peripheral/PageHeaderActions'
import { TabBuilder } from '../components/peripheral/TabBuilder'
import { AppColors, AppStyles } from '../constants/AppConstants'
import {
  formatUsbDeviceId,
  getPeripheralTypeLabel,
  PeripheralBlacklistTemplate,
  PeripheralPolicyRecord,
  PeripheralWhitelistCandidate
} from '../models/DataModels'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
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

interface PolicyOption {
  value: string
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
  private usbWhitelistDialogController: CustomDialogController = new CustomDialogController({
    builder: AddWhitelistDialog({
      mode: 'usb',
      getCandidates: (): PeripheralWhitelistCandidate[] => this.viewModel.getUsbWhitelistCandidates(),
      emptyHint: '暂无可添加的 USB 设备，请先连接设备或使用手动录入。',
      onConfirmUsb: (vendorId: number, productId: number, _remark: string) => void this.handleAddUsbWhitelist(vendorId, productId)
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })
  private btWhitelistDialogController: CustomDialogController = new CustomDialogController({
    builder: AddWhitelistDialog({
      mode: 'bluetooth',
      getCandidates: (): PeripheralWhitelistCandidate[] => this.viewModel.getBluetoothWhitelistCandidates(),
      emptyHint: '暂无蓝牙候选设备，请先产生连接记录或使用手动录入。',
      onConfirmBluetooth: (mac: string, _remark: string) => void this.handleAddBluetoothWhitelist(mac)
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })
  private blacklistDialogController: CustomDialogController = new CustomDialogController({
    builder: AddBlacklistDialog({
      getTemplates: (): PeripheralBlacklistTemplate[] => this.viewModel.getUsbBlacklistTemplates(),
      onConfirm: (baseClass: number, subClass: number, protocol: number, _desc: string) => void this.handleAddUsbBlacklist(baseClass, subClass, protocol)
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

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
    this.hoveredPanelIndex = isHover ? index : -1
  }

  private handleTabChange(index: number): void {
    this.viewModel.switchToTab(index)
  }

  @Builder
  private tabBarBuilder(title: string, index: number) {
    TabBuilder({ title, index, currentTab: this.viewModel.currentTab, currentTheme: this.currentTheme })
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        this.header()
        this.tabs()
      }
      .width('100%')
      .height('100%')
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
  private adminBanner(scope: string) {
    if (!this.viewModel.adminState.activated) {
      Row({ space: 10 }) {
        Text('!')
          .width(18)
          .textAlign(TextAlign.Center)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_TEXT)
        Text(`${scope}需要先激活企业管理员：${this.viewModel.adminState.enableCommand}`)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
          .layoutWeight(1)
      }
      .width('100%')
      .padding(14)
      .backgroundColor(AppColors.getColors(this.currentTheme).TAG_ORANGE_BG)
      .borderRadius(AppStyles.RADIUS_LG)
    }
  }

  @Builder
  private interfaceTab() {
    Column({ space: 12 }) {
      this.adminBanner('接口控制、USB 存储策略和设备访问策略')
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
    .width('100%')
    .height('100%')
  }

  @Builder
  private deviceTab() {
    DeviceRecordList({
      deviceRecords: this.viewModel.deviceRecords,
      currentTheme: this.currentTheme,
      hoveredPanelIndex: this.hoveredPanelIndex,
      onRecordClick: (record) => this.viewModel.openConnectionDetailDialog(record),
      onPanelHover: (isHover: boolean) => this.setPanelHover(1, isHover)
    })
  }

  @Builder
  private policyTab() {
    Scroll() {
      Column({ space: 16 }) {
        this.adminBanner('黑白名单和设备访问策略')
        this.policyTable()
        this.usbWhitelistCard()
        this.bluetoothWhitelistCard()
        this.usbBlacklistCard()
      }
      .width('100%')
      .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: AppStyles.PADDING_MD, bottom: AppStyles.PADDING_LG })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private policyTable() {
    Column({ space: 0 }) {
      Row() {
        Text('设备访问策略').fontSize(AppStyles.FONT_SIZE_SUBTITLE).fontWeight(FontWeight.Medium).fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        Blank()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 12 })

      if (this.viewModel.peripheralPolicyRecords.length === 0) {
        EmptyStatePanel({
          title: '暂无可管理的 USB 设备记录',
          description: '设备接入后会显示在这里，允许设置允许接入或禁止访问策略。',
          radius: AppStyles.RADIUS_LG,
          verticalPadding: 24
        })
      } else {
        Row({ space: 12 }) {
          Text('设备名称').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(1.8)
          Text('设备类型').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(1.1)
          Text('设备标识').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(1.6)
          Text('最近连接时间').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(1.3)
          Text('当前策略').fontSize(AppStyles.FONT_SIZE_SMALL).layoutWeight(1.2)
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 14, bottom: 14 })
        .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)

        ForEach(this.viewModel.peripheralPolicyRecords, (record: PeripheralPolicyRecord, index: number) => {
          Row({ space: 12 }) {
            Text(record.deviceName).fontSize(AppStyles.FONT_SIZE_BODY).layoutWeight(1.8).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(getPeripheralTypeLabel(record.deviceType)).fontSize(AppStyles.FONT_SIZE_CAPTION).layoutWeight(1.1)
            Text(record.deviceId).fontSize(AppStyles.FONT_SIZE_CAPTION).layoutWeight(1.6).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(record.lastSeenLabel).fontSize(AppStyles.FONT_SIZE_CAPTION).layoutWeight(1.3)
            Select(this.policyListOptions as SelectOption[])
              .selected(record.policyIndex)
              .value(this.policyListOptions[record.policyIndex].value)
              .font({ size: AppStyles.FONT_SIZE_CAPTION })
              .selectedOptionFont({ size: AppStyles.FONT_SIZE_CAPTION })
              .optionFont({ size: AppStyles.FONT_SIZE_CAPTION })
              .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
              .borderRadius(AppStyles.RADIUS_SM)
              .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER, style: BorderStyle.Solid })
              .layoutWeight(1.2)
              .enabled(!this.viewModel.isPeripheralPolicyUpdating(record.deviceId.toUpperCase()))
              .opacity(this.viewModel.isPeripheralPolicyUpdating(record.deviceId.toUpperCase()) ? 0.6 : 1)
              .onSelect((policyIndex: number) => void this.handlePolicyChange(record, policyIndex))
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          .backgroundColor(index % 2 === 0 ? AppColors.getColors(this.currentTheme).BG_CARD : AppColors.getColors(this.currentTheme).BG_PAGE)
        }, (record: PeripheralPolicyRecord) => `${record.deviceId}-${record.policyIndex}-${this.viewModel.peripheralPolicyRenderVersion}`)
      }
    }
    .width('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .clip(true)
    .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
  }

  @Builder
  private usbWhitelistCard() {
    Column({ space: 12 }) {
      Row() {
        Text('USB 白名单').fontSize(AppStyles.FONT_SIZE_SUBTITLE).fontWeight(FontWeight.Medium)
        Blank()
        Button('添加 USB 白名单').fontSize(AppStyles.FONT_SIZE_CAPTION).fontColor(Color.White).backgroundColor(AppColors.BRAND_PRIMARY).borderRadius(AppStyles.RADIUS_MD).height(36).onClick(() => this.usbWhitelistDialogController.open())
      }
      .width('100%')

      if (this.viewModel.whitelistBlacklistState.usbWhitelist.length === 0) {
        EmptyStatePanel({ title: '暂无 USB 白名单', description: '添加后将显示在这里。', radius: AppStyles.RADIUS_LG, verticalPadding: 20 })
      } else {
        Column({ space: 8 }) {
          ForEach(this.viewModel.whitelistBlacklistState.usbWhitelist, (device: edmUsbManager.UsbDeviceId) => {
            this.removableItem(`USB ${formatUsbDeviceId(device.vendorId, device.productId)}`, '允许接入', () => void this.handleRemoveUsbWhitelist(device))
          }, (device: edmUsbManager.UsbDeviceId) => `${device.vendorId}-${device.productId}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
  }

  @Builder
  private bluetoothWhitelistCard() {
    Column({ space: 12 }) {
      Row() {
        Text('蓝牙白名单').fontSize(AppStyles.FONT_SIZE_SUBTITLE).fontWeight(FontWeight.Medium)
        Blank()
        Button('添加蓝牙白名单').fontSize(AppStyles.FONT_SIZE_CAPTION).fontColor(Color.White).backgroundColor(AppColors.BRAND_PRIMARY).borderRadius(AppStyles.RADIUS_MD).height(36).onClick(() => this.btWhitelistDialogController.open())
      }
      .width('100%')

      if (this.viewModel.whitelistBlacklistState.btWhitelist.length === 0) {
        EmptyStatePanel({ title: '暂无蓝牙白名单', description: '产生蓝牙连接记录后可直接从候选列表添加。', radius: AppStyles.RADIUS_LG, verticalPadding: 20 })
      } else {
        Column({ space: 8 }) {
          ForEach(this.viewModel.whitelistBlacklistState.btWhitelist, (mac: string) => {
            this.removableItem(`MAC: ${mac}`, '允许接入', () => void this.handleRemoveBluetoothWhitelist(mac))
          }, (mac: string) => mac)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
  }

  @Builder
  private usbBlacklistCard() {
    Column({ space: 12 }) {
      Row() {
        Text('USB 黑名单').fontSize(AppStyles.FONT_SIZE_SUBTITLE).fontWeight(FontWeight.Medium)
        Blank()
        Button('添加 USB 黑名单').fontSize(AppStyles.FONT_SIZE_CAPTION).fontColor(Color.White).backgroundColor(AppColors.BRAND_PRIMARY).borderRadius(AppStyles.RADIUS_MD).height(36).onClick(() => this.blacklistDialogController.open())
      }
      .width('100%')

      if (this.viewModel.whitelistBlacklistState.usbBlacklist.length === 0) {
        EmptyStatePanel({ title: '暂无 USB 黑名单', description: '添加后符合类型的 USB 设备将被禁止访问。', radius: AppStyles.RADIUS_LG, verticalPadding: 20 })
      } else {
        Column({ space: 8 }) {
          ForEach(this.viewModel.whitelistBlacklistState.usbBlacklist, (deviceType: edmUsbManager.UsbDeviceType) => {
            this.removableItem(`Base ${this.hex(deviceType.baseClass)} / Sub ${this.hex(deviceType.subClass)} / Protocol ${this.hex(deviceType.protocol)}`, '禁止访问', () => void this.handleRemoveUsbBlacklist(deviceType))
          }, (deviceType: edmUsbManager.UsbDeviceType) => `${deviceType.baseClass}-${deviceType.subClass}-${deviceType.protocol}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_CARD)
    .borderRadius(AppStyles.RADIUS_LG)
    .border({ width: 1, color: AppColors.getColors(this.currentTheme).BORDER })
  }

  @Builder
  private removableItem(title: string, tagText: string, onRemove: () => void) {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(title).fontSize(AppStyles.FONT_SIZE_BODY).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(tagText)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TAG_RED_TEXT)
          .backgroundColor(AppColors.getColors(this.currentTheme).TAG_RED_BG)
          .borderRadius(AppStyles.RADIUS_SM)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Button('移除').fontSize(AppStyles.FONT_SIZE_CAPTION).height(34).borderRadius(AppStyles.RADIUS_MD).backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE).onClick(() => onRemove())
    }
    .width('100%')
    .padding(12)
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
    .borderRadius(AppStyles.RADIUS_MD)
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

  private async handleAddUsbWhitelist(vendorId: number, productId: number): Promise<void> {
    const success = await this.viewModel.addToUsbWhitelist(vendorId, productId)
    if (!success) {
      this.viewModel.adminState.activated ? this.showResultDialog('failure', this.viewModel.errorMessage || '添加 USB 白名单失败') : this.showAdminRequiredDialog('添加 USB 白名单')
      return
    }
    this.showResultDialog('success', 'USB 白名单已添加')
  }

  private async handleRemoveUsbWhitelist(device: edmUsbManager.UsbDeviceId): Promise<void> {
    const success = await this.viewModel.removeFromUsbWhitelist(device)
    if (!success) {
      this.viewModel.adminState.activated ? this.showResultDialog('failure', this.viewModel.errorMessage || '移除 USB 白名单失败') : this.showAdminRequiredDialog('移除 USB 白名单')
      return
    }
    this.showResultDialog('success', 'USB 白名单已移除')
  }

  private async handleAddBluetoothWhitelist(mac: string): Promise<void> {
    const success = await this.viewModel.addToBluetoothWhitelist(mac)
    if (!success) {
      this.viewModel.adminState.activated ? this.showResultDialog('failure', this.viewModel.errorMessage || '添加蓝牙白名单失败') : this.showAdminRequiredDialog('添加蓝牙白名单')
      return
    }
    this.showResultDialog('success', '蓝牙白名单已添加')
  }

  private async handleRemoveBluetoothWhitelist(mac: string): Promise<void> {
    const success = await this.viewModel.removeFromBluetoothWhitelist(mac)
    if (!success) {
      this.viewModel.adminState.activated ? this.showResultDialog('failure', this.viewModel.errorMessage || '移除蓝牙白名单失败') : this.showAdminRequiredDialog('移除蓝牙白名单')
      return
    }
    this.showResultDialog('success', '蓝牙白名单已移除')
  }

  private async handleAddUsbBlacklist(baseClass: number, subClass: number, protocol: number): Promise<void> {
    const success = await this.viewModel.addToUsbBlacklist(baseClass, subClass, protocol)
    if (!success) {
      this.viewModel.adminState.activated ? this.showResultDialog('failure', this.viewModel.errorMessage || '添加 USB 黑名单失败') : this.showAdminRequiredDialog('添加 USB 黑名单')
      return
    }
    this.showResultDialog('success', 'USB 黑名单已添加')
  }

  private async handleRemoveUsbBlacklist(deviceType: edmUsbManager.UsbDeviceType): Promise<void> {
    const success = await this.viewModel.removeFromUsbBlacklist(deviceType)
    if (!success) {
      this.viewModel.adminState.activated ? this.showResultDialog('failure', this.viewModel.errorMessage || '移除 USB 黑名单失败') : this.showAdminRequiredDialog('移除 USB 黑名单')
      return
    }
    this.showResultDialog('success', 'USB 黑名单已移除')
  }

  private async handleExportConnectionHistory(): Promise<void> {
    const success = await this.viewModel.exportConnectionHistory()
    success ? this.showConnectionHistoryExportSuccessDialog() : this.showConnectionHistoryExportFailureDialog(this.viewModel.errorMessage ?? undefined)
  }

  private async handleExportPeripheralPolicyRecords(): Promise<void> {
    const success = await this.viewModel.exportPeripheralPolicyRecords()
    success ? this.showPolicyRecordExportSuccessDialog() : this.showPolicyRecordExportFailureDialog(this.viewModel.errorMessage ?? undefined)
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

  private hex(value: number): string {
    return `0x${value.toString(16).toUpperCase().padStart(2, '0')}`
  }
}

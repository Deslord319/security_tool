import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { IconTextActionButton } from '../components/IconTextActionButton'
import { SubPageHeader } from '../components/SubPageHeader'
import {
  ConnectionDetailDialog,
  ConnectionHistoryItem
} from '../components/peripheral/ConnectionDetailDialog'
import { DeviceRecordList } from '../components/peripheral/DeviceRecordList'
import { InterfaceControlTab } from '../components/peripheral/InterfaceControlTab'
import { PolicyList, PolicyOption } from '../components/peripheral/PolicyList'
import { TabBuilder } from '../components/peripheral/TabBuilder'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { PeripheralReasons } from '../constants/modules/PeripheralReasons'
import { PeripheralStrings } from '../constants/modules/PeripheralStrings'
import { PeripheralConnectionRecord, PeripheralPolicyRecord } from '../models/DataModels'
import { PeripheralService } from '../services/PeripheralService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { PeripheralRuntimeEventService } from '../services/PeripheralRuntimeEventService'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'
import { PeripheralViewModel } from '../viewmodels/PeripheralViewModel'
import { DialogService } from '../utils/DialogService'

const TAG = 'PeripheralPage'
const DOMAIN = 0x0013

@Component
struct PeripheralUsbLoadingOverlay {
  message: string = PeripheralStrings.usbLoadingMessage
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.24)')

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
      .shadow({
        radius: 18,
        color: this.currentTheme === ThemeMode.DARK ? 'rgba(0,0,0,0.32)' : 'rgba(0,0,0,0.14)',
        offsetX: 0,
        offsetY: 8
      })
    }
    .width('100%')
    .height('100%')
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
  private policyListOptions: PolicyOption[] = [
    { value: PeripheralStrings.policyOptions[0] },
    { value: PeripheralStrings.policyOptions[1] }
  ]
  @State usbLoadingVisible: boolean = false
  @State usbLoadingMessage: string = PeripheralStrings.usbLoadingMessage
  private usbLoadingOpenedAt: number = 0

  aboutToAppear() {
    void this.initViewModel()
  }

  aboutToDisappear() {
    this.closeUsbLoadingOverlay()
    this.closeDetailDialog()
    this.viewModel.onRefresh = undefined
    this.viewModel.destroy()
  }

  private async initViewModel(): Promise<void> {
    try {
      this.viewModel.onRefresh = () => {
        this.renderVersion++
      }
      let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      await PeripheralRuntimeEventService.init(context)
      await PeripheralRuntimeEventService.start()
      await this.viewModel.initialize(context)
      this.renderVersion++
    } catch (err) {
      hilog.error(DOMAIN, TAG, `initViewModel failed: ${JSON.stringify(err)}`)
      this.showResultDialog('failure', PeripheralStrings.resolveReason(PeripheralReasons.INIT_FAILED))
    }
  } 

  private showResultDialog(status: 'success' | 'failure', message: string): void {
    void DialogService.openResult(this.getUIContext(), {
      status: status,
      message: message
    })
  }

  private openUsbLoadingOverlay(message: string): void {
    this.usbLoadingMessage = message
    this.usbLoadingOpenedAt = Date.now()
    this.usbLoadingVisible = true
  }

  private closeUsbLoadingOverlay(): void {
    this.usbLoadingVisible = false
    this.usbLoadingOpenedAt = 0
  }

  private async runUsbOperationWithLoading(message: string, operation: () => Promise<boolean>): Promise<boolean> {
    this.openUsbLoadingOverlay(message)
    try {
      await new Promise<void>((resolve: () => void) => setTimeout(() => resolve(), 120))
      return await operation()
    } finally {
      const remaining = PeripheralStrings.minUsbLoadingDuration - (Date.now() - this.usbLoadingOpenedAt)
      if (remaining > 0) {
        await new Promise<void>((resolve: () => void) => setTimeout(() => resolve(), remaining))
      }
      this.closeUsbLoadingOverlay()
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

      if (this.usbLoadingVisible) {
        PeripheralUsbLoadingOverlay({
          message: this.usbLoadingMessage
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private header() {
    SubPageHeader({
      title: PeripheralStrings.pageTitle,
      subtitle: PeripheralStrings.pageSubtitle,
      currentTheme: this.currentTheme,
      onBack: () => this.onBack(),
      actions: () => {
        this.headerRightActions()
      }
    })
  }

  @Builder
  private headerRightActions() {
    if (this.viewModel.currentTab === 1) {
      this.headerActions(
        PeripheralStrings.exportHistoryLabel,
        PeripheralStrings.clearHistoryLabel,
        () => void this.handleExportConnectionHistory(),
        () => this.showClearHistoryConfirmDialog()
      )
    } else if (this.viewModel.currentTab === 2) {
      this.headerActions(
        PeripheralStrings.exportPolicyLabel,
        PeripheralStrings.clearPolicyLabel,
        () => void this.handleExportPeripheralPolicyRecords(),
        () => this.showClearPolicyRecordsConfirmDialog()
      )
    }
  }

  @Builder
  private tabs() {
    Tabs({ barPosition: BarPosition.Start, controller: this.tabsController }) {
      TabContent() { this.interfaceTab() }.tabBar(this.tabBarBuilder(PeripheralStrings.interfaceTabTitle, 0))
      TabContent() { this.deviceTab() }.tabBar(this.tabBarBuilder(PeripheralStrings.deviceTabTitle, 1))
      TabContent() { this.policyTab() }.tabBar(this.tabBarBuilder(PeripheralStrings.policyTabTitle, 2))
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
    const toggle = async (): Promise<boolean> => this.viewModel.toggleInterface(feature, disallow)
    const success = feature === PeripheralService.FEATURE_USB
      ? await this.runUsbOperationWithLoading(PeripheralStrings.usbInterfaceLoadingMessage, toggle)
      : await toggle()
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        this.showResultDialog('failure', `${PeripheralStrings.setInterfaceAction}${PeripheralStrings.adminRequiredActionSuffix}`)
      } else {
        this.showResultDialog('failure', PeripheralStrings.resolveReason(this.viewModel.reasonCode))
      }
      return
    }
    this.renderVersion++
  }

  private async handleUsbStoragePolicyChange(index: number): Promise<void> {
    const success = await this.runUsbOperationWithLoading(PeripheralStrings.usbStorageLoadingMessage, async () => {
      return await this.viewModel.setUsbStoragePolicy(index)
    })
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        this.showResultDialog('failure', `${PeripheralStrings.setUsbStorageAction}${PeripheralStrings.adminRequiredActionSuffix}`)
      } else {
        this.showResultDialog('failure', PeripheralStrings.resolveReason(this.viewModel.reasonCode))
      }
      return
    }
    this.renderVersion++
  }

  private async handlePolicyChange(record: PeripheralPolicyRecord, policyIndex: number): Promise<void> {
    const success = await this.viewModel.handlePeripheralPolicyChange(record.deviceId, record.deviceType, policyIndex)
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        this.showResultDialog('failure', `${PeripheralStrings.updatePolicyAction}${PeripheralStrings.adminRequiredActionSuffix}`)
      } else {
        this.showResultDialog('failure', PeripheralStrings.resolveReason(this.viewModel.reasonCode))
      }
      return
    }
    this.renderVersion++
  }

  private async handleExportConnectionHistory(): Promise<void> {
    const success = await this.viewModel.exportConnectionHistory()
    if (success) {
      this.showResultDialog('success', PeripheralStrings.exportHistorySuccess)
    } else {
      this.showResultDialog('failure', PeripheralStrings.resolveReason(this.viewModel.reasonCode))
    }
  }

  @Builder
  private headerActions(
    exportLabel: string,
    clearLabel: string,
    onExport: () => void,
    onClear: () => void
  ) {
    Row({ space: 8 }) {
      IconTextActionButton({
        label: exportLabel,
        icon: $r('app.media.save'),
        kind: 'primary',
        onTap: onExport
      })

      IconTextActionButton({
        label: clearLabel,
        icon: $r('app.media.trash'),
        kind: 'danger',
        onTap: onClear
      })
    }
  }

  private async handleExportPeripheralPolicyRecords(): Promise<void> {
    const success = await this.viewModel.exportPeripheralPolicyRecords()
    if (success) {
      this.showResultDialog('success', PeripheralStrings.exportPolicySuccess)
    } else {
      this.showResultDialog('failure', PeripheralStrings.resolveReason(this.viewModel.reasonCode))
    }
  }

  private showClearHistoryConfirmDialog(): void {
    if (this.viewModel.records.records.length === 0) {
      this.showResultDialog('failure', PeripheralStrings.emptyHistoryToClear)
      return
    }
    void DialogService.openConfirm(this.getUIContext(), {
      title: PeripheralStrings.clearHistoryLabel,
      message: PeripheralStrings.clearHistoryMessage,
      confirmText: CommonStrings.actionClear,
      cancelText: CommonStrings.actionCancel,
      onConfirm: () => void this.clearConnectionHistory()
    })
  }

  private showClearPolicyRecordsConfirmDialog(): void {
    if (this.viewModel.policy.records.length === 0) {
      this.showResultDialog('failure', PeripheralStrings.emptyPolicyToClear)
      return
    }
    void DialogService.openConfirm(this.getUIContext(), {
      title: PeripheralStrings.clearPolicyLabel,
      message: PeripheralStrings.clearPolicyMessage,
      confirmText: CommonStrings.actionDelete,
      cancelText: CommonStrings.actionCancel,
      onConfirm: () => void this.clearPolicyRecords()
    })
  }

  private async clearConnectionHistory(): Promise<void> {
    try {
      await PeripheralTraceRepository.init(this.getUIContext().getHostContext() as common.UIAbilityContext)
      const success = await PeripheralTraceRepository.clearAll()
      if (!success) {
        this.showResultDialog('failure', PeripheralStrings.clearFailed)
        return
      }
      this.closeDetailDialog()
      this.viewModel.reloadDeviceRecords()
      this.renderVersion++
      this.showResultDialog('success', PeripheralStrings.clearHistorySuccess)
    } catch (err) {
      hilog.error(DOMAIN, TAG, `clearConnectionHistory failed: ${JSON.stringify(err)}`)
      this.showResultDialog('failure', PeripheralStrings.clearFailed)
    }
  }

  private async clearPolicyRecords(): Promise<void> {
    const success = await this.viewModel.clearPeripheralPolicyRecords()
    if (!success) {
      this.showResultDialog('failure', PeripheralStrings.clearFailed)
      return
    }
    this.closeDetailDialog()
    this.renderVersion++
    this.showResultDialog('success', PeripheralStrings.clearPolicySuccess)
  }
}

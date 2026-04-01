import { LogUtils } from '../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { IconTextActionButton } from '../components/IconTextActionButton'
import { SubPageHeader } from '../components/SubPageHeader'
import {
  ConnectionDetailDialog,
  ConnectionHistoryItem
} from '../components/peripheral/ConnectionDetailDialog'
import { DeviceRecordList } from '../components/peripheral/DeviceRecordList'
import { InterfaceControlTab } from '../components/peripheral/InterfaceControlTab'
import { PolicyList, PolicyOption } from '../components/peripheral/PolicyList'
import { AppColors, AppStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { PeripheralStrings } from '../constants/modules/PeripheralStrings'
import { PeripheralConnectionRecord, PeripheralPolicyRecord } from '../models/DataModels'
import { PeripheralService } from '../services/PeripheralService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { PeripheralRuntimeEventService } from '../services/PeripheralRuntimeEventService'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'
import { ExportMessageUtils } from '../utils/ExportMessageUtils'
import { PeripheralViewModel } from '../viewmodels/PeripheralViewModel'
import { DialogService } from '../utils/DialogService'
import { TimedLoadingDialogRunner } from '../utils/TimedLoadingDialogRunner'
import { CommonLoadingDialog } from '../components/CommonLoadingDialog'

const TAG = 'PeripheralPage'
const USB_INTERFACE_LOADING_RENDER_READY_DELAY_MS = 180

@Component
export struct PeripheralPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State viewModel: PeripheralViewModel = new PeripheralViewModel()
  @State currentTabIndex: number = 0
  @State hoveredPanelIndex: number = -1
  @State deviceRecords: PeripheralConnectionRecord[] = []
  @State policyRecords: PeripheralPolicyRecord[] = []
  @State detailRecord: PeripheralConnectionRecord | null = null
  @State detailHistoryItems: ConnectionHistoryItem[] = [] 

  private tabsController: TabsController = new TabsController()
  private policyListOptions: PolicyOption[] = [
    { value: PeripheralStrings.policyOptions[0] },
    { value: PeripheralStrings.policyOptions[1] }
  ]
  private detailDialogController?: CustomDialogController
  private readonly usbLoadingRunner: TimedLoadingDialogRunner = new TimedLoadingDialogRunner(TAG)

  aboutToAppear() {
    let runtimeStatus = PeripheralRuntimeEventService.getStatus()
    LogUtils.info(TAG,
      `page enter: tab=${this.currentTabIndex}, records=${this.deviceRecords.length}, policyRecords=${this.policyRecords.length}, runtimeRunning=${runtimeStatus.running}, usbRuntime=${runtimeStatus.capabilities.usbRuntimeEvents}, bluetoothRuntime=${runtimeStatus.capabilities.bluetoothRuntimeEvents}`
    )
    void this.initViewModel()
  }

  aboutToDisappear() {
    this.usbLoadingRunner.closeIfOpen('page-disappear')
    this.closeDetailDialog()
    this.viewModel.onRefresh = undefined
    this.viewModel.destroy()
    let runtimeStatus = PeripheralRuntimeEventService.getStatus()
    LogUtils.info(TAG,
      `page exit: tab=${this.currentTabIndex}, records=${this.deviceRecords.length}, policyRecords=${this.policyRecords.length}, runtimeRunning=${runtimeStatus.running}, usbRuntime=${runtimeStatus.capabilities.usbRuntimeEvents}, bluetoothRuntime=${runtimeStatus.capabilities.bluetoothRuntimeEvents}`
    )
  }

  private async initViewModel(): Promise<void> {
    try {
      this.viewModel.onRefresh = () => this.syncViewState()
      let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      await PeripheralRuntimeEventService.init(context)
      await PeripheralRuntimeEventService.start()
      await this.viewModel.initialize(context)
      this.currentTabIndex = this.viewModel.currentTab
      this.syncViewState()
    } catch (err) {
      LogUtils.error(TAG, `initViewModel failed: ${JSON.stringify(err)}`)
      DialogService.openFailure(this.getUIContext(), PeripheralStrings.resolveReason(PeripheralStrings.INIT_FAILED))
    }
  }

  private setPanelHover(index: number, isHover: boolean): void {
    HoverUtils.animate(() => {
      this.hoveredPanelIndex = isHover ? index : -1
    })
  }

  private handleTabChange(index: number): void {
    this.currentTabIndex = index
    this.viewModel.switchToTab(index)
  }

  private syncDetailDialogState(): void {
    this.detailRecord = this.viewModel.records.connectionDetailDialog.record
    this.detailHistoryItems = [...this.viewModel.records.connectionDetailDialog.historyItems]
  }

  private syncViewState(): void {
    this.deviceRecords = [...this.viewModel.records.records]
    this.policyRecords = [...this.viewModel.policy.records]
    this.syncDetailDialogState()
  }

  private openDetailDialog(record: PeripheralConnectionRecord): void {
    this.closeDetailDialogController()
    this.viewModel.openConnectionDetailDialog(record)
    this.syncViewState()
    if (!this.detailRecord) {
      return
    }
    try {
      this.detailDialogController = new CustomDialogController({
        builder: ConnectionDetailDialog({
          controller: this.detailDialogController,
          selectedRecord: this.detailRecord as PeripheralConnectionRecord,
          historyItems: this.detailHistoryItems,
          onClose: () => this.closeDetailDialog()
        }),
        alignment: DialogAlignment.Center,
        autoCancel: true,
        customStyle: true,
        isModal: true,
        maskColor: AppColors.OVERLAY_BACKGROUND,
        cancel: () => {
          this.detailDialogController = undefined
          this.detailRecord = null
          this.detailHistoryItems = []
          this.viewModel.closeConnectionDetailDialog()
        }
      })
      this.detailDialogController.open()
    } catch (err) {
      LogUtils.warn(TAG, `openDetailDialog failed: ${JSON.stringify(err)}`)
      this.closeDetailDialog()
    }
  }

  private closeDetailDialogController(): void {
    try {
      this.detailDialogController?.close()
    } catch (_err) {
    } finally {
      this.detailDialogController = undefined
    }
  }

  private closeDetailDialog(): void {
    this.closeDetailDialogController()
    this.viewModel.closeConnectionDetailDialog()
    this.detailRecord = null
    this.detailHistoryItems = []
  }

  private createUsbLoadingDialogController(message: string): CustomDialogController {
    return new CustomDialogController({
      builder: CommonLoadingDialog({
        message: message
      }),
      alignment: DialogAlignment.Center,
      autoCancel: false,
      customStyle: true
    })
  }

  @Builder
  private tabBarBuilder(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(index === this.currentTabIndex ? AppColors.BRAND_PRIMARY : AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(index === this.currentTabIndex ? 1 : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
    }
    .padding({ left: AppStyles.SPACING_TAB_BAR_ITEM_HORIZONTAL, right: AppStyles.SPACING_TAB_BAR_ITEM_HORIZONTAL, top: AppStyles.SPACING_TAB_BAR_ITEM_VERTICAL, bottom: AppStyles.SPACING_TAB_BAR_ITEM_VERTICAL })
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
    if (this.currentTabIndex === 1) {
      this.headerActions(
        PeripheralStrings.exportHistoryLabel,
        PeripheralStrings.clearHistoryLabel,
        () => void this.handleExportConnectionHistory(),
        () => this.showClearHistoryConfirmDialog()
      )
    } else if (this.currentTabIndex === 2) {
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
        currentTheme: this.currentTheme,
        hoveredPanelIndex: this.hoveredPanelIndex,
        onInterfaceToggle: (feature: string, disallow: boolean) => void this.handleInterfaceToggle(feature, disallow),
        onUsbStoragePolicyChange: async (index: number): Promise<boolean> => this.handleUsbStoragePolicyChange(index),
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
        deviceRecords: this.deviceRecords,
        currentTheme: this.currentTheme,
        hoveredPanelIndex: this.hoveredPanelIndex,
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
        policyRecords: this.policyRecords,
        policyListOptions: this.policyListOptions,
        currentTheme: this.currentTheme,
        hoveredPanelIndex: this.hoveredPanelIndex,
        onPolicyChange: (index: number, policyIndex: number) => {
          const record: PeripheralPolicyRecord | undefined = this.policyRecords[index]
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
      ? await this.usbLoadingRunner.run(
        'peripheral-usb-interface',
        PeripheralStrings.usbInterfaceLoadingMessage,
        async (): Promise<boolean> => {
          LogUtils.info(TAG, `usb interface switch start: disallow=${disallow}`)
          return await toggle()
        },
        (dialogMessage: string): CustomDialogController => this.createUsbLoadingDialogController(dialogMessage),
        500,
        USB_INTERFACE_LOADING_RENDER_READY_DELAY_MS
      )
      : await toggle()
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        DialogService.openFailure(this.getUIContext(), `${PeripheralStrings.setInterfaceAction}${PeripheralStrings.adminRequiredActionSuffix}`)
      } else {
        DialogService.openFailure(this.getUIContext(), PeripheralStrings.resolveReason(this.viewModel.reasonCode))
      }
      return
    }
    if (feature === PeripheralService.FEATURE_USB) {
      LogUtils.info(TAG, `usb interface switch success: disallow=${disallow}`)
    }
  }

  private async handleUsbStoragePolicyChange(index: number): Promise<boolean> {
    const success = await this.usbLoadingRunner.run(
      'peripheral-usb-storage',
      PeripheralStrings.usbStorageLoadingMessage,
      async (): Promise<boolean> => {
        LogUtils.info(TAG, `usb storage policy switch start: index=${index}`)
        return await this.viewModel.setUsbStoragePolicy(index)
      },
      (dialogMessage: string): CustomDialogController => this.createUsbLoadingDialogController(dialogMessage)
    )
    if (!success) {
      LogUtils.warn(TAG, `usb storage policy switch failed: index=${index}, reason=${this.viewModel.reasonCode ?? 'unknown'}`)
      if (!this.viewModel.adminState.activated) {
        DialogService.openFailure(this.getUIContext(), `${PeripheralStrings.setUsbStorageAction}${PeripheralStrings.adminRequiredActionSuffix}`)
      } else {
        DialogService.openFailure(this.getUIContext(), PeripheralStrings.resolveReason(this.viewModel.reasonCode))
      }
      return false
    }
    LogUtils.info(TAG, `usb storage policy switch success: index=${index}`)
    return true
  }

  private async handlePolicyChange(record: PeripheralPolicyRecord, policyIndex: number): Promise<void> {
    const success = await this.viewModel.handlePeripheralPolicyChange(
      record.deviceId,
      record.deviceType,
      record.deviceName,
      policyIndex
    )
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        DialogService.openFailure(this.getUIContext(), `${PeripheralStrings.updatePolicyAction}${PeripheralStrings.adminRequiredActionSuffix}`)
      } else {
        DialogService.openFailure(this.getUIContext(), PeripheralStrings.resolveReason(this.viewModel.reasonCode))
      }
      return
    }
  }

  private async handleExportConnectionHistory(): Promise<void> {
    const result = await this.viewModel.exportConnectionHistory()
    if (result.success) {
      DialogService.openSuccess(
        this.getUIContext(),
        ExportMessageUtils.buildExportSuccessText(result.fileName ?? 'peripheral_connection_history.csv')
      )
    } else {
      DialogService.openFailure(this.getUIContext(), PeripheralStrings.resolveReason(this.viewModel.reasonCode))
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
    const result = await this.viewModel.exportPeripheralPolicyRecords()
    if (result.success) {
      DialogService.openSuccess(
        this.getUIContext(),
        ExportMessageUtils.buildExportSuccessText(result.fileName ?? 'peripheral_policy_list.csv')
      )
    } else {
      DialogService.openFailure(this.getUIContext(), PeripheralStrings.resolveReason(this.viewModel.reasonCode))
    }
  }

  private showClearHistoryConfirmDialog(): void {
    if (this.deviceRecords.length === 0) {
      DialogService.openFailure(this.getUIContext(), PeripheralStrings.emptyHistoryToClear)
      return
    }
    DialogService.openConfirm(this.getUIContext(), {
      title: PeripheralStrings.clearHistoryLabel,
      message: PeripheralStrings.clearHistoryMessage,
      confirmText: CommonStrings.actionClear,
      cancelText: CommonStrings.actionCancel,
      onConfirm: () => void this.clearConnectionHistory()
    })
  }

  private showClearPolicyRecordsConfirmDialog(): void {
    if (this.policyRecords.length === 0) {
      DialogService.openFailure(this.getUIContext(), PeripheralStrings.emptyPolicyToClear)
      return
    }
    DialogService.openConfirm(this.getUIContext(), {
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
        DialogService.openFailure(this.getUIContext(), PeripheralStrings.clearFailed)
        return
      }
      this.closeDetailDialog()
      this.viewModel.reloadDeviceRecords()
      DialogService.openSuccess(this.getUIContext(), PeripheralStrings.clearHistorySuccess)
    } catch (err) {
      LogUtils.error(TAG, `clearConnectionHistory failed: ${JSON.stringify(err)}`)
      DialogService.openFailure(this.getUIContext(), PeripheralStrings.clearFailed)
    }
  }

  private async clearPolicyRecords(): Promise<void> {
    const success = await this.viewModel.clearPeripheralPolicyRecords()
    if (!success) {
      DialogService.openFailure(this.getUIContext(), PeripheralStrings.clearFailed)
      return
    }
    this.closeDetailDialog()
    this.syncViewState()
    DialogService.openSuccess(this.getUIContext(), PeripheralStrings.clearPolicySuccess)
  }
}


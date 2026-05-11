import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { ConnectionDetailDialog } from '../../../components/peripheral/connection-record/ConnectionDetailDialog'
import { DeviceRecordList } from '../../../components/peripheral/connection-record/DeviceRecordList'
import { InterfaceControlTab } from '../../../components/peripheral/interface-control/InterfaceControlTab'
import { PolicyList } from '../../../components/peripheral/device-policy/PolicyList'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ActionText, ModuleText } from '../../../constants/StringCatalog'
import {
  PERIPHERAL_ADMIN_REQUIRED_ACTION_SUFFIX,
  PeripheralActionStrings,
  PeripheralEmptyStateStrings,
  PeripheralExportStrings,
  PeripheralLoadingStrings,
  PeripheralOptionStrings,
  PeripheralPageStrings,
  PeripheralPolicyOptionIndexes,
  PeripheralReasonCodes,
  PeripheralTabIndexes,
  resolvePeripheralReason
} from '../../../constants/modules/PeripheralStrings'
import {
  PeripheralConnectionRecord,
  PeripheralPolicyRecord
} from '../../../models/PeripheralModels'
import { PeripheralService } from '../../../services/peripheral/interface-control/PeripheralService'
import { ThemeMode } from '../../../theme/ThemeColors'
import { HoverUtils } from '../../../utils/HoverUtils'
import { ExportMessageUtils } from '../../../utils/ExportMessageUtils'
import { PeripheralViewModel } from '../../../viewmodels/peripheral/overview/PeripheralViewModel'
import { DialogService } from '../../../utils/DialogService'
import { TimedLoadingDialogRunner } from '../../../utils/TimedLoadingDialogRunner'

const TAG = 'PeripheralPage'

@ComponentV2
export struct PeripheralPage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Param viewModel: PeripheralViewModel = new PeripheralViewModel()
  @Event onBack: () => void = () => {}
  @Local currentTabIndex: number = PeripheralTabIndexes.INTERFACE_CONTROL
  @Local hoveredPanelIndex: number = -1

  private policyListOptions: SelectOption[] = [
    { value: PeripheralOptionStrings.POLICY_OPTIONS[PeripheralPolicyOptionIndexes.ALLOW] },
    { value: PeripheralOptionStrings.POLICY_OPTIONS[PeripheralPolicyOptionIndexes.DENY] }
  ]
  private detailDialogController?: CustomDialogController
  private readonly usbLoadingRunner: TimedLoadingDialogRunner = new TimedLoadingDialogRunner(TAG)

  aboutToAppear() {
    this.syncCurrentTabFromViewModel()
    LogUtils.info(TAG,
      `page enter: tab=${this.currentTabIndex}, records=${this.viewModel.records.state.records.length}, policyRecords=${this.viewModel.policy.state.records.length}`
    )
    this.initViewModel()
  }

  aboutToDisappear() {
    this.usbLoadingRunner.closeIfOpen('page-disappear')
    this.closeDetailDialog()
    this.viewModel.destroy()
    LogUtils.info(TAG,
      `page exit: tab=${this.currentTabIndex}, records=${this.viewModel.records.state.records.length}, policyRecords=${this.viewModel.policy.state.records.length}`
    )
  }

  private async initViewModel(): Promise<void> {
    try {
      let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      await this.viewModel.initialize(context)
      this.syncCurrentTabFromViewModel()
    } catch (err) {
      LogUtils.error(TAG, `initViewModel failed: ${JSON.stringify(err)}`)
      DialogService.openFailure(this.getUIContext(), resolvePeripheralReason(PeripheralReasonCodes.INIT_FAILED))
    }
  }

  private setPanelHover(index: number, isHover: boolean): void {
    HoverUtils.animate(this.getUIContext(), () => {
      this.hoveredPanelIndex = isHover ? index : -1
    })
  }

  private handleTabChange(index: number): void {
    this.currentTabIndex = index
    this.viewModel.switchToTab(index)
  }

  private syncCurrentTabFromViewModel(): void {
    this.currentTabIndex = this.normalizeTabIndex(this.viewModel.currentTab)
  }

  private normalizeTabIndex(index: number): number {
    return PeripheralTabIndexes.normalize(index)
  }

  private openDetailDialog(record: PeripheralConnectionRecord): void {
    this.detailDialogController = DialogService.closeController(this.detailDialogController)
    this.viewModel.openConnectionDetailDialog(record)
    let detailRecord = this.viewModel.records.state.connectionDetailDialog.record
    if (!detailRecord) {
      return
    }
    try {
      this.detailDialogController = new CustomDialogController({
        builder: ConnectionDetailDialog({
          controller: this.detailDialogController,
          currentTheme: this.currentTheme,
          selectedRecord: detailRecord,
          historyItems: this.viewModel.records.state.connectionDetailDialog.historyItems.slice(),
          onClose: () => this.closeDetailDialog()
        }),
        alignment: DialogAlignment.Center,
        autoCancel: false,
        customStyle: true,
        isModal: true,
        maskColor: AppColors.OVERLAY_BACKGROUND,
        cancel: () => {
          this.detailDialogController = undefined
          this.viewModel.closeConnectionDetailDialog()
        }
      })
      this.detailDialogController.open()
    } catch (err) {
      LogUtils.warn(TAG, `openDetailDialog failed: ${JSON.stringify(err)}`)
      this.closeDetailDialog()
    }
  }

  private closeDetailDialog(): void {
    this.detailDialogController = DialogService.closeController(this.detailDialogController)
    this.viewModel.closeConnectionDetailDialog()
  }

  @Builder
  private tabBarBuilder(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontWeight(index === this.currentTabIndex ? FontWeight.Bold : FontWeight.Regular)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(index === this.currentTabIndex ? AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY : AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
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
      title: ModuleText.PERIPHERAL_MANAGE,
      subtitle: PeripheralPageStrings.SUBTITLE,
      currentTheme: this.currentTheme,
      onBack: () => this.onBack(),
      actions: () => {
        this.headerRightActions()
      }
    })
  }

  @Builder
  private headerRightActions() {
    if (this.currentTabIndex === PeripheralTabIndexes.CONNECTION_RECORD) {
      this.headerActions(
        PeripheralExportStrings.HISTORY_LABEL,
        PeripheralExportStrings.CLEAR_HISTORY_LABEL,
        () => void this.handleExportConnectionHistory(),
        () => this.showClearHistoryConfirmDialog()
      )
    } else if (this.currentTabIndex === PeripheralTabIndexes.DEVICE_POLICY) {
      this.headerActions(
        PeripheralExportStrings.EXPORT_POLICY_LABEL,
        PeripheralExportStrings.CLEAR_POLICY_LABEL,
        () => void this.handleExportPeripheralPolicyRecords(),
        () => this.showClearPolicyRecordsConfirmDialog()
      )
    }
  }

  @Builder
  private tabs() {
    Tabs({ barPosition: BarPosition.Start, index: this.currentTabIndex }) {
      TabContent() { this.interfaceTab() }.tabBar(this.tabBarBuilder(PeripheralPageStrings.INTERFACE_TAB, PeripheralTabIndexes.INTERFACE_CONTROL))
      TabContent() { this.deviceTab() }.tabBar(this.tabBarBuilder(PeripheralPageStrings.DEVICE_TAB, PeripheralTabIndexes.CONNECTION_RECORD))
      TabContent() { this.policyTab() }.tabBar(this.tabBarBuilder(PeripheralPageStrings.POLICY_TAB, PeripheralTabIndexes.DEVICE_POLICY))
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
        onUsbInterfaceToggleAsync: async (disallow: boolean): Promise<boolean> => this.handleUsbInterfaceToggle(disallow),
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
        deviceRecords: this.viewModel.records.state.records,
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
        policyRecords: this.viewModel.policy.state.records,
        policyListOptions: this.policyListOptions,
        currentTheme: this.currentTheme,
        hoveredPanelIndex: this.hoveredPanelIndex,
        onPolicyChange: (index: number, policyIndex: number) => {
          const record = this.viewModel.policy.state.records[index]
          if (record) {
            this.handlePolicyChange(record, policyIndex)
          }
        },
        isUpdating: (deviceId: string) => this.viewModel.policy.isUpdating(deviceId.toUpperCase()),
        onPanelHover: (isHover: boolean) => this.setPanelHover(2, isHover)
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  private async handleUsbInterfaceToggle(disallow: boolean): Promise<boolean> {
    const success = await this.usbLoadingRunner.run(
      'peripheral-usb-interface',
      PeripheralLoadingStrings.USB_INTERFACE,
      async (): Promise<boolean> => {
        LogUtils.info(TAG, `usb interface switch start: disallow=${disallow}`)
        return await this.viewModel.toggleInterface(PeripheralService.FEATURE_USB, disallow)
      },
      (dialogMessage: string): CustomDialogController => DialogService.createLoadingController(dialogMessage, this.currentTheme)
    )
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        DialogService.openFailure(this.getUIContext(), `${PeripheralActionStrings.SET_INTERFACE}${PERIPHERAL_ADMIN_REQUIRED_ACTION_SUFFIX}`)
      } else {
        DialogService.openFailure(this.getUIContext(), resolvePeripheralReason(this.viewModel.reasonCode))
      }
      return false
    }
    LogUtils.info(TAG, `usb interface switch success: disallow=${disallow}`)
    return true
  }

  private async handleInterfaceToggle(feature: string, disallow: boolean): Promise<void> {
    if (feature === PeripheralService.FEATURE_USB) {
      await this.handleUsbInterfaceToggle(disallow)
      return
    }
    const success = await this.viewModel.toggleInterface(feature, disallow)
    if (!success) {
      if (!this.viewModel.adminState.activated) {
        DialogService.openFailure(this.getUIContext(), `${PeripheralActionStrings.SET_INTERFACE}${PERIPHERAL_ADMIN_REQUIRED_ACTION_SUFFIX}`)
      } else {
        DialogService.openFailure(this.getUIContext(), resolvePeripheralReason(this.viewModel.reasonCode))
      }
    }
  }

  private async handleUsbStoragePolicyChange(index: number): Promise<boolean> {
    const success = await this.usbLoadingRunner.run(
      'peripheral-usb-storage',
      PeripheralLoadingStrings.USB_STORAGE,
      async (): Promise<boolean> => {
        LogUtils.info(TAG, `usb storage policy switch start: index=${index}`)
        return await this.viewModel.setUsbStoragePolicy(index)
      },
      (dialogMessage: string): CustomDialogController => DialogService.createLoadingController(dialogMessage, this.currentTheme)
    )
    if (!success) {
      LogUtils.warn(TAG, `usb storage policy switch failed: index=${index}, reason=${this.viewModel.reasonCode ?? 'unknown'}`)
      if (!this.viewModel.adminState.activated) {
        DialogService.openFailure(this.getUIContext(), `${PeripheralActionStrings.SET_USB_STORAGE}${PERIPHERAL_ADMIN_REQUIRED_ACTION_SUFFIX}`)
      } else {
        DialogService.openFailure(this.getUIContext(), resolvePeripheralReason(this.viewModel.reasonCode))
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
        DialogService.openFailure(this.getUIContext(), `${PeripheralActionStrings.UPDATE_POLICY}${PERIPHERAL_ADMIN_REQUIRED_ACTION_SUFFIX}`)
      } else {
        DialogService.openFailure(this.getUIContext(), resolvePeripheralReason(this.viewModel.reasonCode))
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
      DialogService.openFailure(this.getUIContext(), resolvePeripheralReason(this.viewModel.reasonCode))
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
        icon: AppResources.SAVE_ICON,
        kind: 'primary',
        currentTheme: this.currentTheme,
        onTap: onExport
      })

      IconTextActionButton({
        label: clearLabel,
        icon: AppResources.TRASH_ICON,
        kind: 'danger',
        currentTheme: this.currentTheme,
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
      DialogService.openFailure(this.getUIContext(), resolvePeripheralReason(this.viewModel.reasonCode))
    }
  }

  private showClearHistoryConfirmDialog(): void {
    if (this.viewModel.records.state.records.length === 0) {
      DialogService.openFailure(this.getUIContext(), PeripheralEmptyStateStrings.HISTORY_TO_CLEAR)
      return
    }
    DialogService.openConfirm(this.getUIContext(), {
      title: PeripheralExportStrings.CLEAR_HISTORY_LABEL,
      message: PeripheralExportStrings.CLEAR_HISTORY_MESSAGE,
      confirmText: ActionText.CLEAR,
      cancelText: ActionText.CANCEL,
      onConfirm: () => void this.clearConnectionHistory()
    })
  }

  private showClearPolicyRecordsConfirmDialog(): void {
    if (this.viewModel.policy.state.records.length === 0) {
      DialogService.openFailure(this.getUIContext(), PeripheralEmptyStateStrings.POLICY_TO_CLEAR)
      return
    }
    DialogService.openConfirm(this.getUIContext(), {
      title: PeripheralExportStrings.CLEAR_POLICY_LABEL,
      message: PeripheralExportStrings.CLEAR_POLICY_MESSAGE,
      confirmText: ActionText.DELETE,
      cancelText: ActionText.CANCEL,
      onConfirm: () => void this.clearPolicyRecords()
    })
  }

  private async clearConnectionHistory(): Promise<void> {
    try {
      const success = await this.viewModel.clearConnectionHistory()
      if (!success) {
        DialogService.openFailure(this.getUIContext(), PeripheralEmptyStateStrings.CLEAR_FAILED)
        return
      }
      this.closeDetailDialog()
      DialogService.openSuccess(this.getUIContext(), PeripheralEmptyStateStrings.CLEAR_HISTORY_SUCCESS)
    } catch (err) {
      LogUtils.error(TAG, `clearConnectionHistory failed: ${JSON.stringify(err)}`)
      DialogService.openFailure(this.getUIContext(), PeripheralEmptyStateStrings.CLEAR_FAILED)
    }
  }

  private async clearPolicyRecords(): Promise<void> {
    const success = await this.viewModel.clearPeripheralPolicyRecords()
    if (!success) {
      DialogService.openFailure(this.getUIContext(), PeripheralEmptyStateStrings.CLEAR_FAILED)
      return
    }
    this.closeDetailDialog()
    DialogService.openSuccess(this.getUIContext(), PeripheralEmptyStateStrings.CLEAR_POLICY_SUCCESS)
  }
}

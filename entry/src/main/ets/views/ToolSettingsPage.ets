import { AppColors, AppStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { ToolSettingsStrings } from '../constants/modules/ToolSettingsStrings'
import { common } from '@kit.AbilityKit'
import { AUTH_METHOD_OPTIONS } from '../models/DataModels'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { FormControlUtils } from '../utils/FormControlUtils'
import { SectionCard } from '../components/SettingsSectionCard'
import { SectionActionRow, SectionSelectRow, SectionToggleRow } from '../components/SectionRows'
import { IconTextActionButton } from '../components/IconTextActionButton'
import { DialogService } from '../utils/DialogService'
import { SubPageHeader } from '../components/SubPageHeader'
import { ToolSettingsActionRequest, ToolSettingsViewModel } from '../viewmodels/ToolSettingsViewModel'

const TAG = 'ToolSettings.Page'
const DOMAIN = 0x0014

@Component
export struct ToolSettingsPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State viewModel: ToolSettingsViewModel = new ToolSettingsViewModel()
  @State initialized: boolean = false
  private authMethodOptions: SelectOption[] =
    AUTH_METHOD_OPTIONS.map((opt): SelectOption => ({ value: opt.label }))

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, '[PAGE_ENTER] aboutToAppear | route=tool-settings')
    void this.initializeViewModel()
  }

  aboutToDisappear() {
    hilog.info(DOMAIN, TAG, '[PAGE_EXIT] aboutToDisappear | route=tool-settings')
  }

  private async initializeViewModel(): Promise<void> {
    this.initialized = false
    await this.viewModel.initialize(this.getPageContext())
    this.initialized = true
  }

  private getPageContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private getSelectedAuthMethodLabel(): string {
    let selectedIndex = this.viewModel.selectedAuthMethodIndex
    if (selectedIndex < 0 || selectedIndex >= this.authMethodOptions.length) {
      return this.authMethodOptions[0].value as string
    }
    return this.authMethodOptions[selectedIndex].value as string
  }

  private handleActionRequest(request: ToolSettingsActionRequest): void {
    if (request.kind === 'result' && request.status && request.message) {
      void DialogService.openResult(this.getUIContext(), {
        status: request.status,
        message: request.message
      })
      return
    }
    if (request.kind !== 'confirm' || !request.title || !request.message) {
      return
    }
    void DialogService.openConfirm(this.getUIContext(), {
      title: request.title,
      message: request.message,
      confirmText: ToolSettingsStrings.continueSave,
      cancelText: CommonStrings.actionCancel,
      onConfirm: () => {
        void this.handleSave(true)
      }
    })
  }

  private async handleSave(allowUnsupportedAuthMethod: boolean = false): Promise<void> {
    let request = await this.viewModel.requestSave(this.getPageContext(), allowUnsupportedAuthMethod)
    this.handleActionRequest(request)
  }

  private async handlePasswordSettings(): Promise<void> {
    let request = await this.viewModel.openPasswordSettings(this.getPageContext())
    this.handleActionRequest(request)
  }

  build() {
    Column() {
      SubPageHeader({
        title: ToolSettingsStrings.pageTitle,
        subtitle: ToolSettingsStrings.pageSubtitle,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerActions()
        }
      })

      Scroll() {
        Column({ space: 24 }) {
          if (this.initialized) {
            SectionCard({
              title: ToolSettingsStrings.sectionStartupAuth,
              content: () => {
                this.startupAuthContent()
              }
            })
          } else {
            Blank()
              .width('100%')
              .height(1)
          }
        }
        .width('100%')
        .padding({
          left: AppStyles.PADDING_LG,
          right: AppStyles.PADDING_LG,
          top: AppStyles.PADDING_MD,
          bottom: AppStyles.PADDING_LG
        })
        .justifyContent(FlexAlign.Start)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.getColors(this.currentTheme).BG_PAGE)
  }

  @Builder
  private headerActions() {
    IconTextActionButton({
      label: ToolSettingsStrings.saveButton,
      icon: $r('app.media.save'),
      kind: 'primary',
      onTap: () => {
        void this.handleSave()
      }
    })
  }

  @Builder
  startupAuthContent() {
    this.startupAuthSwitchRow()

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    this.authMethodRow()

    Divider()
      .color(AppColors.getColors(this.currentTheme).BORDER)
      .opacity(AppColors.getColors(this.currentTheme).BORDER_OPACITY)

    this.changePasswordRow()
  }

  @Builder
  private startupAuthSwitchRow() {
    SectionToggleRow({
      title: ToolSettingsStrings.startupAuthTitle,
      description: ToolSettingsStrings.startupAuthDesc,
      isOn: this.viewModel.state.config.startupAuthEnabled,
      onChange: (value: boolean) => {
        this.viewModel.setStartupAuthEnabled(value)
      }
    })
  }

  @Builder
  private authMethodRow() {
    SectionSelectRow({
      title: ToolSettingsStrings.authMethodTitle,
      description: ToolSettingsStrings.authMethodDesc,
      options: this.authMethodOptions,
      selectedIndex: this.viewModel.selectedAuthMethodIndex,
      value: this.getSelectedAuthMethodLabel(),
      selectWidth: 140,
      onSelect: (index: number) => {
        if (index >= 0 && index < AUTH_METHOD_OPTIONS.length) {
          this.viewModel.setAuthMethod(AUTH_METHOD_OPTIONS[index].value)
        }
      }
    })
  }

  @Builder
  private changePasswordRow() {
    SectionActionRow({
      title: ToolSettingsStrings.changePasswordLabel,
      description: ToolSettingsStrings.changePasswordDesc,
      actionLabel: ToolSettingsStrings.changePasswordLabel,
      onTap: () => {
        void this.handlePasswordSettings()
      }
    })
  }
}

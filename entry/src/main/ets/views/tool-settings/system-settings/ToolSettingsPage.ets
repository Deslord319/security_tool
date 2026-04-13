import { LogUtils } from '../../../utils/LogUtils'
import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ActionText, LabelText, ModuleText } from '../../../constants/StringCatalog'
import {
  ToolSettingsConfirmationStrings,
  ToolSettingsPageStrings,
  ToolSettingsPasswordStrings,
  ToolSettingsStartupAuthStrings
} from '../../../constants/modules/ToolSettingsStrings'
import { common } from '@kit.AbilityKit'
import { AUTH_METHOD_OPTIONS } from '../../../models/DataModels'

import { ThemeMode } from '../../../theme/ThemeColors'
import { FormControlUtils } from '../../../utils/FormControlUtils'
import { SectionCard } from '../../../components/SettingsSectionCard'
import { SectionActionRow, SectionSelectRow, SectionToggleRow } from '../../../components/SectionRows'
import { IconTextActionButton } from '../../../components/IconTextActionButton'
import { DialogService } from '../../../utils/DialogService'
import { SubPageHeader } from '../../../components/SubPageHeader'
import { ToolSettingsActionRequest, ToolSettingsViewModel } from '../../../viewmodels/tool-settings/system-settings/ToolSettingsViewModel'

const TAG = 'ToolSettings.Page'

@ComponentV2
export struct ToolSettingsPage {
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onBack: () => void = () => {}
  @Local viewModel: ToolSettingsViewModel = new ToolSettingsViewModel()
  private authMethodOptions: SelectOption[] =
    AUTH_METHOD_OPTIONS.map((opt): SelectOption => ({ value: opt.label }))

  aboutToAppear() {
    LogUtils.info(TAG, '[PAGE_ENTER] aboutToAppear | route=tool-settings')
    void this.initializeViewModel()
  }

  aboutToDisappear() {
    LogUtils.info(TAG, '[PAGE_EXIT] aboutToDisappear | route=tool-settings')
  }

  private async initializeViewModel(): Promise<void> {
    await this.viewModel.initialize(this.getPageContext())
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

  private async handleSave(allowUnsupportedAuthMethod: boolean = false): Promise<void> {
    let request = await this.viewModel.requestSave(this.getPageContext(), allowUnsupportedAuthMethod)
    if (request.kind === 'result' && request.status && request.message) {
      DialogService.openResult(this.getUIContext(), {
        status: request.status,
        message: request.message
      })
      return
    }
    if (request.kind !== 'confirm' || !request.title || !request.message) {
      return
    }
    DialogService.openConfirm(this.getUIContext(), {
      title: request.title,
      message: request.message,
      confirmText: ToolSettingsConfirmationStrings.CONTINUE_SAVE,
      cancelText: ActionText.CANCEL,
      onConfirm: () => {
        void this.handleSave(true)
      }
    })
  }

  build() {
    Column() {
      SubPageHeader({
        title: ModuleText.TOOL_SETTINGS,
        subtitle: ToolSettingsPageStrings.SUBTITLE,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerActions()
        }
      })

      Scroll() {
        Column({ space: 24 }) {
          if (this.viewModel.state.initialized) {
            SectionCard({
              title: ToolSettingsStartupAuthStrings.SECTION_TITLE,
              currentTheme: this.currentTheme,
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
      label: ActionText.SAVE_SETTINGS,
      icon: AppResources.SAVE_ICON,
      kind: 'primary',
      currentTheme: this.currentTheme,
      isEnabled: this.viewModel.state.initialized && this.viewModel.state.hasChanges && !this.viewModel.state.saving,
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
      title: ToolSettingsStartupAuthStrings.TITLE,
      description: ToolSettingsStartupAuthStrings.DESCRIPTION,
      isOn: this.viewModel.state.config.startupAuthEnabled,
      currentTheme: this.currentTheme,
      onChange: (value: boolean) => {
        this.viewModel.setStartupAuthEnabled(value)
      }
    })
  }

  @Builder
  private authMethodRow() {
    SectionSelectRow({
      title: LabelText.AUTH_METHOD,
      description: ToolSettingsStartupAuthStrings.AUTH_METHOD_DESCRIPTION,
      options: this.authMethodOptions,
      selectedIndex: this.viewModel.selectedAuthMethodIndex,
      value: this.getSelectedAuthMethodLabel(),
      selectWidth: AppStyles.SELECT_WIDTH_DEFAULT,
      currentTheme: this.currentTheme,
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
      title: ToolSettingsPasswordStrings.CHANGE_LABEL,
      description: ToolSettingsPasswordStrings.CHANGE_DESCRIPTION,
      actionLabel: ToolSettingsPasswordStrings.CHANGE_LABEL,
      currentTheme: this.currentTheme,
      onTap: () => {
        this.viewModel.openPasswordSettings(this.getPageContext()).then((request: ToolSettingsActionRequest) => {
          if (request.kind === 'result' && request.status && request.message) {
            DialogService.openResult(this.getUIContext(), {
              status: request.status,
              message: request.message
            })
          }
        })
      }
    })
  }
}

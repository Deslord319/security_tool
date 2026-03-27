import { AppColors, AppStyles } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { ToolSettingsStrings } from '../constants/modules/ToolSettingsStrings'
import { common } from '@kit.AbilityKit'
import { AUTH_METHOD_OPTIONS } from '../models/DataModels'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { BackNavButton } from '../components/BackNavButton'
import { FormControlUtils } from '../utils/FormControlUtils'
import { ResultMessageBox, ResultMessageStatus } from '../components/ResultMessageBox'
import { ResultDialogHelper } from '../utils/ResultDialogHelper'
import { SettingsSectionCard } from '../components/SettingsSectionCard'
import { ToolSettingsActionRequest, ToolSettingsViewModel } from '../viewmodels/ToolSettingsViewModel'

const TAG = 'ToolSettings.Page'
const DOMAIN = 0x0014

@Component
export struct ToolSettingsPage {
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onBack: () => void = () => {}
  @State viewModel: ToolSettingsViewModel = new ToolSettingsViewModel()
  private resultDialogController: CustomDialogController = new CustomDialogController({
    builder: ResultMessageBox({
      onConfirm: () => {
      }
    }),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  })
  private authMethodOptions: SelectOption[] =
    AUTH_METHOD_OPTIONS.map((opt): SelectOption => ({ value: opt.label }))

  aboutToAppear() {
    hilog.info(DOMAIN, TAG, '[PAGE_ENTER] aboutToAppear | route=tool-settings')
    void this.initializeViewModel()
  }

  aboutToDisappear() {
    hilog.info(DOMAIN, TAG, '[PAGE_EXIT] aboutToDisappear | route=tool-settings')
    try {
      this.resultDialogController.close()
    } catch (_err) {
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

  private handleActionRequest(request: ToolSettingsActionRequest): void {
    if (request.kind === 'result' && request.status && request.message) {
      this.showResultDialog(request.status, request.message)
      return
    }
    if (request.kind !== 'confirm' || !request.title || !request.message) {
      return
    }
    void this.getUIContext().showAlertDialog({
      title: request.title,
      message: request.message,
      primaryButton: {
        value: ToolSettingsStrings.continueSave,
        action: () => {
          void this.handleSave(true)
        }
      },
      secondaryButton: {
        value: CommonStrings.actionCancel,
        action: () => {
        }
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
      Row() {
        Row({ space: 8 }) {
          BackNavButton({
            onBack: () => {
              this.onBack()
            }
          })

          Column({ space: 4 }) {
            Text(ToolSettingsStrings.pageTitle)
              .fontSize(AppStyles.FONT_SIZE_TITLE)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
            Text(ToolSettingsStrings.pageSubtitle)
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
              .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Top)

        this.saveButton()
      }
      .width('100%')
      .padding({
        left: AppStyles.PADDING_LG,
        right: AppStyles.PADDING_LG,
        top: AppStyles.PADDING_LG
      })

      Scroll() {
        Column({ space: 24 }) {
          SettingsSectionCard({
            title: ToolSettingsStrings.sectionStartupAuth,
            content: this.startupAuthContent.bind(this)
          })
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
  private saveButton() {
    Button() {
      Row({ space: 6 }) {
        Image($r('app.media.save'))
          .width(14)
          .height(14)
          .fillColor(Color.White)
          .draggable(false)

        Text(ToolSettingsStrings.saveButton)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(Color.White)
      }
      .alignItems(VerticalAlign.Center)
    }
    .type(ButtonType.Normal)
    .backgroundColor(AppColors.BRAND_PRIMARY)
    .borderRadius(AppStyles.RADIUS_SM)
    .height(32)
    .padding({ left: 10, right: 10 })
    .onClick(() => {
      void this.handleSave()
    })
  }

  @Builder
  private startupAuthSwitchRow() {
    Row() {
      Column({ space: 2 }) {
        Text(ToolSettingsStrings.startupAuthTitle)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Text(ToolSettingsStrings.startupAuthDesc)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.viewModel.state.config.startupAuthEnabled })
        .selectedColor(AppColors.BRAND_PRIMARY)
        .onChange((value: boolean) => {
          this.viewModel.setStartupAuthEnabled(value)
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  @Builder
  private authMethodRow() {
    Row() {
      Column({ space: 2 }) {
        Text(ToolSettingsStrings.authMethodTitle)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Text(ToolSettingsStrings.authMethodDesc)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Select(this.authMethodOptions)
        .selected(this.viewModel.selectedAuthMethodIndex)
        .value(this.getSelectedAuthMethodLabel())
        .font({ size: AppStyles.FONT_SIZE_BODY })
        .fontColor(FormControlUtils.text(this.currentTheme))
        .selectedOptionFont({ size: AppStyles.FONT_SIZE_BODY })
        .optionFont({ size: AppStyles.FONT_SIZE_BODY })
        .width(140)
        .height(36)
        .backgroundColor(FormControlUtils.background(this.currentTheme))
        .borderRadius(AppStyles.RADIUS_SM)
        .border({ width: 1, color: FormControlUtils.border(this.currentTheme), style: BorderStyle.Solid })
        .onSelect((index: number) => {
          if (index >= 0 && index < AUTH_METHOD_OPTIONS.length) {
            this.viewModel.setAuthMethod(AUTH_METHOD_OPTIONS[index].value)
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }

  @Builder
  private changePasswordRow() {
    Row() {
      Column({ space: 2 }) {
        Text(ToolSettingsStrings.changePasswordLabel)
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
        Text(ToolSettingsStrings.changePasswordDesc)
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button(ToolSettingsStrings.changePasswordLabel)
        .type(ButtonType.Normal)
        .fontSize(AppStyles.FONT_SIZE_BODY)
        .fontColor(Color.White)
        .backgroundColor(AppColors.BRAND_PRIMARY)
        .borderRadius(AppStyles.RADIUS_SM)
        .height(36)
        .padding({ left: 14, right: 14 })
        .onClick(() => {
          void this.handlePasswordSettings()
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
  }
}

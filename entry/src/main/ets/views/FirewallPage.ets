import { AppColors, AppStyles } from '../constants/AppConstants'
import { BackNavButton } from '../components/BackNavButton'
import { FirewallToggleAuthService } from '../services/FirewallToggleAuthService'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { FirewallPresetMode, FirewallToggleRejectReason } from '../models/DataModels'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'

const TAG = 'FirewallPage'

@Component
export struct FirewallPage {
  @Prop firewallEnabled: boolean = false
  @Prop currentMode: FirewallPresetMode = 'custom'
  @State isToggleProcessing: boolean = false
  @State firewallSwitchValue: boolean = false
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onFirewallToggle: (enabled: boolean) => void = () => {}
  onModeChange: (mode: FirewallPresetMode) => void = () => {}
  onNavigateToRules: () => void = () => {}
  onBack: () => void = () => {}

  aboutToAppear() {
    this.firewallSwitchValue = this.firewallEnabled
  }

  async handleToggleWithAuth(isOn: boolean) {
    if (this.isToggleProcessing) {
      this.firewallSwitchValue = this.firewallEnabled
      return
    }
    let currentEnabled = this.firewallEnabled
    if (isOn === currentEnabled) {
      this.firewallSwitchValue = currentEnabled
      return
    }

    this.isToggleProcessing = true
    try {
      let context = getContext(this) as common.UIAbilityContext
      let result = await FirewallToggleAuthService.executeToggle(context, currentEnabled, isOn)
      if (result.success) {
        this.firewallSwitchValue = isOn
        this.onFirewallToggle(isOn)
        return
      }

      this.firewallSwitchValue = currentEnabled
      this.onFirewallToggle(currentEnabled)
      promptAction.showToast({
        message: result.errorMessage ?? this.buildToggleFailedMessage(result.reason, result.lockRemainingSec)
      })
    } catch (err) {
      this.firewallSwitchValue = currentEnabled
      this.onFirewallToggle(currentEnabled)
      promptAction.showToast({ message: '\u9632\u706b\u5899\u72b6\u6001\u66f4\u65b0\u5931\u8d25' })
      hilog.error(0x0001, TAG, `handleToggleWithAuth failed: ${JSON.stringify(err)}`)
    } finally {
      this.isToggleProcessing = false
    }
  }

  private buildToggleFailedMessage(
    reason: FirewallToggleRejectReason | undefined,
    lockRemainingSec: number | undefined
  ): string {
    switch (reason) {
      case 'lockout':
        return `PIN \u8ba4\u8bc1\u5931\u8d25\u6b21\u6570\u8fc7\u591a\uff0c\u8bf7\u5728 ${lockRemainingSec ?? 60} \u79d2\u540e\u91cd\u8bd5`
      case 'pin_unavailable':
        return '\u7cfb\u7edf PIN \u8ba4\u8bc1\u6682\u4e0d\u53ef\u7528'
      case 'pin_failed':
        return 'PIN \u9a8c\u8bc1\u5931\u8d25\uff0c\u5df2\u53d6\u6d88\u672c\u6b21\u53d8\u66f4'
      case 'policy_apply_failed':
        return '\u9632\u706b\u5899\u72b6\u6001\u66f4\u65b0\u5931\u8d25'
      default:
        return '\u9632\u706b\u5899\u72b6\u6001\u66f4\u65b0\u5931\u8d25'
    }
  }

  private getModeTitle(mode: FirewallPresetMode): string {
    switch (mode) {
      case 'public':
        return '\u516c\u5171\u7f51\u7edc'
      case 'private':
        return '\u4e13\u7528\u7f51\u7edc'
      case 'custom':
      default:
        return '\u81ea\u5b9a\u4e49'
    }
  }

  private getModeDescription(mode: FirewallPresetMode): string {
    switch (mode) {
      case 'public':
        return '\u9002\u5408\u5916\u90e8\u7f51\u7edc\u73af\u5883\uff0c\u63d0\u9ad8\u9632\u62a4\u5f3a\u5ea6'
      case 'private':
        return '\u9002\u5408\u53d7\u4fe1\u4efb\u7684\u5185\u90e8\u7f51\u7edc\u73af\u5883'
      case 'custom':
      default:
        return '\u8fdb\u5165\u89c4\u5219\u8be6\u60c5\u9875\uff0c\u914d\u7f6e\u5165\u7ad9\u3001\u51fa\u7ad9\u53ca\u9ad8\u7ea7\u9632\u706b\u5899\u89c4\u5219'
    }
  }

  private getModeIcon(mode: FirewallPresetMode): Resource {
    switch (mode) {
      case 'public':
        return $r('app.media.globe')
      case 'private':
        return $r('app.media.shield')
      case 'custom':
      default:
        return $r('app.media.firewall')
    }
  }

  private getModeAccent(mode: FirewallPresetMode): string {
    switch (mode) {
      case 'public':
        return '#0A84FF'
      case 'private':
        return '#34C759'
      case 'custom':
      default:
        return '#FF9500'
    }
  }

  private getThemeColors() {
    return AppColors.getColors(this.currentTheme)
  }

  private isModeSelected(mode: FirewallPresetMode): boolean {
    return this.currentMode === mode
  }

  private getModeCardBackground(mode: FirewallPresetMode): string {
    if (this.isModeSelected(mode)) {
      return this.currentTheme === ThemeMode.DARK ? '#2F3946' : '#EEF6FF'
    }
    return this.getThemeColors().BG_CARD
  }

  private getModeCardBorder(mode: FirewallPresetMode): string {
    return this.isModeSelected(mode) ? this.getModeAccent(mode) : this.getThemeColors().BORDER
  }

  private async handleModeSelect(mode: FirewallPresetMode): Promise<void> {
    this.onModeChange(mode)
    if (mode === 'custom') {
      this.onNavigateToRules()
      return
    }
    promptAction.showToast({ message: '\u9884\u8bbe\u6a21\u5f0f\u5f85\u540e\u7eed\u5b8c\u5584' })
  }

  @Builder
  private modeCard(mode: FirewallPresetMode) {
    Row({ space: 16 }) {
      Row() {
        Image(this.getModeIcon(mode))
          .width(22)
          .height(22)
          .fillColor(Color.White)
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.getModeAccent(mode))

      Column({ space: 6 }) {
        Text(this.getModeTitle(mode))
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.getThemeColors().TEXT_PRIMARY)
          .opacity(this.getThemeColors().TEXT_PRIMARY_OPACITY)

        Text(this.getModeDescription(mode))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(this.getThemeColors().TEXT_PRIMARY)
          .opacity(this.getThemeColors().TEXT_TERTIARY_OPACITY)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 8 }) {
        if (this.isModeSelected(mode)) {
          Image($r('app.media.check'))
            .width(18)
            .height(18)
            .fillColor(AppColors.SUCCESS)
        }
        if (mode === 'custom') {
          Image($r('app.media.chevron_right'))
            .width(18)
            .height(18)
            .fillColor(this.getThemeColors().TEXT_PRIMARY)
            .opacity(this.getThemeColors().TEXT_SECONDARY_OPACITY)
        }
      }
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(18)
    .backgroundColor(this.getModeCardBackground(mode))
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: 1,
      color: this.getModeCardBorder(mode)
    })
    .onClick(() => {
      this.handleModeSelect(mode)
    })
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Row() {
          Row({ space: 8 }) {
            BackNavButton({
              onBack: () => {
                this.onBack()
              }
            })

            Column({ space: 4 }) {
              Text('\u9632\u706b\u5899\u7ba1\u7406')
                .fontSize(AppStyles.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getThemeColors().TEXT_PRIMARY)
                .opacity(this.getThemeColors().TEXT_PRIMARY_OPACITY)
              Text('\u5728\u4e0d\u540c\u7f51\u7edc\u573a\u666f\u95f4\u5207\u6362\uff0c\u5e76\u8fdb\u5165\u81ea\u5b9a\u4e49\u6a21\u5f0f\u914d\u7f6e\u9ad8\u7ea7\u9632\u706b\u5899\u89c4\u5219')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontColor(this.getThemeColors().TEXT_PRIMARY)
                .opacity(this.getThemeColors().TEXT_TERTIARY_OPACITY)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .layoutWeight(1)
          .alignItems(VerticalAlign.Top)

          Toggle({ type: ToggleType.Switch, isOn: this.firewallSwitchValue })
            .selectedColor(AppColors.BRAND_PRIMARY)
            .switchPointColor(Color.White)
            .enabled(!this.isToggleProcessing)
            .onChange((isOn: boolean) => {
              this.handleToggleWithAuth(isOn)
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Column({ space: 12 }) {
          Text('\u7f51\u7edc\u6a21\u5f0f')
            .fontSize(AppStyles.FONT_SIZE_SUBTITLE)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.getThemeColors().TEXT_PRIMARY)
            .opacity(this.getThemeColors().TEXT_PRIMARY_OPACITY)

          Column({ space: 12 }) {
            this.modeCard('public')
            this.modeCard('private')
            this.modeCard('custom')
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .padding(AppStyles.PADDING_LG)
      .width('100%')
    }
    .align(Alignment.Top)
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
    .backgroundColor(this.getThemeColors().BG_PAGE)
  }
}

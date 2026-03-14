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
  @State serviceErrorText: string = ''
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
        this.serviceErrorText = ''
        return
      }

      this.firewallSwitchValue = currentEnabled
      this.onFirewallToggle(currentEnabled)
      this.serviceErrorText = this.buildToggleFailedMessage(result.reason, result.lockRemainingSec)
      promptAction.showToast({ message: this.serviceErrorText })
    } catch (err) {
      this.firewallSwitchValue = currentEnabled
      this.onFirewallToggle(currentEnabled)
      this.serviceErrorText = '防火墙状态更新失败'
      promptAction.showToast({ message: this.serviceErrorText })
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
        return `PIN 认证失败次数过多，请在 ${lockRemainingSec ?? 60} 秒后重试`
      case 'pin_unavailable':
        return '系统 PIN 不可用，请先在系统设置中启用 PIN 码'
      case 'pin_failed':
        return 'PIN 认证失败，已取消防火墙状态变更'
      case 'policy_apply_failed':
        return '防火墙策略下发失败'
      default:
        return '防火墙状态更新失败'
    }
  }

  private getModeTitle(mode: FirewallPresetMode): string {
    switch (mode) {
      case 'public':
        return '公用网络'
      case 'private':
        return '专用网络'
      case 'custom':
      default:
        return '自定义（配置高级防火墙规则）'
    }
  }

  private getModeDescription(mode: FirewallPresetMode): string {
    switch (mode) {
      case 'public':
        return '适用于公共环境的预设防护入口，业务逻辑后续实现。'
      case 'private':
        return '适用于受信任环境的预设防护入口，业务逻辑后续实现。'
      case 'custom':
      default:
        return '进入规则详情页，配置入站、出站及高级防火墙规则。'
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
    promptAction.showToast({ message: '功能开发中' })
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
              Text('防火墙管理')
                .fontSize(AppStyles.FONT_SIZE_TITLE)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.getThemeColors().TEXT_PRIMARY)
                .opacity(this.getThemeColors().TEXT_PRIMARY_OPACITY)
              Text('在不同网络场景间切换，并进入自定义模式配置高级防火墙规则。')
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

        if (this.serviceErrorText.length > 0) {
          Row({ space: 8 }) {
            Text('⚠')
              .fontSize(AppStyles.FONT_SIZE_BODY)
              .fontColor(AppColors.WARNING)
            Text(`防火墙服务异常：${this.serviceErrorText}`)
              .fontSize(AppStyles.FONT_SIZE_CAPTION)
              .fontColor(this.getThemeColors().TAG_ORANGE_TEXT)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          .backgroundColor(this.getThemeColors().TAG_ORANGE_BG)
          .borderRadius(AppStyles.RADIUS_MD)
        }

        Column({ space: 12 }) {
          Text('网络模式')
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

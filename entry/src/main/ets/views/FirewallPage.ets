import { AppColors, AppStyles } from '../constants/AppConstants'
import { BackNavButton } from '../components/BackNavButton'
import { FirewallToggleAuthService } from '../services/FirewallToggleAuthService'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { promptAction } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { FirewallPresetMode, FirewallToggleRejectReason } from '../models/DataModels'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'

const TAG = 'FirewallPage'

@Component
export struct FirewallPage {
  @Prop firewallEnabled: boolean = false
  @Prop currentMode: FirewallPresetMode = 'custom'
  @State isToggleProcessing: boolean = false
  @State isModeProcessing: boolean = false
  @State firewallSwitchValue: boolean = false
  @State hoveredMode: string = ''
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT
  onFirewallToggle: (enabled: boolean) => void = () => {}
  onModeChange: (mode: FirewallPresetMode) => Promise<boolean> = async () => false
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
      promptAction.showToast({ message: '防火墙开关切换失败' })
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
        return `PIN 校验失败次数过多，请在 ${lockRemainingSec ?? 60} 秒后重试`
      case 'pin_unavailable':
        return '当前设备未配置 PIN'
      case 'pin_failed':
        return 'PIN 校验失败'
      case 'policy_apply_failed':
        return '防火墙状态写入失败'
      default:
        return '防火墙状态切换失败'
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
        return '自定义规则'
    }
  }

  private getModeDescription(mode: FirewallPresetMode): string {
    switch (mode) {
      case 'public':
        return '下发公用网络预置策略，成功后仅保留公用模式规则。'
      case 'private':
        return '下发专用网络预置策略，成功后仅保留专用模式规则。'
      case 'custom':
      default:
        return '切换为自定义模式并进入规则页，重新下发已保存的自定义策略。'
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

  private isModeHovered(mode: FirewallPresetMode): boolean {
    return this.hoveredMode === mode
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

  private getModeCardShadow(mode: FirewallPresetMode): ShadowOptions {
    return HoverUtils.getShadow(this.currentTheme, this.isModeHovered(mode), true)
  }

  private getModeCardTranslateY(mode: FirewallPresetMode): number {
    return HoverUtils.getTranslateY(this.isModeHovered(mode), 4)
  }

  private getModeCardScale(mode: FirewallPresetMode): number {
    return HoverUtils.getScale(this.isModeHovered(mode))
  }

  private async handleModeSelect(mode: FirewallPresetMode): Promise<void> {
    if (this.isModeProcessing) {
      return
    }
    if (mode === this.currentMode) {
      if (mode === 'custom') {
        this.onNavigateToRules()
      }
      return
    }
    this.isModeProcessing = true
    try {
      let success = await this.onModeChange(mode)
      if (!success) {
        promptAction.showToast({ message: '策略下发失败，当前模式未切换' })
        return
      }
      if (mode === 'custom') {
        this.onNavigateToRules()
      }
    } finally {
      this.isModeProcessing = false
    }
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
      .scale({
        x: HoverUtils.getScale(this.isModeHovered(mode), 1.04),
        y: HoverUtils.getScale(this.isModeHovered(mode), 1.04)
      })

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
    .shadow(this.getModeCardShadow(mode))
    .translate({ y: this.getModeCardTranslateY(mode) })
    .scale({
      x: this.getModeCardScale(mode),
      y: this.getModeCardScale(mode)
    })
    .opacity(this.isModeProcessing ? 0.75 : 1)
    .onHover((isHover: boolean) => {
      HoverUtils.animate(() => {
        if (isHover) {
          this.hoveredMode = mode
        } else if (this.hoveredMode === mode) {
          this.hoveredMode = ''
        }
      })
    })
    .onClick(() => {
      if (!this.isModeProcessing) {
        this.handleModeSelect(mode)
      }
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
              Text('点击模式卡片后，后端先执行策略切换，只有成功后当前模式标记才会移动。')
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
          Text('模式切换')
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

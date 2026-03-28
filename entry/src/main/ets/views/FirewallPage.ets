import { AppColors, AppStyles } from '../constants/AppConstants'
import { FirewallStrings } from '../constants/modules/FirewallStrings'
import { SubPageHeader } from '../components/SubPageHeader'
import { UserFirewallControlDialog } from '../components/UserFirewallControlDialog'
import { FirewallService } from '../services/FirewallService'
import { FirewallToggleAuthService } from '../services/FirewallToggleAuthService'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { common } from '@kit.AbilityKit'
import { FirewallPresetMode, FirewallToggleRejectReason } from '../models/DataModels'
import { ThemeMode } from '../theme/ThemeColors'
import { STORAGE_KEY_THEME } from '../theme/ThemeManager'
import { HoverUtils } from '../utils/HoverUtils'
import { DialogService } from '../utils/DialogService'

const TAG = 'FirewallPage'
const DOMAIN = 0x0010
const MIN_MODE_LOADING_DIALOG_DURATION_MS = 500
const DEFAULT_FIREWALL_USER_ID = 100

@CustomDialog
struct FirewallModeLoadingDialog {
  controller: CustomDialogController
  @StorageLink(STORAGE_KEY_THEME) currentTheme: ThemeMode = ThemeMode.LIGHT

  build() {
    Column({ space: 14 }) {
      LoadingProgress()
        .width(44)
        .height(44)
      Text(FirewallStrings.modeLoadingMessage)
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
    .border({
      width: 1,
      color: AppColors.getColors(this.currentTheme).BORDER
    })
    .shadow({
      radius: 20,
      color: this.currentTheme === ThemeMode.DARK ? 'rgba(0,0,0,0.36)' : 'rgba(0,0,0,0.14)',
      offsetX: 0,
      offsetY: 10
    })
  }
}

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
  private isModeLoadingDialogOpen: boolean = false
  private modeLoadingDialogOpenedAt: number = 0
  private modeLoadingDialogController: CustomDialogController = new CustomDialogController({
    builder: FirewallModeLoadingDialog(),
    alignment: DialogAlignment.Center,
    autoCancel: false,
    customStyle: true
  })
  private userFirewallDialogController?: CustomDialogController

  aboutToAppear() {
    this.firewallSwitchValue = this.firewallEnabled
  }

  aboutToDisappear() {
    this.closeModeLoadingDialog()
    this.closeUserFirewallDialog()
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
      let context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
      let result = await FirewallToggleAuthService.executeToggle(context, currentEnabled, isOn)
      if (result.success) {
        this.firewallSwitchValue = isOn
        this.onFirewallToggle(isOn)
        return
      }

      this.firewallSwitchValue = currentEnabled
      this.onFirewallToggle(currentEnabled)
      void DialogService.openFailure(
        this.getUIContext(),
        result.errorMessage ?? this.buildToggleFailedMessage(result.reason, result.lockRemainingSec)
      )
    } catch (err) {
      this.firewallSwitchValue = currentEnabled
      this.onFirewallToggle(currentEnabled)
      void DialogService.openFailure(this.getUIContext(), FirewallStrings.toggleFailed)
      hilog.error(0x0001, TAG, `handleToggleWithAuth failed: ${JSON.stringify(err)}`)
    } finally {
      this.isToggleProcessing = false
    }
  }

  private buildToggleFailedMessage(
    reason: FirewallToggleRejectReason | undefined,
    lockRemainingSec: number | undefined
  ): string {
    return FirewallStrings.buildToggleFailedMessage(reason, lockRemainingSec)
  }

  private getModeTitle(mode: FirewallPresetMode): string {
    return FirewallStrings.getModeTitle(mode)
  }

  private getModeDescription(mode: FirewallPresetMode): string {
    return FirewallStrings.getModeDescription(mode)
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
        return FirewallStrings.publicModeAccent
      case 'private':
        return FirewallStrings.privateModeAccent
      case 'custom':
      default:
        return FirewallStrings.customModeAccent
    }
  }

  private getThemeColors() {
    return AppColors.getColors(this.currentTheme)
  }

  private isModeSelected(mode: FirewallPresetMode): boolean {
    return this.currentMode === mode
  }

  private isModeHovered(mode: FirewallPresetMode): boolean {
    return this.canOperateModeCards() && this.hoveredMode === mode
  }

  private canOperateModeCards(): boolean {
    return this.firewallEnabled && !this.isToggleProcessing && !this.isModeProcessing
  }

  private getModeCardBackground(mode: FirewallPresetMode): string {
    if (this.isModeSelected(mode)) {
      return this.currentTheme === ThemeMode.DARK ? FirewallStrings.selectedCardBgDark : FirewallStrings.selectedCardBgLight
    }
    return this.getThemeColors().BG_CARD
  }

  private getModeCardBorder(mode: FirewallPresetMode): string {
    return this.isModeSelected(mode) ? this.getModeAccent(mode) : this.getThemeColors().BORDER
  }

  private getModeCardBorderWidth(mode: FirewallPresetMode): number {
    return this.isModeSelected(mode) ? 2 : 1
  }

  private getModeIconContainerBorder(mode: FirewallPresetMode): BorderOptions {
    if (!this.isModeSelected(mode)) {
      return {
        width: 0
      }
    }
    return {
      width: 3,
      color: this.currentTheme === ThemeMode.DARK ? FirewallStrings.selectedIconBorderDark : FirewallStrings.selectedIconBorderLight
    }
  }

  private getModeIconContainerShadow(mode: FirewallPresetMode): ShadowOptions | ShadowStyle {
    if (!this.isModeSelected(mode)) {
      return ShadowStyle.OUTER_DEFAULT_SM
    }
    return {
      radius: 16,
      color: this.currentTheme === ThemeMode.DARK ? FirewallStrings.selectedShadowDark : FirewallStrings.selectedShadowLight,
      offsetX: 0,
      offsetY: 6
    }
  }

  private getModeTitleColor(mode: FirewallPresetMode): string {
    return this.isModeSelected(mode) ? this.getModeAccent(mode) : this.getThemeColors().TEXT_PRIMARY
  }

  private getModeTitleOpacity(mode: FirewallPresetMode): number {
    return this.isModeSelected(mode) ? 1 : this.getThemeColors().TEXT_PRIMARY_OPACITY
  }

  private getModeDescriptionOpacity(mode: FirewallPresetMode): number {
    return this.isModeSelected(mode) ? this.getThemeColors().TEXT_SECONDARY_OPACITY : this.getThemeColors().TEXT_TERTIARY_OPACITY
  }

  private getModeStatusBackground(mode: FirewallPresetMode): string {
    return this.currentTheme === ThemeMode.DARK ? `${this.getModeAccent(mode)}33` : this.getModeAccent(mode)
  }

  private getModeStatusTextColor(mode: FirewallPresetMode): string {
    return this.currentTheme === ThemeMode.DARK ? this.getModeAccent(mode) : FirewallStrings.lightStatusText
  }

  private getModeStatusBorder(mode: FirewallPresetMode): BorderOptions {
    if (this.currentTheme === ThemeMode.DARK) {
      return {
        width: 1,
        color: `${this.getModeAccent(mode)}55`
      }
    }
    return {
      width: 0
    }
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

  private openUserFirewallDialog(): void {
    this.closeUserFirewallDialog()
    this.userFirewallDialogController = new CustomDialogController({
      builder: UserFirewallControlDialog({
        controller: this.userFirewallDialogController,
        onActionCompleted: async (userId: number, enabled: boolean): Promise<void> => {
          await this.handleUserFirewallActionCompleted(userId, enabled)
        }
      }),
      alignment: DialogAlignment.Center,
      autoCancel: true,
      customStyle: true
    })
    this.userFirewallDialogController.open()
  }

  private closeUserFirewallDialog(): void {
    try {
      this.userFirewallDialogController?.close()
    } catch (_err) {
    } finally {
      this.userFirewallDialogController = undefined
    }
  }

  private async handleUserFirewallActionCompleted(userId: number, enabled: boolean): Promise<void> {
    if (userId !== DEFAULT_FIREWALL_USER_ID) {
      return
    }
    let nextEnabled = enabled
    let policy = await FirewallService.getFirewallPolicy()
    if (policy !== null) {
      nextEnabled = policy.isOpen
    } else {
      hilog.warn(DOMAIN, TAG, 'sync default firewall state fallback to requested value after user-specific update')
    }
    this.firewallSwitchValue = nextEnabled
    this.onFirewallToggle(nextEnabled)
  }

  private openModeLoadingDialog(): void {
    if (this.isModeLoadingDialogOpen) {
      return
    }
    this.modeLoadingDialogOpenedAt = Date.now()
    this.modeLoadingDialogController.open()
    this.isModeLoadingDialogOpen = true
  }

  private closeModeLoadingDialog(): void {
    if (!this.isModeLoadingDialogOpen) {
      this.modeLoadingDialogOpenedAt = 0
      return
    }
    try {
      this.modeLoadingDialogController.close()
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to close mode loading dialog: ${JSON.stringify(err)}`)
    } finally {
      this.isModeLoadingDialogOpen = false
      this.modeLoadingDialogOpenedAt = 0
    }
  }

  private async waitForModeLoadingDialogMinimumDuration(): Promise<void> {
    if (!this.isModeLoadingDialogOpen) {
      return
    }
    let elapsed = Date.now() - this.modeLoadingDialogOpenedAt
    let remainingDuration = MIN_MODE_LOADING_DIALOG_DURATION_MS - elapsed
    if (remainingDuration <= 0) {
      return
    }
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => {
        resolve()
      }, remainingDuration)
    })
  }

  private showModeChangeFailedDialog(): void {
    void DialogService.openFailure(this.getUIContext(), FirewallStrings.modeApplyFailed)
  }

  private async handleModeSelect(mode: FirewallPresetMode): Promise<void> {
    if (!this.canOperateModeCards()) {
      return
    }
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
    this.openModeLoadingDialog()
    let success = false
    try {
      success = await this.onModeChange(mode)
    } catch (err) {
      hilog.error(0x0001, TAG, `handleModeSelect failed: ${JSON.stringify(err)}`)
    } finally {
      await this.waitForModeLoadingDialogMinimumDuration()
      this.closeModeLoadingDialog()
      this.isModeProcessing = false
    }
    if (!success) {
      this.showModeChangeFailedDialog()
      return
    }
    hilog.info(0x0001, TAG, 'mode changed successfully')
    if (mode === 'custom') {
      this.onNavigateToRules()
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
          .draggable(false)
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .backgroundColor(this.getModeAccent(mode))
      .border(this.getModeIconContainerBorder(mode))
      .shadow(this.getModeIconContainerShadow(mode))
      .scale({
        x: HoverUtils.getScale(this.isModeHovered(mode), 1.04),
        y: HoverUtils.getScale(this.isModeHovered(mode), 1.04)
      })

      Column({ space: 6 }) {
        if (this.isModeSelected(mode)) {
          Row({ space: 4 }) {
            Image($r('app.media.check'))
              .width(12)
              .height(12)
              .fillColor(this.getModeStatusTextColor(mode))
            Text(FirewallStrings.currentMode)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getModeStatusTextColor(mode))
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(999)
          .backgroundColor(this.getModeStatusBackground(mode))
          .border(this.getModeStatusBorder(mode))
        }

        Text(this.getModeTitle(mode))
          .fontSize(AppStyles.FONT_SIZE_BODY)
          .fontWeight(this.isModeSelected(mode) ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.getModeTitleColor(mode))
          .opacity(this.getModeTitleOpacity(mode))

        Text(this.getModeDescription(mode))
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(this.getThemeColors().TEXT_PRIMARY)
          .opacity(this.getModeDescriptionOpacity(mode))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 8 }) {
        if (mode === 'custom') {
          Row({ space: 4 }) {
            Text(FirewallStrings.rulesPage)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getThemeColors().TEXT_PRIMARY)
              .opacity(this.isModeSelected(mode) ? this.getThemeColors().TEXT_SECONDARY_OPACITY : this.getThemeColors().TEXT_TERTIARY_OPACITY)
            Image($r('app.media.chevron_right'))
              .width(16)
              .height(16)
              .fillColor(this.getThemeColors().TEXT_PRIMARY)
              .opacity(this.isModeSelected(mode) ? this.getThemeColors().TEXT_SECONDARY_OPACITY : this.getThemeColors().TEXT_TERTIARY_OPACITY)
          }
        } else if (this.isModeSelected(mode)) {
          Row({ space: 4 }) {
            Text(FirewallStrings.effective)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getThemeColors().TEXT_PRIMARY)
              .opacity(this.getThemeColors().TEXT_SECONDARY_OPACITY)
            Image($r('app.media.check'))
              .width(14)
              .height(14)
              .fillColor(this.getModeAccent(mode))
          }
        } else {
          Image($r('app.media.check'))
            .width(14)
            .height(14)
            .fillColor(this.getThemeColors().TEXT_PRIMARY)
            .opacity(0)
        }
      }
      .alignItems(HorizontalAlign.End)
      .justifyContent(FlexAlign.Center)
    }
    .alignItems(VerticalAlign.Center)
    .width('100%')
    .padding(18)
    .backgroundColor(this.getModeCardBackground(mode))
    .borderRadius(AppStyles.RADIUS_LG)
    .border({
      width: this.getModeCardBorderWidth(mode),
      color: this.getModeCardBorder(mode)
    })
    .shadow(this.getModeCardShadow(mode))
    .translate({ y: this.getModeCardTranslateY(mode) })
    .scale({
      x: this.getModeCardScale(mode),
      y: this.getModeCardScale(mode)
    })
    .opacity(this.canOperateModeCards() ? (this.isModeProcessing ? 0.75 : 1) : 0.56)
    .onHover((isHover: boolean) => {
      if (!this.canOperateModeCards()) {
        if (this.hoveredMode === mode) {
          this.hoveredMode = ''
        }
        return
      }
      HoverUtils.animate(() => {
        if (isHover) {
          this.hoveredMode = mode
        } else if (this.hoveredMode === mode) {
          this.hoveredMode = ''
        }
      })
    })
    .onClick(() => {
      if (this.canOperateModeCards()) {
        this.handleModeSelect(mode)
      }
    })
  }

  build() {
    Column() {
      SubPageHeader({
        title: FirewallStrings.pageTitle,
        subtitle: FirewallStrings.pageSubtitle,
        currentTheme: this.currentTheme,
        onBack: () => this.onBack(),
        actions: () => {
          this.headerActions()
        }
      })

      Scroll() {
        Column({ space: 24 }) {
          Column({ space: 12 }) {
            Text(FirewallStrings.modeSectionTitle)
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
        .padding({
          left: AppStyles.PADDING_LG,
          right: AppStyles.PADDING_LG,
          top: AppStyles.PADDING_MD,
          bottom: AppStyles.PADDING_LG
        })
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getThemeColors().BG_PAGE)
  }

  @Builder
  private headerActions() {
    Row({ space: 12 }) {
      Button(FirewallStrings.userIdControlButton)
        .type(ButtonType.Normal)
        .height(36)
        .padding({ left: 14, right: 14 })
        .fontSize(AppStyles.FONT_SIZE_SMALL)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppColors.BRAND_PRIMARY)
        .backgroundColor(this.getThemeColors().BG_CARD)
        .borderRadius(AppStyles.RADIUS_MD)
        .border({
          width: 1,
          color: this.getThemeColors().BORDER
        })
        .enabled(!this.isToggleProcessing && !this.isModeProcessing)
        .opacity(!this.isToggleProcessing && !this.isModeProcessing ? 1 : 0.5)
        .onClick(() => {
          this.openUserFirewallDialog()
        })

      Toggle({ type: ToggleType.Switch, isOn: this.firewallSwitchValue })
        .selectedColor(AppColors.BRAND_PRIMARY)
        .switchPointColor(Color.White)
        .enabled(!this.isToggleProcessing)
        .onChange((isOn: boolean) => {
          this.handleToggleWithAuth(isOn)
        })
    }
    .alignItems(VerticalAlign.Center)
  }
}

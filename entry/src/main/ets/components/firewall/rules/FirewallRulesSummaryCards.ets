import { AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import {
  FirewallRuleStrings,
  buildFirewallRuleCountText,
  buildFirewallUserCountText
} from '../../../constants/modules/FirewallStrings'
import { ThemeMode } from '../../../theme/ThemeColors'
import { CompactSummaryCard } from '../../CompactSummaryCard'
import {
  FirewallDefaultPolicyDisplayItem,
  FirewallDefaultPolicyMode
} from '../../../services/firewall/FirewallModels'

const USER_POLICY_DESCRIPTION_MAX_LINES: number = 2

@ComponentV2
export struct FirewallRulesSummaryCards {
  @Param defaultPolicyItems: FirewallDefaultPolicyDisplayItem[] = []
  @Param inboundRuleCount: number = 0
  @Param outboundRuleCount: number = 0
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT

  private getDefaultPolicyUserCount(mode: FirewallDefaultPolicyMode): number {
    return this.defaultPolicyItems.filter((item: FirewallDefaultPolicyDisplayItem): boolean => item.mode === mode).length
  }

  private getDefaultPolicyUserCountText(mode: FirewallDefaultPolicyMode): string {
    return buildFirewallUserCountText(this.getDefaultPolicyUserCount(mode))
  }

  private getDefaultPolicyUserListText(mode: FirewallDefaultPolicyMode): string {
    const labels = this.defaultPolicyItems
      .filter((item: FirewallDefaultPolicyDisplayItem): boolean => item.mode === mode)
      .map((item: FirewallDefaultPolicyDisplayItem): string => item.label)
    return labels.length > 0 ? labels.join('、') : FirewallRuleStrings.DEFAULT_POLICY_EMPTY_USERS
  }

  private getDefaultPolicyOtherSummaryText(): string {
    const customCount = this.getDefaultPolicyUserCount('custom')
    const unknownCount = this.getDefaultPolicyUserCount('unknown')
    const disabledCount = this.defaultPolicyItems.filter((item: FirewallDefaultPolicyDisplayItem): boolean => !item.isOpen).length
    let parts: string[] = []
    if (customCount > 0) {
      parts.push(`${FirewallRuleStrings.DEFAULT_POLICY_CUSTOM} ${buildFirewallUserCountText(customCount)}`)
    }
    if (unknownCount > 0) {
      parts.push(`${FirewallRuleStrings.DEFAULT_POLICY_UNKNOWN} ${buildFirewallUserCountText(unknownCount)}`)
    }
    if (disabledCount > 0) {
      parts.push(`${FirewallRuleStrings.DEFAULT_POLICY_DISABLED} ${buildFirewallUserCountText(disabledCount)}`)
    }
    return parts.join(' · ')
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: AppStyles.PADDING_LG }) {
        CompactSummaryCard({
          title: FirewallRuleStrings.DEFAULT_POLICY_ALLOWLIST_USERS,
          valueText: this.getDefaultPolicyUserCountText('allowlist'),
          description: this.getDefaultPolicyUserListText('allowlist'),
          accentStart: AppColors.DANGER,
          accentEnd: AppColors.WARNING,
          icon: AppResources.SHIELD_ICON,
          secondaryMaxLines: USER_POLICY_DESCRIPTION_MAX_LINES,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)

        CompactSummaryCard({
          title: FirewallRuleStrings.DEFAULT_POLICY_DENYLIST_USERS,
          valueText: this.getDefaultPolicyUserCountText('denylist'),
          description: this.getDefaultPolicyUserListText('denylist'),
          accentStart: AppColors.SUCCESS,
          accentEnd: AppColors.GRADIENT_LOG_END,
          icon: AppResources.SHIELD_ICON,
          secondaryMaxLines: USER_POLICY_DESCRIPTION_MAX_LINES,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)

        CompactSummaryCard({
          title: FirewallRuleStrings.INBOUND,
          valueText: buildFirewallRuleCountText(this.inboundRuleCount),
          description: FirewallRuleStrings.INBOUND_DESCRIPTION,
          accentStart: AppColors.WARNING,
          accentEnd: AppColors.GRADIENT_IDENTITY_END,
          icon: AppResources.ARROW_DOWN_ICON,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)

        CompactSummaryCard({
          title: FirewallRuleStrings.OUTBOUND,
          valueText: buildFirewallRuleCountText(this.outboundRuleCount),
          description: FirewallRuleStrings.OUTBOUND_DESCRIPTION,
          accentStart: AppColors.BRAND_PRIMARY,
          accentEnd: AppColors.GRADIENT_FIREWALL_END,
          icon: AppResources.ARROW_UP_ICON,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)
      }
      .width('100%')

      if (this.getDefaultPolicyOtherSummaryText().length > 0) {
        Text(this.getDefaultPolicyOtherSummaryText())
          .fontSize(AppStyles.FONT_SIZE_CAPTION)
          .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
          .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG, top: 6 })
  }
}

import { netFirewall } from '@kit.NetworkKit'
import { ActionButtonStyles, AppColors, AppStyles } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { LabelText } from '../../../constants/StringCatalog'
import { EmptyStateStrings, LoadingStrings } from '../../../constants/modules/DialogStrings'
import {
  FirewallDialogStrings,
  FirewallRuleLabelStrings,
  FirewallRuleStrings
} from '../../../constants/modules/FirewallStrings'
import { ThemeMode } from '../../../theme/ThemeColors'
import { HoverUtils } from '../../../utils/HoverUtils'
import { getScrollBarColor, SCROLL_BAR_WIDTH_DEFAULT, SCROLL_BAR_WIDTH_HOVER } from '../../../utils/ScrollBarStyleUtils'
import { BaseCard } from '../../BaseCard'
import { IconTextActionButton } from '../../IconTextActionButton'
import { LoadingStatePanel } from '../../LoadingStatePanel'
import {
  FIREWALL_PROTOCOL_ICMP,
  FIREWALL_PROTOCOL_TCP,
  FIREWALL_PROTOCOL_UDP,
  FirewallScopedRule
} from '../../../models/firewall/FirewallModels'
import { FirewallRulePresentationMapper } from '../../../viewmodels/firewall/rules/FirewallRulePresentationMapper'

@ComponentV2
export struct FirewallRuleList {
  @Param rules: netFirewall.NetFirewallRule[] = []
  @Param isLoading: boolean = false
  @Param deletingRuleId: string = ''
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event getUserScopeLabel: (rule: netFirewall.NetFirewallRule) => string = (_rule: netFirewall.NetFirewallRule): string => FirewallDialogStrings.ALL_VALUE
  @Event onEditRule: (rule: netFirewall.NetFirewallRule) => void = (_rule: netFirewall.NetFirewallRule): void => {}
  @Event onDeleteRule: (rule: netFirewall.NetFirewallRule) => void = (_rule: netFirewall.NetFirewallRule): void => {}
  @Local private listScrollBarWidth: number = SCROLL_BAR_WIDTH_DEFAULT

  private getRuleKey(rule: netFirewall.NetFirewallRule): string {
    return (rule as FirewallScopedRule).localRuleId ?? `${rule.name ?? 'rule'}_${rule.direction}_${rule.action}_${rule.type}`
  }

  build() {
    Column() {
      if (this.isLoading) {
        LoadingStatePanel({
          message: LoadingStrings.LOADING_RULES,
          indicatorSize: AppStyles.LOADING_INDICATOR_SIZE,
          currentTheme: this.currentTheme
        })
          .layoutWeight(1)
      } else if (this.rules.length === 0) {
        Column({ space: 10 }) {
          Text(EmptyStateStrings.NO_RULES)
            .fontSize(AppStyles.FONT_SIZE_BODY)
            .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
            .opacity(AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 12 }) {
          ForEach(this.rules, (rule: netFirewall.NetFirewallRule) => {
            ListItem() {
              FirewallRuleCard({
                rule: rule,
                userScopeLabel: this.getUserScopeLabel(rule),
                isDeleting: this.getRuleKey(rule) === this.deletingRuleId,
                currentTheme: this.currentTheme,
                onEditRule: this.onEditRule,
                onDeleteRule: this.onDeleteRule
              })
            }
          }, (rule: netFirewall.NetFirewallRule): string => this.getRuleKey(rule))
        }
        .width('100%')
        .layoutWeight(1)
        .clip(false)
        .scrollBar(BarState.Auto)
        .scrollBarColor(getScrollBarColor(this.currentTheme))
        .scrollBarWidth(this.listScrollBarWidth)
        .onHover((isHover: boolean) => {
          this.listScrollBarWidth = isHover ? SCROLL_BAR_WIDTH_HOVER : SCROLL_BAR_WIDTH_DEFAULT
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding({ top: 6, bottom: 0 })
  }
}

@ComponentV2
struct FirewallRuleCard {
  @Param rule: netFirewall.NetFirewallRule = {
    userId: 0,
    name: '',
    direction: netFirewall.NetFirewallRuleDirection.RULE_OUT,
    action: netFirewall.FirewallRuleAction.RULE_ALLOW,
    type: netFirewall.NetFirewallRuleType.RULE_IP,
    isEnabled: true
  }
  @Param userScopeLabel: string = ''
  @Param isDeleting: boolean = false
  @Param currentTheme: ThemeMode = ThemeMode.LIGHT
  @Event onEditRule: (rule: netFirewall.NetFirewallRule) => void = (_rule: netFirewall.NetFirewallRule): void => {}
  @Event onDeleteRule: (rule: netFirewall.NetFirewallRule) => void = (_rule: netFirewall.NetFirewallRule): void => {}
  @Local private isHovered: boolean = false

  private getRuleTypeLabel(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return FirewallRuleLabelStrings.IP_RULE
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return FirewallRuleLabelStrings.DOMAIN_RULE
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return FirewallRuleLabelStrings.DNS_RULE
      default:
        return LabelText.UNKNOWN
    }
  }

  private getRuleTypeTextColor(type: netFirewall.NetFirewallRuleType): string {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return AppColors.getColors(this.currentTheme).TAG_BLUE_TEXT
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return AppColors.getColors(this.currentTheme).TAG_PURPLE_TEXT
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
      default:
        return AppColors.getColors(this.currentTheme).TAG_GRAY_TEXT
    }
  }

  private getRuleIcon(type: netFirewall.NetFirewallRuleType): Resource {
    switch (type) {
      case netFirewall.NetFirewallRuleType.RULE_IP:
        return AppResources.NETWORK_ICON
      case netFirewall.NetFirewallRuleType.RULE_DOMAIN:
        return AppResources.GLOBE_ICON
      case netFirewall.NetFirewallRuleType.RULE_DNS:
        return AppResources.SERVER_ICON
      default:
        return AppResources.FIREWALL_ICON
    }
  }

  private getDirectionLabel(dir: netFirewall.NetFirewallRuleDirection): string {
    return dir === netFirewall.NetFirewallRuleDirection.RULE_IN
      ? FirewallDialogStrings.DIRECTION_INBOUND
      : FirewallDialogStrings.DIRECTION_OUTBOUND
  }

  private getActionLabel(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW ? FirewallDialogStrings.ACTION_ALLOW : FirewallDialogStrings.ACTION_DENY
  }

  private getActionTextColor(action: netFirewall.FirewallRuleAction): string {
    return action === netFirewall.FirewallRuleAction.RULE_ALLOW
      ? AppColors.getColors(this.currentTheme).TAG_GREEN_TEXT
      : AppColors.getColors(this.currentTheme).TAG_RED_TEXT
  }

  private getRuleAddress(): string {
    if (this.rule.type === netFirewall.NetFirewallRuleType.RULE_IP) {
      let ipParams = this.rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN ? this.rule.localIps : this.rule.remoteIps
      return FirewallRulePresentationMapper.formatIpParams(ipParams) || FirewallDialogStrings.ALL_VALUE
    }
    if (this.rule.type === netFirewall.NetFirewallRuleType.RULE_DOMAIN) {
      return this.rule.domains?.[0]?.domain ?? '-'
    }
    if (this.rule.type === netFirewall.NetFirewallRuleType.RULE_DNS) {
      return this.rule.dns?.primaryDns ?? '-'
    }
    return '-'
  }

  private getRuleLocalPort(): string {
    return FirewallRulePresentationMapper.formatPortParams(this.rule.localPorts) || FirewallDialogStrings.ALL_VALUE
  }

  private getRuleRemotePort(): string {
    return FirewallRulePresentationMapper.formatPortParams(this.rule.remotePorts) || FirewallDialogStrings.ALL_VALUE
  }

  private getIpAddressLabel(): string {
    return this.rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN
      ? FirewallDialogStrings.LOCAL_ADDRESS
      : FirewallDialogStrings.REMOTE_ADDRESS
  }

  private getPrimaryPortLabel(): string {
    return this.rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN
      ? FirewallDialogStrings.LOCAL_PORT
      : FirewallDialogStrings.REMOTE_PORT
  }

  private getPrimaryPortValue(): string {
    return this.rule.direction === netFirewall.NetFirewallRuleDirection.RULE_IN
      ? this.getRuleLocalPort()
      : this.getRuleRemotePort()
  }

  private getProtocolLabel(): string {
    if (this.rule.protocol === undefined || this.rule.protocol === null) {
      return FirewallDialogStrings.ALL_VALUE
    }
    switch (this.rule.protocol) {
      case FIREWALL_PROTOCOL_TCP:
        return FirewallDialogStrings.PROTOCOL_TCP
      case FIREWALL_PROTOCOL_UDP:
        return FirewallDialogStrings.PROTOCOL_UDP
      case FIREWALL_PROTOCOL_ICMP:
        return FirewallDialogStrings.PROTOCOL_ICMP
      default:
        return FirewallDialogStrings.ALL_VALUE
    }
  }

  build() {
    Column() {
      BaseCard({
        useAutoHeight: true,
        clickable: true,
        disabled: this.isDeleting,
        currentTheme: this.currentTheme,
        onPress: () => {
          this.onEditRule(this.rule)
        },
        onHoverChange: (isHovered: boolean) => {
          this.isHovered = isHovered
        }
      }) {
        Column({ space: 14 }) {
          Row({ space: 12 }) {
            Column() {
              Image(this.getRuleIcon(this.rule.type))
                .width(this.isHovered ? AppStyles.ICON_SIZE_SM + 1 : AppStyles.ICON_SIZE_SM)
                .height(this.isHovered ? AppStyles.ICON_SIZE_SM + 1 : AppStyles.ICON_SIZE_SM)
                .fillColor(Color.White)
                .draggable(false)
            }
            .width(AppStyles.BUTTON_HEIGHT)
            .height(AppStyles.BUTTON_HEIGHT)
            .borderRadius(AppStyles.RADIUS_LG)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor(this.getRuleTypeTextColor(this.rule.type))
            .shadow(this.isHovered ? HoverUtils.getShadow(this.currentTheme, true, false) : ShadowStyle.OUTER_DEFAULT_SM)
            .scale({
              x: HoverUtils.getScale(this.isHovered, 1.04),
              y: HoverUtils.getScale(this.isHovered, 1.04)
            })

            Column({ space: 6 }) {
              Text(this.rule.name ?? '-')
                .fontSize(AppStyles.FONT_SIZE_BODY)
                .fontWeight(this.isHovered ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
                .opacity(this.isHovered ? 1 : AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              Row({ space: 8 }) {
                Text(this.getRuleTypeLabel(this.rule.type))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(this.getRuleTypeTextColor(this.rule.type))
                  .borderRadius(10)
                  .padding({ left: AppStyles.SPACING_CHIP, right: AppStyles.SPACING_CHIP, top: AppStyles.PADDING_XS, bottom: AppStyles.PADDING_XS })

                Text(this.getDirectionLabel(this.rule.direction))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(ActionButtonStyles.getPrimaryForeground(this.currentTheme))
                  .borderRadius(10)
                  .padding({ left: AppStyles.SPACING_CHIP, right: AppStyles.SPACING_CHIP, top: AppStyles.PADDING_XS, bottom: AppStyles.PADDING_XS })

                Text(this.getActionLabel(this.rule.action))
                  .fontSize(AppStyles.FONT_SIZE_CAPTION)
                  .fontColor(this.getActionTextColor(this.rule.action))
                  .borderRadius(10)
                  .padding({ left: AppStyles.SPACING_CHIP, right: AppStyles.SPACING_CHIP, top: AppStyles.PADDING_XS, bottom: AppStyles.PADDING_XS })
              }
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            Row({ space: 8 }) {
              this.deleteActionButton()
            }
          }
          .width('100%')

          Column({ space: 10 }) {
            this.detailRow(FirewallDialogStrings.USER_SCOPE, this.userScopeLabel)
            if (this.rule.type === netFirewall.NetFirewallRuleType.RULE_IP) {
              this.detailRow(this.getIpAddressLabel(), this.getRuleAddress())
              this.detailRow(this.getPrimaryPortLabel(), this.getPrimaryPortValue())
            } else if (this.rule.type === netFirewall.NetFirewallRuleType.RULE_DNS) {
              this.detailRow(FirewallDialogStrings.PRIMARY_DNS, this.rule.dns?.primaryDns ?? '-')
              this.detailRow(FirewallDialogStrings.STANDBY_DNS, this.rule.dns?.standbyDns ?? '-')
            } else {
              this.detailRow(FirewallDialogStrings.REMOTE_ADDRESS, this.getRuleAddress())
              this.detailRow(FirewallDialogStrings.LOCAL_PORT, this.getRuleLocalPort())
              this.detailRow(FirewallDialogStrings.REMOTE_PORT, this.getRuleRemotePort())
            }
            this.detailRow(FirewallDialogStrings.PROTOCOL, this.getProtocolLabel())
          }
          .width('100%')
        }
        .width('100%')
        .padding(AppStyles.PADDING_XL)
      }
    }
    .width('100%')
    .padding({ left: AppStyles.PADDING_LG, right: AppStyles.PADDING_LG })
    .clip(false)
  }

  @Builder
  private deleteActionButton() {
    if (this.isDeleting) {
      Row({ space: 8 }) {
        LoadingProgress()
          .width(AppStyles.INLINE_LOADING_INDICATOR_SIZE)
          .height(AppStyles.INLINE_LOADING_INDICATOR_SIZE)

        Text(FirewallRuleStrings.DELETE_TITLE)
          .fontSize(ActionButtonStyles.FONT_SIZE)
          .fontColor(ActionButtonStyles.getDangerForeground(this.currentTheme))
          .fontWeight(FontWeight.Regular)
      }
      .height(ActionButtonStyles.HEIGHT)
      .padding({
        left: ActionButtonStyles.HORIZONTAL_PADDING_START,
        right: ActionButtonStyles.HORIZONTAL_PADDING_END
      })
      .borderRadius(AppStyles.RADIUS_SM)
      .backgroundColor(ActionButtonStyles.getDangerBackground(this.currentTheme, false, false))
      .opacity(0.72)
      .alignItems(VerticalAlign.Center)
    } else {
      IconTextActionButton({
        label: FirewallRuleStrings.DELETE_TITLE,
        icon: AppResources.TRASH_ICON,
        kind: 'danger',
        currentTheme: this.currentTheme,
        onTap: () => {
          this.onDeleteRule(this.rule)
        }
      })
    }
  }

  @Builder
  private detailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(this.isHovered
          ? AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY
          : AppColors.getColors(this.currentTheme).TEXT_TERTIARY_OPACITY)
        .width(92)

      Text(value)
        .fontSize(AppStyles.FONT_SIZE_CAPTION)
        .fontColor(AppColors.getColors(this.currentTheme).TEXT_PRIMARY)
        .opacity(this.isHovered ? AppColors.getColors(this.currentTheme).TEXT_PRIMARY_OPACITY :
          AppColors.getColors(this.currentTheme).TEXT_SECONDARY_OPACITY)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

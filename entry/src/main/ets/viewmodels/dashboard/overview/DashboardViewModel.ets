import { common } from '@kit.AbilityKit'
import { AppColors } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { CommonStrings } from '../../../constants/CommonStrings'
import { RouteIds } from '../../../constants/RouteIds'
import { DashboardStrings } from '../../../constants/modules/DashboardStrings'
import { FirewallDialogStrings } from '../../../constants/modules/DialogStrings'
import { FirewallStrings } from '../../../constants/modules/FirewallStrings'
import { DashboardModuleCardState, DashboardQuickEntryState } from '../../../models/DashboardModels'
import { EnterpriseAdminService } from '../../../services/admin/activation/EnterpriseAdminService'
import { FirewallModeService } from '../../../services/firewall/mode-control/FirewallModeService'
import { FirewallService } from '../../../services/firewall/policy/FirewallService'
import { PeripheralTraceRepository } from '../../../services/peripheral/connection-record/PeripheralTraceRepository'
import { LogRepository } from '../../../services/log-manage/repository/LogRepository'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'DashboardViewModel'
type DashboardQuickEntryId = 'firewall' | 'log-manage' | 'peripheral-manage' | 'identity' | 'tool-settings' | 'help-feedback'

@ObservedV2
export class DashboardViewModel {
  @Trace moduleCards: DashboardModuleCardState[] = []
  @Trace quickEntries: DashboardQuickEntryState[] = []

  private context: common.UIAbilityContext | null = null
  private logListenerId: number = -1
  private peripheralTraceListenerId: number = -1

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context
    this.quickEntries = this.buildQuickEntries()
    await this.refreshAll()
    this.registerListeners()
  }

  destroy(): void {
    if (this.logListenerId > 0) {
      LogRepository.removeChangeListener(this.logListenerId)
      this.logListenerId = -1
    }
    if (this.peripheralTraceListenerId > 0) {
      PeripheralTraceRepository.removeChangeListener(this.peripheralTraceListenerId)
      this.peripheralTraceListenerId = -1
    }
  }

  async refreshAll(): Promise<void> {
    this.moduleCards = await this.buildModuleCards()
  }

  async refreshStaticStatuses(): Promise<void> {
    await this.refreshAll()
  }

  private registerListeners(): void {
    if (this.logListenerId <= 0) {
      this.logListenerId = LogRepository.addChangeListener(() => {
        void this.refreshLiveCards(false, true)
      })
    }
    if (this.peripheralTraceListenerId <= 0) {
      this.peripheralTraceListenerId = PeripheralTraceRepository.addChangeListener(() => {
        void this.refreshLiveCards(true, false)
      })
    }
  }

  private async buildModuleCards(): Promise<DashboardModuleCardState[]> {
    return [
      this.buildAdminCard(),
      await this.buildFirewallCard(),
      this.buildLogCard(),
      this.buildPeripheralCard()
    ]
  }

  private buildAdminCard(): DashboardModuleCardState {
    let activated = EnterpriseAdminService.probeActivation().activated
    return this.createModuleCard(
      RouteIds.ADMIN,
      DashboardStrings.adminTitle,
      activated ? DashboardStrings.adminReady : DashboardStrings.adminPending,
      activated ? DashboardStrings.adminReadyDetail : DashboardStrings.adminPendingDetail,
      AppColors.WARNING,
      AppColors.GRADIENT_IDENTITY_END,
      AppResources.IDENTITY_ICON
    )
  }

  private async buildFirewallCard(): Promise<DashboardModuleCardState> {
    let enabled = false
    let modeText = FirewallStrings.getModeTitle('custom')
    try {
      let policy = await FirewallService.getFirewallPolicy()
      enabled = policy?.isOpen ?? false
      if (this.context) {
        modeText = FirewallStrings.getModeTitle(await FirewallModeService.getCurrentMode(this.context))
      }
    } catch (err) {
      LogUtils.warn(TAG, `buildFirewallCard failed: ${JSON.stringify(err)}`)
    }

    return this.createModuleCard(
      RouteIds.FIREWALL,
      DashboardStrings.firewallTitle,
      enabled ? FirewallDialogStrings.SWITCH_ENABLED : FirewallDialogStrings.SWITCH_DISABLED,
      modeText,
      DashboardStrings.firewallGradient.start,
      DashboardStrings.firewallGradient.end,
      AppResources.FIREWALL_ICON
    )
  }

  private buildLogCard(): DashboardModuleCardState {
    let statistics = LogRepository.getStatistics()
    return this.createModuleCard(
      RouteIds.LOG_MANAGE,
      DashboardStrings.logTitle,
      `${statistics.todayCount}`,
      `${DashboardStrings.logTodayDetailPrefix}${statistics.totalCount}${DashboardStrings.logTodayDetailSuffix}`,
      DashboardStrings.logManageGradient.start,
      DashboardStrings.logManageGradient.end,
      AppResources.LOG_ICON
    )
  }

  private buildPeripheralCard(): DashboardModuleCardState {
    let stats = PeripheralTraceRepository.getStats()
    return this.createModuleCard(
      RouteIds.PERIPHERAL_MANAGE,
      DashboardStrings.peripheralTitle,
      `${stats.total}`,
      `${DashboardStrings.peripheralDetailPrefix}${stats.connects}${DashboardStrings.peripheralDetailMiddle}${stats.disconnects}${DashboardStrings.peripheralDetailSuffix}`,
      DashboardStrings.peripheralGradient.start,
      DashboardStrings.peripheralGradient.end,
      AppResources.PERIPHERAL_ICON
    )
  }

  private async refreshLiveCards(refreshPeripheral: boolean, refreshLog: boolean): Promise<void> {
    try {
      let nextCards = [...this.moduleCards]
      for (let index = 0; index < nextCards.length; index++) {
        let card = nextCards[index]
        if (refreshLog && card.id === RouteIds.LOG_MANAGE) {
          nextCards[index] = this.buildLogCard()
        } else if (refreshPeripheral && card.id === RouteIds.PERIPHERAL_MANAGE) {
          nextCards[index] = this.buildPeripheralCard()
        }
      }
      this.moduleCards = nextCards
    } catch (err) {
      LogUtils.warn(TAG, `refreshLiveCards failed: ${JSON.stringify(err)}`)
    }
  }

  private buildQuickEntries(): DashboardQuickEntryState[] {
    return [
      this.createQuickEntry(
        RouteIds.FIREWALL,
        CommonStrings.moduleFirewall,
        AppResources.FIREWALL_ICON,
        DashboardStrings.firewallGradient.start,
        DashboardStrings.firewallGradient.end,
        RouteIds.FIREWALL
      ),
      this.createQuickEntry(
        RouteIds.LOG_MANAGE,
        CommonStrings.moduleLogManage,
        AppResources.LOG_ICON,
        DashboardStrings.logManageGradient.start,
        DashboardStrings.logManageGradient.end,
        RouteIds.LOG_MANAGE
      ),
      this.createQuickEntry(
        RouteIds.PERIPHERAL_MANAGE,
        CommonStrings.modulePeripheralManage,
        AppResources.PERIPHERAL_ICON,
        DashboardStrings.peripheralGradient.start,
        DashboardStrings.peripheralGradient.end,
        RouteIds.PERIPHERAL_MANAGE
      ),
      this.createQuickEntry(
        RouteIds.IDENTITY,
        CommonStrings.moduleIdentity,
        AppResources.IDENTITY_ICON,
        DashboardStrings.identityGradient.start,
        DashboardStrings.identityGradient.end,
        RouteIds.IDENTITY
      ),
      this.createQuickEntry(
        RouteIds.TOOL_SETTINGS,
        CommonStrings.moduleToolSettings,
        AppResources.SETTINGS_ICON,
        DashboardStrings.toolSettingsGradient.start,
        DashboardStrings.toolSettingsGradient.end,
        RouteIds.TOOL_SETTINGS
      ),
      this.createQuickEntry(
        RouteIds.HELP_FEEDBACK,
        CommonStrings.moduleHelpFeedback,
        AppResources.HELP_ICON,
        DashboardStrings.helpFeedbackGradient.start,
        DashboardStrings.helpFeedbackGradient.end,
        RouteIds.HELP_FEEDBACK
      )
    ]
  }

  private createModuleCard(
    id: 'admin' | 'firewall' | 'log-manage' | 'peripheral-manage',
    title: string,
    primaryText: string,
    secondaryText: string,
    accentStart: string,
    accentEnd: string,
    icon: Resource
  ): DashboardModuleCardState {
    return {
      id: id,
      title: title,
      primaryText: primaryText,
      secondaryText: secondaryText,
      accentStart: accentStart,
      accentEnd: accentEnd,
      icon: icon
    }
  }

  private createQuickEntry(
    id: DashboardQuickEntryId,
    title: string,
    icon: Resource,
    accentStart: string,
    accentEnd: string,
    route: string
  ): DashboardQuickEntryState {
    return {
      id: id,
      title: title,
      icon: icon,
      accentStart: accentStart,
      accentEnd: accentEnd,
      route: route
    }
  }
}

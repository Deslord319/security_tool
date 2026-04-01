import { common } from '@kit.AbilityKit'
import { AppColors } from '../constants/AppConstants'
import { AppResources } from '../constants/AppResources'
import { CommonStrings } from '../constants/CommonStrings'
import { RouteIds } from '../constants/RouteIds'
import { DashboardStrings } from '../constants/modules/DashboardStrings'
import { FirewallStrings } from '../constants/modules/FirewallStrings'
import { DashboardModuleCardState, DashboardQuickEntryState } from '../models/DashboardModels'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { FirewallModeService } from '../services/FirewallModeService'
import { FirewallService } from '../services/FirewallService'
import { LogStorageChangeEvent, LogStorageService } from '../services/LogStorageService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'DashboardViewModel'
type DashboardQuickEntryId = 'firewall' | 'log' | 'peripheral' | 'identity' | 'tool-settings' | 'help-feedback'

@Observed
export class DashboardViewModel {
  moduleCards: DashboardModuleCardState[] = []
  quickEntries: DashboardQuickEntryState[] = []

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
      LogStorageService.removeChangeListener(this.logListenerId)
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
      this.logListenerId = LogStorageService.addChangeListener((_event: LogStorageChangeEvent) => {
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
      RouteIds.MODULE_ADMIN,
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
      RouteIds.MODULE_FIREWALL,
      DashboardStrings.firewallTitle,
      enabled ? DashboardStrings.firewallEnabled : DashboardStrings.firewallDisabled,
      modeText,
      DashboardStrings.firewallGradient.start,
      DashboardStrings.firewallGradient.end,
      AppResources.FIREWALL_ICON
    )
  }

  private buildLogCard(): DashboardModuleCardState {
    let statistics = LogStorageService.getStatistics()
    return this.createModuleCard(
      RouteIds.MODULE_LOG,
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
      RouteIds.MODULE_PERIPHERAL,
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
        if (refreshLog && card.id === 'log') {
          nextCards[index] = this.buildLogCard()
        } else if (refreshPeripheral && card.id === 'peripheral') {
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
        RouteIds.ENTRY_FIREWALL,
        CommonStrings.moduleFirewall,
        AppResources.FIREWALL_ICON,
        DashboardStrings.firewallGradient.start,
        DashboardStrings.firewallGradient.end,
        RouteIds.FIREWALL
      ),
      this.createQuickEntry(
        RouteIds.ENTRY_LOG,
        CommonStrings.moduleLogManage,
        AppResources.LOG_ICON,
        DashboardStrings.logManageGradient.start,
        DashboardStrings.logManageGradient.end,
        RouteIds.LOG_MANAGE
      ),
      this.createQuickEntry(
        RouteIds.ENTRY_PERIPHERAL,
        CommonStrings.modulePeripheralManage,
        AppResources.PERIPHERAL_ICON,
        DashboardStrings.peripheralGradient.start,
        DashboardStrings.peripheralGradient.end,
        RouteIds.PERIPHERAL_MANAGE
      ),
      this.createQuickEntry(
        RouteIds.ENTRY_IDENTITY,
        CommonStrings.moduleIdentity,
        AppResources.IDENTITY_ICON,
        DashboardStrings.identityGradient.start,
        DashboardStrings.identityGradient.end,
        RouteIds.IDENTITY
      ),
      this.createQuickEntry(
        RouteIds.ENTRY_TOOL_SETTINGS,
        CommonStrings.moduleToolSettings,
        AppResources.SETTINGS_ICON,
        DashboardStrings.toolSettingsGradient.start,
        DashboardStrings.toolSettingsGradient.end,
        RouteIds.TOOL_SETTINGS
      ),
      this.createQuickEntry(
        RouteIds.ENTRY_HELP_FEEDBACK,
        CommonStrings.moduleHelpFeedback,
        AppResources.HELP_ICON,
        DashboardStrings.helpFeedbackGradient.start,
        DashboardStrings.helpFeedbackGradient.end,
        RouteIds.HELP_FEEDBACK
      )
    ]
  }

  private createModuleCard(
    id: 'admin' | 'firewall' | 'log' | 'peripheral',
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

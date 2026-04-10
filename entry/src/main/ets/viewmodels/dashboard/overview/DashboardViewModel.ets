import { common } from '@kit.AbilityKit'
import { AppColors } from '../../../constants/AppConstants'
import { AppResources } from '../../../constants/AppResources'
import { ModuleText, StatusText } from '../../../constants/StringCatalog'
import { RouteIds } from '../../../constants/RouteIds'
import {
  DashboardAdminStrings,
  DashboardFirewallCardStrings,
  DashboardGradientPalette,
  DashboardLogCardStrings,
  DashboardPeripheralCardStrings
} from '../../../constants/modules/DashboardStrings'
import { FirewallDialogStrings } from '../../../constants/modules/DialogStrings'
import { getFirewallModeTitle } from '../../../constants/modules/FirewallStrings'
import { DashboardModuleCardState, DashboardQuickEntryState } from '../../../models/DashboardModels'
import { EnterpriseAdminService } from '../../../services/admin/activation/EnterpriseAdminService'
import { FirewallService } from '../../../services/firewall/FirewallService'
import { LogEntryRepository } from '../../../services/log-manage/repository/LogEntryRepository'
import { PeripheralTraceEntryRepository } from '../../../services/peripheral/connection-record/PeripheralTraceEntryRepository'
import { PeripheralTraceMaintenanceService } from '../../../services/peripheral/connection-record/PeripheralTraceMaintenanceService'
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
    await PeripheralTraceMaintenanceService.initialize(context)
    this.quickEntries = this.buildQuickEntries()
    await this.refreshAll()
    this.registerListeners()
  }

  destroy(): void {
    if (this.logListenerId > 0) {
      LogEntryRepository.removeChangeListener(this.logListenerId)
      this.logListenerId = -1
    }
    if (this.peripheralTraceListenerId > 0) {
      PeripheralTraceEntryRepository.removeChangeListener(this.peripheralTraceListenerId)
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
      this.logListenerId = LogEntryRepository.addChangeListener(() => {
        void this.refreshLiveCards(false, true)
      })
    }
    if (this.peripheralTraceListenerId <= 0) {
      this.peripheralTraceListenerId = PeripheralTraceEntryRepository.addChangeListener(() => {
        void this.refreshLiveCards(true, false)
      })
    }
  }

  private async buildModuleCards(): Promise<DashboardModuleCardState[]> {
    return [
      this.buildAdminCard(),
      await this.buildFirewallCard(),
      await this.buildLogCard(),
      await this.buildPeripheralCard()
    ]
  }

  private buildAdminCard(): DashboardModuleCardState {
    let activated = EnterpriseAdminService.probeActivation().activated
    return this.createModuleCard(
      'admin-status',
      DashboardAdminStrings.TITLE,
      activated ? StatusText.ACTIVATED : DashboardAdminStrings.PENDING,
      activated ? DashboardAdminStrings.READY_DETAIL : DashboardAdminStrings.PENDING_DETAIL,
      AppColors.WARNING,
      AppColors.GRADIENT_IDENTITY_END,
      AppResources.IDENTITY_ICON
    )
  }

  private async buildFirewallCard(): Promise<DashboardModuleCardState> {
    let enabled = false
    let modeText = getFirewallModeTitle('custom')
    try {
      if (this.context) {
        let overview = await FirewallService.loadOverviewState(this.context)
        enabled = overview.enabled
        modeText = getFirewallModeTitle(overview.currentMode)
      } else {
        let policy = await FirewallService.getFirewallPolicy()
        enabled = policy?.isOpen ?? false
      }
    } catch (err) {
      LogUtils.warn(TAG, `buildFirewallCard failed: ${JSON.stringify(err)}`)
    }

    return this.createModuleCard(
      RouteIds.FIREWALL,
      DashboardFirewallCardStrings.TITLE,
      enabled ? FirewallDialogStrings.SWITCH_ENABLED : FirewallDialogStrings.SWITCH_DISABLED,
      modeText,
      DashboardGradientPalette.firewallGradient.start,
      DashboardGradientPalette.firewallGradient.end,
      AppResources.FIREWALL_ICON
    )
  }

  private async buildLogCard(): Promise<DashboardModuleCardState> {
    let statistics = await LogEntryRepository.getStatistics()
    return this.createModuleCard(
      RouteIds.LOG_MANAGE,
      DashboardLogCardStrings.TITLE,
      `${statistics.todayCount}`,
      `${DashboardLogCardStrings.TODAY_DETAIL_PREFIX}${statistics.totalCount}${DashboardLogCardStrings.TODAY_DETAIL_SUFFIX}`,
      DashboardGradientPalette.logManageGradient.start,
      DashboardGradientPalette.logManageGradient.end,
      AppResources.LOG_ICON
    )
  }

  private async buildPeripheralCard(): Promise<DashboardModuleCardState> {
    let stats = await PeripheralTraceEntryRepository.getStatistics()
    return this.createModuleCard(
      RouteIds.PERIPHERAL_MANAGE,
      DashboardPeripheralCardStrings.TITLE,
      `${stats.total}`,
      `${DashboardPeripheralCardStrings.DETAIL_PREFIX}${stats.connects}${DashboardPeripheralCardStrings.DETAIL_MIDDLE}${stats.disconnects}${DashboardPeripheralCardStrings.DETAIL_SUFFIX}`,
      DashboardGradientPalette.peripheralGradient.start,
      DashboardGradientPalette.peripheralGradient.end,
      AppResources.PERIPHERAL_ICON
    )
  }

  private async refreshLiveCards(refreshPeripheral: boolean, refreshLog: boolean): Promise<void> {
    try {
      let nextCards = [...this.moduleCards]
      for (let index = 0; index < nextCards.length; index++) {
        let card = nextCards[index]
        if (refreshLog && card.id === RouteIds.LOG_MANAGE) {
          nextCards[index] = await this.buildLogCard()
        } else if (refreshPeripheral && card.id === RouteIds.PERIPHERAL_MANAGE) {
          nextCards[index] = await this.buildPeripheralCard()
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
        ModuleText.FIREWALL,
        AppResources.FIREWALL_ICON,
        DashboardGradientPalette.firewallGradient.start,
        DashboardGradientPalette.firewallGradient.end,
        RouteIds.FIREWALL
      ),
      this.createQuickEntry(
        RouteIds.LOG_MANAGE,
        ModuleText.LOG_MANAGE,
        AppResources.LOG_ICON,
        DashboardGradientPalette.logManageGradient.start,
        DashboardGradientPalette.logManageGradient.end,
        RouteIds.LOG_MANAGE
      ),
      this.createQuickEntry(
        RouteIds.PERIPHERAL_MANAGE,
        ModuleText.PERIPHERAL_MANAGE,
        AppResources.PERIPHERAL_ICON,
        DashboardGradientPalette.peripheralGradient.start,
        DashboardGradientPalette.peripheralGradient.end,
        RouteIds.PERIPHERAL_MANAGE
      ),
      this.createQuickEntry(
        RouteIds.IDENTITY,
        ModuleText.IDENTITY,
        AppResources.IDENTITY_ICON,
        DashboardGradientPalette.identityGradient.start,
        DashboardGradientPalette.identityGradient.end,
        RouteIds.IDENTITY
      ),
      this.createQuickEntry(
        RouteIds.TOOL_SETTINGS,
        ModuleText.TOOL_SETTINGS,
        AppResources.SETTINGS_ICON,
        DashboardGradientPalette.toolSettingsGradient.start,
        DashboardGradientPalette.toolSettingsGradient.end,
        RouteIds.TOOL_SETTINGS
      ),
      this.createQuickEntry(
        RouteIds.HELP_FEEDBACK,
        ModuleText.HELP_FEEDBACK,
        AppResources.HELP_ICON,
        DashboardGradientPalette.helpFeedbackGradient.start,
        DashboardGradientPalette.helpFeedbackGradient.end,
        RouteIds.HELP_FEEDBACK
      )
    ]
  }

  private createModuleCard(
    id: 'admin-status' | 'firewall' | 'log-manage' | 'peripheral-manage',
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

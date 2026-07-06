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
import { getFirewallModeTitle } from '../../../constants/modules/FirewallStrings'
import { DashboardModuleCardState, DashboardQuickEntryState } from '../../../models/DashboardModels'
import { EnterpriseAdminService } from '../../../services/admin/activation/EnterpriseAdminService'
import { FirewallService } from '../../../services/firewall/FirewallService'
import { LogEntryRepository } from '../../../services/log-manage/repository/LogEntryRepository'
import { PeripheralTraceEntryRepository } from '../../../services/peripheral/connection-record/PeripheralTraceEntryRepository'
import { PeripheralTraceMaintenanceService } from '../../../services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'DashboardViewModel'
type DashboardQuickEntryId = 'firewall' | 'log-manage' | 'peripheral-manage' | 'permission-manage' | 'identity' | 'tool-settings'

@ObservedV2
export class DashboardViewModel {
  @Trace moduleCards: DashboardModuleCardState[] = []
  @Trace quickEntries: DashboardQuickEntryState[] = []

  private context: common.UIAbilityContext | null = null
  private logListenerId: number = -1
  private peripheralTraceListenerId: number = -1

  prepareInitialContent(): void {
    if (this.quickEntries.length === 0) {
      this.quickEntries = this.buildQuickEntries()
    }
    if (this.moduleCards.length === 0) {
      this.moduleCards = this.buildFallbackModuleCards()
    }
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context
    this.prepareInitialContent()
    try {
      let initialized = await PeripheralTraceMaintenanceService.initialize(context)
      if (!initialized.success) {
        LogUtils.warn(TAG, `initialize peripheral trace storage failed: ${initialized.code}`)
      }
    } catch (err) {
      LogUtils.warn(TAG, `initialize peripheral trace storage failed: ${JSON.stringify(err)}`)
    }
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
    try {
      this.moduleCards = await this.buildModuleCards()
    } catch (err) {
      LogUtils.warn(TAG, `refreshAll failed: ${JSON.stringify(err)}`)
      this.moduleCards = this.buildFallbackModuleCards()
    }
  }

  async refreshStaticStatuses(): Promise<void> {
    await this.refreshAll()
  }

  private registerListeners(): void {
    if (this.logListenerId <= 0) {
      this.logListenerId = LogEntryRepository.addChangeListener(() => {
        this.refreshLiveCards(false, true)
      })
    }
    if (this.peripheralTraceListenerId <= 0) {
      this.peripheralTraceListenerId = PeripheralTraceEntryRepository.addChangeListener(() => {
        this.refreshLiveCards(true, false)
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
    let activated = false
    try {
      activated = EnterpriseAdminService.probeActivation().activated
    } catch (err) {
      LogUtils.warn(TAG, `buildAdminCard failed: ${JSON.stringify(err)}`)
    }
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
      }
    } catch (err) {
      LogUtils.warn(TAG, `buildFirewallCard failed: ${JSON.stringify(err)}`)
    }

    return this.createModuleCard(
      RouteIds.FIREWALL,
      DashboardFirewallCardStrings.TITLE,
      enabled ? StatusText.ENABLED : StatusText.DISABLED,
      modeText,
      DashboardGradientPalette.firewallGradient.start,
      DashboardGradientPalette.firewallGradient.end,
      AppResources.FIREWALL_ICON
    )
  }

  private async buildLogCard(): Promise<DashboardModuleCardState> {
    let todayCount = 0
    let totalCount = 0
    try {
      let statistics = await LogEntryRepository.getStatistics()
      todayCount = statistics.todayCount
      totalCount = statistics.totalCount
    } catch (err) {
      LogUtils.warn(TAG, `buildLogCard failed: ${JSON.stringify(err)}`)
    }
    return this.createModuleCard(
      RouteIds.LOG_MANAGE,
      DashboardLogCardStrings.TITLE,
      `${todayCount}`,
      `${DashboardLogCardStrings.TODAY_DETAIL_PREFIX}${totalCount}${DashboardLogCardStrings.TODAY_DETAIL_SUFFIX}`,
      DashboardGradientPalette.logManageGradient.start,
      DashboardGradientPalette.logManageGradient.end,
      AppResources.LOG_ICON
    )
  }

  private async buildPeripheralCard(): Promise<DashboardModuleCardState> {
    let total = 0
    let connects = 0
    let disconnects = 0
    let policyChanges = 0
    try {
      let stats = await PeripheralTraceEntryRepository.getStatistics({
        sources: ['runtime_event', 'policy_snapshot'],
        actions: ['connect', 'disconnect', 'discover']
      })
      total = stats.total
      connects = stats.connects
      disconnects = stats.disconnects
      policyChanges = stats.policyChanges
    } catch (err) {
      LogUtils.warn(TAG, `buildPeripheralCard failed: ${JSON.stringify(err)}`)
    }
    return this.createModuleCard(
      RouteIds.PERIPHERAL_MANAGE,
      DashboardPeripheralCardStrings.TITLE,
      `${total}`,
      `${DashboardPeripheralCardStrings.DETAIL_PREFIX}${connects}${DashboardPeripheralCardStrings.DETAIL_MIDDLE}${disconnects}${DashboardPeripheralCardStrings.DETAIL_POLICY_MIDDLE}${policyChanges}${DashboardPeripheralCardStrings.DETAIL_SUFFIX}`,
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

  private buildFallbackModuleCards(): DashboardModuleCardState[] {
    return [
      this.buildAdminCard(),
      this.createModuleCard(
        RouteIds.FIREWALL,
        DashboardFirewallCardStrings.TITLE,
        StatusText.DISABLED,
        getFirewallModeTitle('custom'),
        DashboardGradientPalette.firewallGradient.start,
        DashboardGradientPalette.firewallGradient.end,
        AppResources.FIREWALL_ICON
      ),
      this.createModuleCard(
        RouteIds.LOG_MANAGE,
        DashboardLogCardStrings.TITLE,
        '0',
        `${DashboardLogCardStrings.TODAY_DETAIL_PREFIX}0${DashboardLogCardStrings.TODAY_DETAIL_SUFFIX}`,
        DashboardGradientPalette.logManageGradient.start,
        DashboardGradientPalette.logManageGradient.end,
        AppResources.LOG_ICON
      ),
      this.createModuleCard(
        RouteIds.PERIPHERAL_MANAGE,
        DashboardPeripheralCardStrings.TITLE,
        '0',
        `${DashboardPeripheralCardStrings.DETAIL_PREFIX}0${DashboardPeripheralCardStrings.DETAIL_MIDDLE}0${DashboardPeripheralCardStrings.DETAIL_POLICY_MIDDLE}0${DashboardPeripheralCardStrings.DETAIL_SUFFIX}`,
        DashboardGradientPalette.peripheralGradient.start,
        DashboardGradientPalette.peripheralGradient.end,
        AppResources.PERIPHERAL_ICON
      )
    ]
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
        RouteIds.PERMISSION_MANAGE,
        ModuleText.PERMISSION_MANAGE,
        AppResources.PERMISSION_ICON,
        DashboardGradientPalette.permissionGradient.start,
        DashboardGradientPalette.permissionGradient.end,
        RouteIds.PERMISSION_MANAGE
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

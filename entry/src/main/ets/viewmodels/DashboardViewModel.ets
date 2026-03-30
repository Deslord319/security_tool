import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppColors, Routes } from '../constants/AppConstants'
import { DashboardStrings } from '../constants/modules/DashboardStrings'
import { FirewallStrings } from '../constants/modules/FirewallStrings'
import { DashboardModuleCardState, DashboardQuickEntryState } from '../models/DashboardModels'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { FirewallModeService } from '../services/FirewallModeService'
import { FirewallService } from '../services/FirewallService'
import { LogStorageChangeEvent, LogStorageService } from '../services/LogStorageService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'

const TAG = 'DashboardViewModel'
const DOMAIN = 0x0014
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
      'admin',
      DashboardStrings.adminTitle,
      activated ? DashboardStrings.adminReady : DashboardStrings.adminPending,
      activated ? DashboardStrings.adminReadyDetail : DashboardStrings.adminPendingDetail,
      AppColors.WARNING,
      AppColors.GRADIENT_IDENTITY_END,
      $r('app.media.identity')
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
      hilog.warn(DOMAIN, TAG, `buildFirewallCard failed: ${JSON.stringify(err)}`)
    }

    return this.createModuleCard(
      'firewall',
      DashboardStrings.firewallTitle,
      enabled ? DashboardStrings.firewallEnabled : DashboardStrings.firewallDisabled,
      modeText,
      DashboardStrings.firewallGradient.start,
      DashboardStrings.firewallGradient.end,
      $r('app.media.firewall')
    )
  }

  private buildLogCard(): DashboardModuleCardState {
    let statistics = LogStorageService.getStatistics()
    return this.createModuleCard(
      'log',
      DashboardStrings.logTitle,
      `${statistics.todayCount}`,
      `${DashboardStrings.logTodayDetailPrefix}${statistics.totalCount}${DashboardStrings.logTodayDetailSuffix}`,
      DashboardStrings.logManageGradient.start,
      DashboardStrings.logManageGradient.end,
      $r('app.media.log')
    )
  }

  private buildPeripheralCard(): DashboardModuleCardState {
    let stats = PeripheralTraceRepository.getStats()
    return this.createModuleCard(
      'peripheral',
      DashboardStrings.peripheralTitle,
      `${stats.total}`,
      `${DashboardStrings.peripheralDetailPrefix}${stats.connects}${DashboardStrings.peripheralDetailMiddle}${stats.disconnects}${DashboardStrings.peripheralDetailSuffix}`,
      DashboardStrings.peripheralGradient.start,
      DashboardStrings.peripheralGradient.end,
      $r('app.media.peripheral')
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
      hilog.warn(DOMAIN, TAG, `refreshLiveCards failed: ${JSON.stringify(err)}`)
    }
  }

  private buildQuickEntries(): DashboardQuickEntryState[] {
    return [
      this.createQuickEntry(
        'firewall',
        DashboardStrings.firewallTitle,
        $r('app.media.firewall'),
        DashboardStrings.firewallGradient.start,
        DashboardStrings.firewallGradient.end,
        Routes.FIREWALL
      ),
      this.createQuickEntry(
        'log',
        DashboardStrings.logTitle,
        $r('app.media.log'),
        DashboardStrings.logManageGradient.start,
        DashboardStrings.logManageGradient.end,
        Routes.LOG_MANAGE
      ),
      this.createQuickEntry(
        'peripheral',
        DashboardStrings.peripheralTitle,
        $r('app.media.peripheral'),
        DashboardStrings.peripheralGradient.start,
        DashboardStrings.peripheralGradient.end,
        Routes.PERIPHERAL_MANAGE
      ),
      this.createQuickEntry(
        'identity',
        DashboardStrings.identityTitle,
        $r('app.media.identity'),
        DashboardStrings.identityGradient.start,
        DashboardStrings.identityGradient.end,
        Routes.IDENTITY
      ),
      this.createQuickEntry(
        'tool-settings',
        DashboardStrings.toolSettingsTitle,
        $r('app.media.settings'),
        DashboardStrings.toolSettingsGradient.start,
        DashboardStrings.toolSettingsGradient.end,
        Routes.TOOL_SETTINGS
      ),
      this.createQuickEntry(
        'help-feedback',
        DashboardStrings.helpFeedbackTitle,
        $r('app.media.help'),
        DashboardStrings.helpFeedbackGradient.start,
        DashboardStrings.helpFeedbackGradient.end,
        Routes.HELP_FEEDBACK
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

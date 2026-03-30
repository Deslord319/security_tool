import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppColors, Routes } from '../constants/AppConstants'
import { CommonStrings } from '../constants/CommonStrings'
import { DashboardStrings } from '../constants/modules/DashboardStrings'
import { FirewallStrings } from '../constants/modules/FirewallStrings'
import {
  DashboardModuleCardState,
  DashboardQuickEntryState
} from '../models/DashboardModels'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { FirewallModeService } from '../services/FirewallModeService'
import { FirewallService } from '../services/FirewallService'
import { LogStorageChangeEvent, LogStorageService } from '../services/LogStorageService'
import { LogRuntimeCollectorService } from '../services/LogRuntimeCollectorService'
import { PeripheralRuntimeEventService } from '../services/PeripheralRuntimeEventService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'

const TAG = 'DashboardViewModel'
const DOMAIN = 0x0014

@Observed
export class DashboardViewModel {
  loading: boolean = false
  moduleCards: DashboardModuleCardState[] = []
  quickEntries: DashboardQuickEntryState[] = []

  private context: common.UIAbilityContext | null = null
  private logListenerId: number = -1
  private peripheralTraceListenerId: number = -1

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context
    this.quickEntries = this.buildQuickEntries()
    this.loading = true
    try {
      await this.refreshAll()
      this.registerListeners()
    } finally {
      this.loading = false
    }
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
    this.moduleCards = await this.buildModuleCards()
  }

  private registerListeners(): void {
    if (this.logListenerId <= 0) {
      this.logListenerId = LogStorageService.addChangeListener((_event: LogStorageChangeEvent) => {
        void this.refreshLogAndPeripheralCards(false, true)
      })
    }
    if (this.peripheralTraceListenerId <= 0) {
      this.peripheralTraceListenerId = PeripheralTraceRepository.addChangeListener(() => {
        void this.refreshLogAndPeripheralCards(true, false)
      })
    }
  }

  private async refreshLogAndPeripheralCards(
    refreshPeripheral: boolean,
    refreshLog: boolean
  ): Promise<void> {
    try {
      let cards = [...this.moduleCards]
      for (let index = 0; index < cards.length; index++) {
        let card = cards[index]
        if (refreshLog && card.id === 'log') {
          cards[index] = this.buildLogCard()
        } else if (refreshPeripheral && card.id === 'peripheral') {
          cards[index] = this.buildPeripheralCard()
        }
      }
      this.moduleCards = cards
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `refreshLogAndPeripheralCards failed: ${JSON.stringify(err)}`)
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
    let adminState = EnterpriseAdminService.probeActivation()
    return {
      id: 'admin',
      title: '管理员',
      primaryText: adminState.activated ? CommonStrings.statusActivated : CommonStrings.statusNotActivated,
      secondaryText: adminState.activated ? '企业管理员能力已就绪' : '需先激活企业管理员后再执行受控操作',
      statusText: adminState.activated ? '企业管理可用' : '等待激活',
      statusKind: adminState.activated ? 'success' : 'warning',
      accentStart: AppColors.WARNING,
      accentEnd: AppColors.GRADIENT_IDENTITY_END,
      icon: $r('app.media.identity'),
      route: Routes.IDENTITY,
      clickable: true
    }
  }

  private async buildFirewallCard(): Promise<DashboardModuleCardState> {
    let isEnabled = false
    let modeText = '自定义模式'
    try {
      let policy = await FirewallService.getFirewallPolicy()
      isEnabled = policy?.isOpen ?? false
      if (this.context) {
        modeText = FirewallStrings.getModeTitle(await FirewallModeService.getCurrentMode(this.context))
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `buildFirewallCard failed: ${JSON.stringify(err)}`)
    }

    return {
      id: 'firewall',
      title: CommonStrings.moduleFirewall,
      primaryText: isEnabled ? '已开启' : '已关闭',
      secondaryText: modeText,
      statusText: isEnabled ? '策略生效中' : '防护未开启',
      statusKind: isEnabled ? 'success' : 'warning',
      accentStart: DashboardStrings.firewallGradient.start,
      accentEnd: DashboardStrings.firewallGradient.end,
      icon: $r('app.media.firewall'),
      route: Routes.FIREWALL,
      clickable: true
    }
  }

  private buildLogCard(): DashboardModuleCardState {
    let statistics = LogStorageService.getStatistics()
    let collecting = LogRuntimeCollectorService.isCollecting()
    return {
      id: 'log',
      title: CommonStrings.moduleLogManage,
      primaryText: `${statistics.todayCount}`,
      secondaryText: `今日日志，累计 ${statistics.totalCount} 条`,
      statusText: collecting ? '采集中' : '未采集',
      statusKind: collecting ? 'success' : 'warning',
      accentStart: DashboardStrings.logManageGradient.start,
      accentEnd: DashboardStrings.logManageGradient.end,
      icon: $r('app.media.log'),
      route: Routes.LOG_MANAGE,
      clickable: true
    }
  }

  private buildPeripheralCard(): DashboardModuleCardState {
    let stats = PeripheralTraceRepository.getStats()
    let runtimeStatus = PeripheralRuntimeEventService.getStatus()
    let listening = runtimeStatus.running && runtimeStatus.capabilities.usbRuntimeEvents
    return {
      id: 'peripheral',
      title: CommonStrings.modulePeripheralManage,
      primaryText: `${stats.total}`,
      secondaryText: `连接 ${stats.connects} 次，断开 ${stats.disconnects} 次`,
      statusText: listening ? '监听中' : '未监听',
      statusKind: listening ? 'success' : 'warning',
      accentStart: DashboardStrings.peripheralGradient.start,
      accentEnd: DashboardStrings.peripheralGradient.end,
      icon: $r('app.media.peripheral'),
      route: Routes.PERIPHERAL_MANAGE,
      clickable: true
    }
  }

  private buildQuickEntries(): DashboardQuickEntryState[] {
    return [
      {
        id: 'identity',
        title: CommonStrings.moduleIdentity,
        icon: $r('app.media.identity'),
        accentStart: DashboardStrings.identityGradient.start,
        accentEnd: DashboardStrings.identityGradient.end,
        route: Routes.IDENTITY
      },
      {
        id: 'tool-settings',
        title: CommonStrings.moduleToolSettings,
        icon: $r('app.media.settings'),
        accentStart: DashboardStrings.toolSettingsGradient.start,
        accentEnd: DashboardStrings.toolSettingsGradient.end,
        route: Routes.TOOL_SETTINGS
      },
      {
        id: 'help-feedback',
        title: CommonStrings.moduleHelpFeedback,
        icon: $r('app.media.help'),
        accentStart: DashboardStrings.helpFeedbackGradient.start,
        accentEnd: DashboardStrings.helpFeedbackGradient.end,
        route: Routes.HELP_FEEDBACK
      }
    ]
  }
}

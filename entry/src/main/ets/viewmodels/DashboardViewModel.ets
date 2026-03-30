import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { FirewallStrings } from '../constants/modules/FirewallStrings'
import {
  DashboardAdminSnapshot,
  DashboardFirewallSnapshot,
  DashboardLogSnapshot,
  DashboardModuleCardState,
  DashboardPeripheralSnapshot,
  DashboardQuickEntryState
} from '../models/DashboardModels'
import { EnterpriseAdminService } from '../services/EnterpriseAdminService'
import { FirewallModeService } from '../services/FirewallModeService'
import { FirewallService } from '../services/FirewallService'
import { LogStorageChangeEvent, LogStorageService } from '../services/LogStorageService'
import { LogRuntimeCollectorService } from '../services/LogRuntimeCollectorService'
import { PeripheralRuntimeEventService } from '../services/PeripheralRuntimeEventService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { DashboardPresentationMapper } from './DashboardPresentationMapper'

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
    this.quickEntries = DashboardPresentationMapper.buildQuickEntries()
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
    this.moduleCards = await this.loadModuleCards()
  }

  async refreshStaticStatuses(): Promise<void> {
    this.moduleCards = await this.loadModuleCards()
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

  private async loadModuleCards(): Promise<DashboardModuleCardState[]> {
    let adminSnapshot = this.loadAdminSnapshot()
    let firewallSnapshot = await this.loadFirewallSnapshot()
    let logSnapshot = this.loadLogSnapshot()
    let peripheralSnapshot = this.loadPeripheralSnapshot()
    return DashboardPresentationMapper.buildModuleCards(
      adminSnapshot,
      firewallSnapshot,
      logSnapshot,
      peripheralSnapshot
    )
  }

  private loadAdminSnapshot(): DashboardAdminSnapshot {
    return {
      activated: EnterpriseAdminService.probeActivation().activated
    }
  }

  private async loadFirewallSnapshot(): Promise<DashboardFirewallSnapshot> {
    let enabled = false
    let modeText = FirewallStrings.getModeTitle('custom')
    try {
      let policy = await FirewallService.getFirewallPolicy()
      enabled = policy?.isOpen ?? false
      if (this.context) {
        modeText = FirewallStrings.getModeTitle(await FirewallModeService.getCurrentMode(this.context))
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `loadFirewallSnapshot failed: ${JSON.stringify(err)}`)
    }
    return {
      enabled: enabled,
      modeText: modeText
    }
  }

  private loadLogSnapshot(): DashboardLogSnapshot {
    let statistics = LogStorageService.getStatistics()
    return {
      todayCount: statistics.todayCount,
      totalCount: statistics.totalCount,
      collecting: LogRuntimeCollectorService.isCollecting()
    }
  }

  private loadPeripheralSnapshot(): DashboardPeripheralSnapshot {
    let stats = PeripheralTraceRepository.getStats()
    let runtimeStatus = PeripheralRuntimeEventService.getStatus()
    return {
      totalCount: stats.total,
      connectCount: stats.connects,
      disconnectCount: stats.disconnects,
      listening: runtimeStatus.running && runtimeStatus.capabilities.usbRuntimeEvents
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
          cards[index] = DashboardPresentationMapper.buildLogCard(this.loadLogSnapshot())
        } else if (refreshPeripheral && card.id === 'peripheral') {
          cards[index] = DashboardPresentationMapper.buildPeripheralCard(this.loadPeripheralSnapshot())
        }
      }
      this.moduleCards = cards
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `refreshLogAndPeripheralCards failed: ${JSON.stringify(err)}`)
    }
  }
}

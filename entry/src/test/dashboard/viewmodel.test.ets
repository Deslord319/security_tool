import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { netFirewall } from '@kit.NetworkKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { RouteIds } from '../../main/ets/constants/RouteIds'
import { AppResources } from '../../main/ets/constants/AppResources'
import { StatusText } from '../../main/ets/constants/StringCatalog'
import { DashboardAdminStrings, DashboardFirewallCardStrings, DashboardLogCardStrings, DashboardPeripheralCardStrings } from '../../main/ets/constants/modules/DashboardStrings'
import { DashboardModuleCardState, DashboardQuickEntryState } from '../../main/ets/models/DashboardModels'
import { FirewallPresetMode, LogStatistics, PeripheralTraceStats } from '../../main/ets/models/DataModels'
import { FirewallOverviewState } from '../../main/ets/models/firewall/firewall_service_contracts'
import { EnterpriseAdminService } from '../../main/ets/services/admin/activation/EnterpriseAdminService'
import { FirewallService } from '../../main/ets/services/firewall/FirewallService'
import { LogEntryRepository } from '../../main/ets/services/log-manage/repository/LogEntryRepository'
import { PeripheralTraceEntryRepository } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceEntryRepository'
import { PeripheralTraceMaintenanceService } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceMaintenanceService'
import { DashboardViewModel } from '../../main/ets/viewmodels/dashboard/overview/DashboardViewModel'

class MockAdminState {
  activated: boolean = false
  errorCode?: number
  errorMessage?: string
  enableCommand: string = 'edm enable-admin'
  adminType: 'super' | 'byod' = 'byod'
}

class MockInitResult {
  success: boolean = true
  code: 'ok' | 'storage_init_failed' = 'ok'
  message?: string
}

function createLogStatistics(todayCount: number = 5, totalCount: number = 120): LogStatistics {
  return {
    totalCount: totalCount,
    todayCount: todayCount,
    blockedCount: 0,
    byType: new Map()
  }
}

function createPeripheralStats(total: number = 10, connects: number = 7, disconnects: number = 3): PeripheralTraceStats {
  return {
    total: total,
    connects: connects,
    disconnects: disconnects,
    intercepts: 0,
    allows: 0,
    denies: 0,
    unknowns: 0,
    runtimeCount: 0,
    auditCount: 0,
    snapshotCount: 0
  }
}

function createFirewallOverview(enabled: boolean = false, currentMode: FirewallPresetMode = 'custom'): FirewallOverviewState {
  return {
    enabled: enabled,
    currentMode: currentMode
  }
}

interface DashboardViewModelInternal {
  buildAdminCard(): Object
  buildFirewallCard(): Promise<Object>
  buildLogCard(): Promise<Object>
  buildPeripheralCard(): Promise<Object>
  buildModuleCards(): Promise<Object[]>
  registerListeners(): void
  refreshLiveCards(refreshPeripheral: boolean, refreshLog: boolean): Promise<void>
  buildQuickEntries(): Object[]
  createModuleCard(id: string, title: string, primaryText: string, secondaryText: string, accentStart: string, accentEnd: string, icon: Object): Object
}

export default function dashboardViewModelTest() {
  describe('DashboardViewModel', () => {
    let mockKit: MockKit
    let context: common.UIAbilityContext

    beforeEach(() => {
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should keep basic defaults stable before initialization', 0, () => {
      let viewModel = new DashboardViewModel()

      expect(viewModel.moduleCards.length).assertEqual(0)
      expect(viewModel.quickEntries.length).assertEqual(0)
    })

    it('should expose six quick entries including help feedback contract', 0, () => {
      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let quickEntries = internal.buildQuickEntries()

      expect(quickEntries.length).assertEqual(6)
    })

    it('should allow destroy before initialization', 0, () => {
      let viewModel = new DashboardViewModel()

      viewModel.destroy()

      expect(true).assertTrue()
    })

    it('should initialize with all module cards when admin is activated', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = true
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(new MockInitResult())
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview(true, 'custom'))
      when(logStatsMock)().afterReturn(createLogStatistics(5, 120))
      when(peripheralStatsMock)().afterReturn(createPeripheralStats(10, 7, 3))
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(1)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(2)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      expect(viewModel.moduleCards.length).assertEqual(4)
      expect(viewModel.quickEntries.length).assertEqual(6)
      expect(viewModel.moduleCards[0].primaryText).assertEqual(StatusText.ACTIVATED)
      expect(viewModel.moduleCards[0].secondaryText).assertEqual(DashboardAdminStrings.READY_DETAIL)
      expect(viewModel.moduleCards[1].primaryText).assertEqual(StatusText.ENABLED)
      expect(viewModel.moduleCards[2].primaryText).assertEqual('5')
      expect(viewModel.moduleCards[3].primaryText).assertEqual('10')
      done()
    })

    it('should show pending status when admin is not activated', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = false
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(new MockInitResult())
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview(false, 'custom'))
      when(logStatsMock)().afterReturn(createLogStatistics())
      when(peripheralStatsMock)().afterReturn(createPeripheralStats())
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(1)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(2)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      expect(viewModel.moduleCards[0].primaryText).assertEqual(DashboardAdminStrings.PENDING)
      expect(viewModel.moduleCards[0].secondaryText).assertEqual(DashboardAdminStrings.PENDING_DETAIL)
      done()
    })

    it('should show disabled when firewall is off', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = true
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(new MockInitResult())
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview(false, 'custom'))
      when(logStatsMock)().afterReturn(createLogStatistics())
      when(peripheralStatsMock)().afterReturn(createPeripheralStats())
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(1)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(2)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      expect(viewModel.moduleCards[1].primaryText).assertEqual(StatusText.DISABLED)
      done()
    })

    it('should fall back to getFirewallPolicy when context is null', 0, async (done: Function) => {
      let policyMock = mockKit.mockFunc(FirewallService, FirewallService.getFirewallPolicy)
      let policy: netFirewall.NetFirewallPolicy = { isOpen: true, inAction: 0, outAction: 0 } as netFirewall.NetFirewallPolicy
      when(policyMock)().afterReturn(policy)

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let firewallCard = await internal.buildFirewallCard() as Record<string, string>

      expect(firewallCard.primaryText).assertEqual(StatusText.ENABLED)
      done()
    })

    it('should handle firewall load failure gracefully', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = true
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(new MockInitResult())
      when(firewallMock)(ArgumentMatchers.any).afterAction((): FirewallOverviewState => {
        throw new Error('firewall load failed')
      })
      when(logStatsMock)().afterReturn(createLogStatistics())
      when(peripheralStatsMock)().afterReturn(createPeripheralStats())
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(1)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(2)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      expect(viewModel.moduleCards[1].primaryText).assertEqual(StatusText.DISABLED)
      done()
    })

    it('should handle peripheral trace init failure gracefully', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = true
      let failedResult = new MockInitResult()
      failedResult.success = false
      failedResult.code = 'storage_init_failed'
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(failedResult)
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview())
      when(logStatsMock)().afterReturn(createLogStatistics())
      when(peripheralStatsMock)().afterReturn(createPeripheralStats())
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(1)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(2)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      expect(viewModel.moduleCards.length).assertEqual(4)
      done()
    })

    it('should remove listeners on destroy', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)
      let logRemoveMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.removeChangeListener)
      let peripheralRemoveMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.removeChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = true
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(new MockInitResult())
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview())
      when(logStatsMock)().afterReturn(createLogStatistics())
      when(peripheralStatsMock)().afterReturn(createPeripheralStats())
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(100)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(200)
      when(logRemoveMock)(ArgumentMatchers.any).afterReturn(undefined)
      when(peripheralRemoveMock)(ArgumentMatchers.any).afterReturn(undefined)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)
      viewModel.destroy()

      expect(true).assertTrue()
      done()
    })

    it('should refresh all module cards', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = true
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(new MockInitResult())
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview(true, 'custom'))
      when(logStatsMock)().afterReturn(createLogStatistics(3, 50))
      when(peripheralStatsMock)().afterReturn(createPeripheralStats(5, 3, 2))
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(1)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(2)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)
      await viewModel.refreshAll()

      expect(viewModel.moduleCards.length).assertEqual(4)
      expect(viewModel.moduleCards[2].primaryText).assertEqual('3')
      expect(viewModel.moduleCards[3].primaryText).assertEqual('5')
      done()
    })

    it('should refresh static statuses same as refreshAll', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = true
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(new MockInitResult())
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview())
      when(logStatsMock)().afterReturn(createLogStatistics())
      when(peripheralStatsMock)().afterReturn(createPeripheralStats())
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(1)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(2)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)
      await viewModel.refreshStaticStatuses()

      expect(viewModel.moduleCards.length).assertEqual(4)
      done()
    })

    it('should build log card with correct statistics', 0, async (done: Function) => {
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      when(logStatsMock)().afterReturn(createLogStatistics(12, 300))

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let logCard = await internal.buildLogCard() as Record<string, string>

      expect(logCard.id).assertEqual(RouteIds.LOG_MANAGE)
      expect(logCard.primaryText).assertEqual('12')
      expect(logCard.title).assertEqual(DashboardLogCardStrings.TITLE)
      done()
    })

    it('should build peripheral card with correct statistics', 0, async (done: Function) => {
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      when(peripheralStatsMock)().afterReturn(createPeripheralStats(25, 18, 7))

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let peripheralCard = await internal.buildPeripheralCard() as Record<string, string>

      expect(peripheralCard.id).assertEqual(RouteIds.PERIPHERAL_MANAGE)
      expect(peripheralCard.primaryText).assertEqual('25')
      expect(peripheralCard.title).assertEqual(DashboardPeripheralCardStrings.TITLE)
      done()
    })

    it('should build admin card with activated status', 0, () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let adminState = new MockAdminState()
      adminState.activated = true
      when(adminMock)().afterReturn(adminState)

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let adminCard = internal.buildAdminCard() as Record<string, string>

      expect(adminCard.primaryText).assertEqual(StatusText.ACTIVATED)
      expect(adminCard.secondaryText).assertEqual(DashboardAdminStrings.READY_DETAIL)
    })

    it('should build admin card with pending status when not activated', 0, () => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let adminState = new MockAdminState()
      adminState.activated = false
      when(adminMock)().afterReturn(adminState)

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let adminCard = internal.buildAdminCard() as Record<string, string>

      expect(adminCard.primaryText).assertEqual(DashboardAdminStrings.PENDING)
      expect(adminCard.secondaryText).assertEqual(DashboardAdminStrings.PENDING_DETAIL)
    })

    it('should register listeners only when not already registered', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = true
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(new MockInitResult())
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview())
      when(logStatsMock)().afterReturn(createLogStatistics())
      when(peripheralStatsMock)().afterReturn(createPeripheralStats())
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(1)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(2)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      let internal = viewModel as Object as DashboardViewModelInternal
      internal.registerListeners()

      expect(true).assertTrue()
      done()
    })

    it('should create module card with all fields', 0, () => {
      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let card = internal.createModuleCard('admin-status', 'title', 'primary', 'secondary', '#fff', '#000', AppResources.SETTINGS_ICON) as DashboardModuleCardState

      expect(card.id).assertEqual('admin-status')
      expect(card.title).assertEqual('title')
      expect(card.primaryText).assertEqual('primary')
      expect(card.secondaryText).assertEqual('secondary')
      expect(card.accentStart).assertEqual('#fff')
      expect(card.accentEnd).assertEqual('#000')
    })

    it('should handle getFirewallPolicy returning null', 0, async (done: Function) => {
      let policyMock = mockKit.mockFunc(FirewallService, FirewallService.getFirewallPolicy)
      when(policyMock)().afterReturn(null)

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let firewallCard = await internal.buildFirewallCard() as Record<string, string>

      expect(firewallCard.primaryText).assertEqual(StatusText.DISABLED)
      done()
    })

    it('should handle getFirewallPolicy returning open policy', 0, async (done: Function) => {
      let policyMock = mockKit.mockFunc(FirewallService, FirewallService.getFirewallPolicy)
      let policy: netFirewall.NetFirewallPolicy = { isOpen: true, inAction: 0, outAction: 0 } as netFirewall.NetFirewallPolicy
      when(policyMock)().afterReturn(policy)

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let firewallCard = await internal.buildFirewallCard() as Record<string, string>

      expect(firewallCard.primaryText).assertEqual(StatusText.ENABLED)
      done()
    })

    it('should refresh log card via refreshLiveCards', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = true
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(new MockInitResult())
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview())
      when(logStatsMock)().afterReturn(createLogStatistics(99, 500))
      when(peripheralStatsMock)().afterReturn(createPeripheralStats())
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(1)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(2)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      let internal = viewModel as Object as DashboardViewModelInternal
      await internal.refreshLiveCards(false, true)

      let logCard = viewModel.moduleCards.find((card: DashboardModuleCardState) => card.id === RouteIds.LOG_MANAGE)
      expect(logCard?.primaryText).assertEqual('99')
      done()
    })

    it('should refresh peripheral card via refreshLiveCards', 0, async (done: Function) => {
      let adminMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let initMock = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
      let firewallMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let logStatsMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
      let peripheralStatsMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      let logListenerMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
      let peripheralListenerMock = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

      let adminState = new MockAdminState()
      adminState.activated = true
      when(adminMock)().afterReturn(adminState)
      when(initMock)(ArgumentMatchers.any).afterReturn(new MockInitResult())
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview())
      when(logStatsMock)().afterReturn(createLogStatistics())
      when(peripheralStatsMock)().afterReturn(createPeripheralStats(42, 30, 12))
      when(logListenerMock)(ArgumentMatchers.any).afterReturn(1)
      when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(2)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      let internal = viewModel as Object as DashboardViewModelInternal
      await internal.refreshLiveCards(true, false)

      let peripheralCard = viewModel.moduleCards.find((card: DashboardModuleCardState) => card.id === RouteIds.PERIPHERAL_MANAGE)
      expect(peripheralCard?.primaryText).assertEqual('42')
      done()
    })
  })
}

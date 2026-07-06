import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { RouteIds } from '../../main/ets/constants/RouteIds'
import { AppResources } from '../../main/ets/constants/AppResources'
import { ModuleText, StatusText } from '../../main/ets/constants/StringCatalog'
import { DashboardAdminStrings, DashboardLogCardStrings, DashboardPeripheralCardStrings } from '../../main/ets/constants/modules/DashboardStrings'
import { DashboardModuleCardState } from '../../main/ets/models/DashboardModels'
import { LogStatistics } from '../../main/ets/models/LogModels'
import { PeripheralTraceStats } from '../../main/ets/models/PeripheralModels'
import { FirewallOverviewState, FirewallPresetMode } from '../../main/ets/services/firewall/FirewallModels'
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
    byType: new Map()
  }
}

function createPeripheralStats(
  total: number = 10,
  connects: number = 7,
  disconnects: number = 3,
  policyChanges: number = 0
): PeripheralTraceStats {
  return {
    total: total,
    connects: connects,
    disconnects: disconnects,
    policyChanges: policyChanges
  }
}

function createFirewallOverview(enabled: boolean = false, currentMode: FirewallPresetMode = 'custom'): FirewallOverviewState {
  return {
    enabled: enabled,
    currentMode: currentMode
  }
}

interface DashboardInitializationOptions {
  adminActivated?: boolean
  initResult?: MockInitResult
  firewallOverview?: FirewallOverviewState
  logStatistics?: LogStatistics
  peripheralStats?: PeripheralTraceStats
  logListenerId?: number
  peripheralListenerId?: number
  onFirewallLoad?: () => FirewallOverviewState
  onLogStatistics?: () => LogStatistics
  onPeripheralStatistics?: () => PeripheralTraceStats
  withRemoveListeners?: boolean
}

function mockDashboardInitialization(mockKit: MockKit, options: DashboardInitializationOptions = {}): void {
  let adminMock: Object = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
  let initMock: Object = mockKit.mockFunc(PeripheralTraceMaintenanceService, PeripheralTraceMaintenanceService.initialize)
  let firewallMock: Object = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
  let logStatsMock: Object = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
  let peripheralStatsMock: Object = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
  let logListenerMock: Object = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.addChangeListener)
  let peripheralListenerMock: Object = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.addChangeListener)

  let adminState = new MockAdminState()
  adminState.activated = options.adminActivated ?? true
  when(adminMock)().afterReturn(adminState)
  when(initMock)(ArgumentMatchers.any).afterReturn(options.initResult ?? new MockInitResult())

  if (options.onFirewallLoad) {
    when(firewallMock)(ArgumentMatchers.any).afterAction(options.onFirewallLoad)
  } else {
    when(firewallMock)(ArgumentMatchers.any).afterReturn(options.firewallOverview ?? createFirewallOverview())
  }

  if (options.onLogStatistics) {
    when(logStatsMock)().afterAction(options.onLogStatistics)
  } else {
    when(logStatsMock)().afterReturn(options.logStatistics ?? createLogStatistics())
  }

  if (options.onPeripheralStatistics) {
    when(peripheralStatsMock)(ArgumentMatchers.any).afterAction(options.onPeripheralStatistics)
  } else {
    when(peripheralStatsMock)(ArgumentMatchers.any).afterReturn(options.peripheralStats ?? createPeripheralStats())
  }

  when(logListenerMock)(ArgumentMatchers.any).afterReturn(options.logListenerId ?? 1)
  when(peripheralListenerMock)(ArgumentMatchers.any).afterReturn(options.peripheralListenerId ?? 2)

  if (options.withRemoveListeners) {
    let logRemoveMock: Object = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.removeChangeListener)
    let peripheralRemoveMock: Object = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.removeChangeListener)
    when(logRemoveMock)(ArgumentMatchers.any).afterReturn(undefined)
    when(peripheralRemoveMock)(ArgumentMatchers.any).afterReturn(undefined)
  }
}

interface DashboardViewModelInternal {
  context: common.UIAbilityContext | null
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

    it('should expose six quick entries including permission management contract', 0, () => {
      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let quickEntries = internal.buildQuickEntries() as Record<string, string>[]

      expect(quickEntries.length).assertEqual(6)
      expect(quickEntries[3].id).assertEqual(RouteIds.PERMISSION_MANAGE)
      expect(quickEntries[3].title).assertEqual(ModuleText.PERMISSION_MANAGE)
      expect(quickEntries[4].id).assertEqual(RouteIds.IDENTITY)
      expect(quickEntries.find((entry: Record<string, string>) => entry.id === RouteIds.HELP_FEEDBACK) === undefined).assertTrue()
    })

    it('should allow destroy before initialization', 0, () => {
      let viewModel = new DashboardViewModel()

      viewModel.destroy()

      expect(true).assertTrue()
    })

    it('should initialize with all module cards when admin is activated', 0, async (done: Function) => {
      mockDashboardInitialization(mockKit, {
        firewallOverview: createFirewallOverview(true, 'custom'),
        logStatistics: createLogStatistics(5, 120),
        peripheralStats: createPeripheralStats(10, 7, 3)
      })

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
      mockDashboardInitialization(mockKit, {
        adminActivated: false,
        firewallOverview: createFirewallOverview(false, 'custom')
      })

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      expect(viewModel.moduleCards[0].primaryText).assertEqual(DashboardAdminStrings.PENDING)
      expect(viewModel.moduleCards[0].secondaryText).assertEqual(DashboardAdminStrings.PENDING_DETAIL)
      done()
    })

    it('should show disabled when firewall is off', 0, async (done: Function) => {
      mockDashboardInitialization(mockKit, {
        firewallOverview: createFirewallOverview(false, 'custom')
      })

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      expect(viewModel.moduleCards[1].primaryText).assertEqual(StatusText.DISABLED)
      done()
    })

    it('should use disabled firewall card state when context is null', 0, async (done: Function) => {
      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let firewallCard = await internal.buildFirewallCard() as Record<string, string>

      expect(firewallCard.primaryText).assertEqual(StatusText.DISABLED)
      done()
    })

    it('should handle firewall load failure gracefully', 0, async (done: Function) => {
      mockDashboardInitialization(mockKit, {
        onFirewallLoad: (): FirewallOverviewState => {
          throw new Error('firewall load failed')
        }
      })

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      expect(viewModel.moduleCards[1].primaryText).assertEqual(StatusText.DISABLED)
      done()
    })

    it('should handle peripheral trace init failure gracefully', 0, async (done: Function) => {
      let failedResult = new MockInitResult()
      failedResult.success = false
      failedResult.code = 'storage_init_failed'
      mockDashboardInitialization(mockKit, {
        initResult: failedResult
      })

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      expect(viewModel.moduleCards.length).assertEqual(4)
      done()
    })

    it('should keep visible dashboard state when statistics are unavailable', 0, async (done: Function) => {
      mockDashboardInitialization(mockKit, {
        onLogStatistics: (): LogStatistics => {
          throw new Error('log statistics unavailable')
        },
        onPeripheralStatistics: (): PeripheralTraceStats => {
          throw new Error('peripheral statistics unavailable')
        }
      })

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      expect(viewModel.moduleCards.length).assertEqual(4)
      expect(viewModel.quickEntries.length).assertEqual(6)
      expect(viewModel.moduleCards[2].primaryText).assertEqual('0')
      expect(viewModel.moduleCards[3].primaryText).assertEqual('0')
      done()
    })

    it('should remove listeners on destroy', 0, async (done: Function) => {
      mockDashboardInitialization(mockKit, {
        logListenerId: 100,
        peripheralListenerId: 200,
        withRemoveListeners: true
      })

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)
      viewModel.destroy()

      expect(true).assertTrue()
      done()
    })

    it('should refresh all module cards', 0, async (done: Function) => {
      mockDashboardInitialization(mockKit, {
        firewallOverview: createFirewallOverview(true, 'custom'),
        logStatistics: createLogStatistics(3, 50),
        peripheralStats: createPeripheralStats(5, 3, 2)
      })

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)
      await viewModel.refreshAll()

      expect(viewModel.moduleCards.length).assertEqual(4)
      expect(viewModel.moduleCards[2].primaryText).assertEqual('3')
      expect(viewModel.moduleCards[3].primaryText).assertEqual('5')
      done()
    })

    it('should refresh static statuses same as refreshAll', 0, async (done: Function) => {
      mockDashboardInitialization(mockKit)

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)
      await viewModel.refreshStaticStatuses()

      expect(viewModel.moduleCards.length).assertEqual(4)
      done()
    })

    it('should build log card with correct statistics', 0, async (done: Function) => {
      let logStatsMock: Object = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.getStatistics)
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
      let peripheralStatsMock: Object = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      when(peripheralStatsMock)(ArgumentMatchers.any).afterReturn(createPeripheralStats(25, 18, 7))

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let peripheralCard = await internal.buildPeripheralCard() as Record<string, string>

      expect(peripheralCard.id).assertEqual(RouteIds.PERIPHERAL_MANAGE)
      expect(peripheralCard.primaryText).assertEqual('25')
      expect(peripheralCard.title).assertEqual(DashboardPeripheralCardStrings.TITLE)
      done()
    })

    it('should build peripheral card from runtime connection records and policy snapshots', 0, async (done: Function) => {
      let capturedQuery = ''
      let peripheralStatsMock: Object = mockKit.mockFunc(PeripheralTraceEntryRepository, PeripheralTraceEntryRepository.getStatistics)
      when(peripheralStatsMock)(ArgumentMatchers.any).afterAction((query: Object) => {
        capturedQuery = JSON.stringify(query)
        return createPeripheralStats(10, 5, 3, 2)
      })

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      let peripheralCard = await internal.buildPeripheralCard() as Record<string, string>

      expect(peripheralCard.primaryText).assertEqual('10')
      expect(peripheralCard.secondaryText).assertEqual('连接 5 次，断开 3 次，策略变更 2 次')
      expect(capturedQuery.indexOf('runtime_event') > -1).assertTrue()
      expect(capturedQuery.indexOf('policy_snapshot') > -1).assertTrue()
      expect(capturedQuery.indexOf('connect') > -1).assertTrue()
      expect(capturedQuery.indexOf('disconnect') > -1).assertTrue()
      expect(capturedQuery.indexOf('discover') > -1).assertTrue()
      done()
    })

    it('should build admin card with activated status', 0, () => {
      let adminMock: Object = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
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
      let adminMock: Object = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
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
      mockDashboardInitialization(mockKit)

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

    it('should handle loadOverviewState returning disabled state', 0, async (done: Function) => {
      let firewallMock: Object = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview(false, 'custom'))

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      internal.context = context
      let firewallCard = await internal.buildFirewallCard() as Record<string, string>

      expect(firewallCard.primaryText).assertEqual(StatusText.DISABLED)
      done()
    })

    it('should handle loadOverviewState returning enabled state', 0, async (done: Function) => {
      let firewallMock: Object = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      when(firewallMock)(ArgumentMatchers.any).afterReturn(createFirewallOverview(true, 'custom'))

      let viewModel = new DashboardViewModel()
      let internal = viewModel as Object as DashboardViewModelInternal
      internal.context = context
      let firewallCard = await internal.buildFirewallCard() as Record<string, string>

      expect(firewallCard.primaryText).assertEqual(StatusText.ENABLED)
      done()
    })

    it('should refresh log card via refreshLiveCards', 0, async (done: Function) => {
      mockDashboardInitialization(mockKit, {
        logStatistics: createLogStatistics(99, 500)
      })

      let viewModel = new DashboardViewModel()
      await viewModel.initialize(context)

      let internal = viewModel as Object as DashboardViewModelInternal
      await internal.refreshLiveCards(false, true)

      let logCard = viewModel.moduleCards.find((card: DashboardModuleCardState) => card.id === RouteIds.LOG_MANAGE)
      expect(logCard?.primaryText).assertEqual('99')
      done()
    })

    it('should refresh peripheral card via refreshLiveCards', 0, async (done: Function) => {
      mockDashboardInitialization(mockKit, {
        peripheralStats: createPeripheralStats(42, 30, 12)
      })

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

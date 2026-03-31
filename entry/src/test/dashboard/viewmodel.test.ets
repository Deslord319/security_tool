import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { Routes } from '../../main/ets/constants/AppConstants'
import { DashboardViewModel } from '../../main/ets/viewmodels/DashboardViewModel'
import { EnterpriseAdminService } from '../../main/ets/services/EnterpriseAdminService'
import { FirewallModeService } from '../../main/ets/services/FirewallModeService'
import { FirewallService } from '../../main/ets/services/FirewallService'
import { LogStorageChangeEvent, LogStorageService } from '../../main/ets/services/LogStorageService'
import { PeripheralTraceRepository } from '../../main/ets/services/PeripheralTraceRepository'

export default function dashboardViewModelTest() {
  describe('DashboardViewModel', () => {
    let viewModel: DashboardViewModel
    let context: common.UIAbilityContext

    let originalProbeActivation: () => Object
    let originalGetFirewallPolicy: () => Promise<Object | null>
    let originalGetCurrentMode: (context: common.UIAbilityContext) => Promise<string>
    let originalGetStatistics: () => Object
    let originalAddLogListener: (listener: (event: LogStorageChangeEvent) => void) => number
    let originalRemoveLogListener: (listenerId: number) => void
    let originalGetPeripheralStats: () => Object
    let originalAddPeripheralListener: (listener: () => void) => number
    let originalRemovePeripheralListener: (listenerId: number) => void

    let adminActivated: boolean
    let firewallEnabled: boolean
    let firewallMode: string
    let logTodayCount: number
    let logTotalCount: number
    let peripheralTotal: number
    let peripheralConnects: number
    let peripheralDisconnects: number
    let logListener: ((event: LogStorageChangeEvent) => void) | null
    let peripheralListener: (() => void) | null
    let removedLogListenerIds: number[]
    let removedPeripheralListenerIds: number[]

    beforeEach(() => {
      viewModel = new DashboardViewModel()
      context = {} as common.UIAbilityContext

      adminActivated = true
      firewallEnabled = true
      firewallMode = 'private'
      logTodayCount = 6
      logTotalCount = 21
      peripheralTotal = 9
      peripheralConnects = 5
      peripheralDisconnects = 4
      logListener = null
      peripheralListener = null
      removedLogListenerIds = []
      removedPeripheralListenerIds = []

      originalProbeActivation = EnterpriseAdminService.probeActivation
      originalGetFirewallPolicy = FirewallService.getFirewallPolicy
      originalGetCurrentMode = FirewallModeService.getCurrentMode
      originalGetStatistics = LogStorageService.getStatistics
      originalAddLogListener = LogStorageService.addChangeListener
      originalRemoveLogListener = LogStorageService.removeChangeListener
      originalGetPeripheralStats = PeripheralTraceRepository.getStats
      originalAddPeripheralListener = PeripheralTraceRepository.addChangeListener
      originalRemovePeripheralListener = PeripheralTraceRepository.removeChangeListener

      EnterpriseAdminService.probeActivation = (): Object => {
        return {
          activated: adminActivated,
          enableCommand: 'mock'
        }
      }
      FirewallService.getFirewallPolicy = async (): Promise<Object | null> => {
        return {
          isOpen: firewallEnabled
        }
      }
      FirewallModeService.getCurrentMode = async (_context: common.UIAbilityContext): Promise<string> => firewallMode
      LogStorageService.getStatistics = (): Object => {
        return {
          totalCount: logTotalCount,
          todayCount: logTodayCount,
          blockedCount: 0,
          byType: new Map()
        }
      }
      LogStorageService.addChangeListener = (listener: (event: LogStorageChangeEvent) => void): number => {
        logListener = listener
        return 11
      }
      LogStorageService.removeChangeListener = (listenerId: number): void => {
        removedLogListenerIds.push(listenerId)
      }
      PeripheralTraceRepository.getStats = (): Object => {
        return {
          total: peripheralTotal,
          connects: peripheralConnects,
          disconnects: peripheralDisconnects,
          intercepts: 0,
          allows: 0,
          denies: 0,
          unknowns: 0,
          runtimeCount: 0,
          auditCount: 0,
          snapshotCount: 0
        }
      }
      PeripheralTraceRepository.addChangeListener = (listener: () => void): number => {
        peripheralListener = listener
        return 22
      }
      PeripheralTraceRepository.removeChangeListener = (listenerId: number): void => {
        removedPeripheralListenerIds.push(listenerId)
      }
    })

    afterEach(() => {
      EnterpriseAdminService.probeActivation = originalProbeActivation
      FirewallService.getFirewallPolicy = originalGetFirewallPolicy
      FirewallModeService.getCurrentMode = originalGetCurrentMode
      LogStorageService.getStatistics = originalGetStatistics
      LogStorageService.addChangeListener = originalAddLogListener
      LogStorageService.removeChangeListener = originalRemoveLogListener
      PeripheralTraceRepository.getStats = originalGetPeripheralStats
      PeripheralTraceRepository.addChangeListener = originalAddPeripheralListener
      PeripheralTraceRepository.removeChangeListener = originalRemovePeripheralListener
    })

    it('should initialize module cards and quick entries from aggregated services', 0, async (done: Function) => {
      await viewModel.initialize(context)

      expect(viewModel.moduleCards.length).assertEqual(4)
      expect(viewModel.quickEntries.length).assertEqual(6)

      let adminCard = viewModel.moduleCards.find((card) => card.id === 'admin')
      let firewallCard = viewModel.moduleCards.find((card) => card.id === 'firewall')
      let logCard = viewModel.moduleCards.find((card) => card.id === 'log')
      let peripheralCard = viewModel.moduleCards.find((card) => card.id === 'peripheral')

      expect(adminCard?.primaryText).assertEqual('已激活')
      expect(firewallCard?.primaryText).assertEqual('已开启')
      expect(logCard?.primaryText).assertEqual('6')
      expect(logCard?.secondaryText).assertEqual('累计 21 条')
      expect(peripheralCard?.primaryText).assertEqual('9')
      expect(peripheralCard?.secondaryText).assertEqual('连接 5 次，断开 4 次')

      expect(viewModel.quickEntries[0].route).assertEqual(Routes.FIREWALL)
      expect(viewModel.quickEntries[1].route).assertEqual(Routes.LOG_MANAGE)
      expect(viewModel.quickEntries[2].route).assertEqual(Routes.PERIPHERAL_MANAGE)
      expect(viewModel.quickEntries[3].route).assertEqual(Routes.IDENTITY)
      expect(viewModel.quickEntries[4].route).assertEqual(Routes.TOOL_SETTINGS)
      expect(viewModel.quickEntries[5].route).assertEqual(Routes.HELP_FEEDBACK)
      done()
    })

    it('should refresh only log card when log listener fires', 0, async (done: Function) => {
      await viewModel.initialize(context)

      logTodayCount = 10
      logTotalCount = 30
      if (logListener) {
        logListener({
          totalCount: logTotalCount,
          addedCount: 1,
          timestamp: Date.now()
        })
      }

      let logCard = viewModel.moduleCards.find((card) => card.id === 'log')
      let peripheralCard = viewModel.moduleCards.find((card) => card.id === 'peripheral')

      expect(logCard?.primaryText).assertEqual('10')
      expect(logCard?.secondaryText).assertEqual('累计 30 条')
      expect(peripheralCard?.primaryText).assertEqual('9')
      done()
    })

    it('should refresh only peripheral card when peripheral listener fires', 0, async (done: Function) => {
      await viewModel.initialize(context)

      peripheralTotal = 15
      peripheralConnects = 8
      peripheralDisconnects = 7
      if (peripheralListener) {
        peripheralListener()
      }

      let logCard = viewModel.moduleCards.find((card) => card.id === 'log')
      let peripheralCard = viewModel.moduleCards.find((card) => card.id === 'peripheral')

      expect(logCard?.primaryText).assertEqual('6')
      expect(peripheralCard?.primaryText).assertEqual('15')
      expect(peripheralCard?.secondaryText).assertEqual('连接 8 次，断开 7 次')
      done()
    })

    it('should remove registered listeners on destroy', 0, async (done: Function) => {
      await viewModel.initialize(context)

      viewModel.destroy()

      expect(removedLogListenerIds.length).assertEqual(1)
      expect(removedPeripheralListenerIds.length).assertEqual(1)
      expect(removedLogListenerIds[0]).assertEqual(11)
      expect(removedPeripheralListenerIds[0]).assertEqual(22)
      done()
    })
  })
}

import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { MockKit, when } from '@ohos/hamock'
import { RouteIds } from '../../main/ets/constants/RouteIds'
import { DashboardViewModel } from '../../main/ets/viewmodels/dashboard/overview/DashboardViewModel'
import { EnterpriseAdminService } from '../../main/ets/services/admin/activation/EnterpriseAdminService'
import { FirewallService } from '../../main/ets/services/firewall/FirewallService'
import { LogRepository } from '../../main/ets/services/log-manage/repository/LogRepository'
import { PeripheralTraceRepository } from '../../main/ets/services/peripheral/connection-record/PeripheralTraceRepository'
import { AdminActivationState, LogEntry, LogEventResult, LogEventType, PeripheralTraceRecord, PeripheralType } from '../../main/ets/models/DataModels'
import { FirewallOverviewState } from '../../main/ets/models/firewall/firewall_service_contracts'

class DashboardAdminActivationState implements AdminActivationState {
  activated: boolean = false
  errorCode?: number
  errorMessage?: string
  enableCommand: string = ''
  adminType: 'super' | 'byod' = 'byod'
}

class DashboardFirewallOverviewState implements FirewallOverviewState {
  enabled: boolean = false
  currentMode: 'private' | 'public' | 'custom' = 'custom'
}

export default function dashboardViewModelTest() {
  describe('DashboardViewModel', () => {
    let viewModel: DashboardViewModel
    let context: common.UIAbilityContext
    let mockKit: MockKit

    let adminActivated: boolean
    let firewallEnabled: boolean
    let firewallMode: string
    let logTodayCount: number
    let logTotalCount: number
    let peripheralTotal: number
    let peripheralConnects: number
    let peripheralDisconnects: number
    let now: number

    beforeEach(() => {
      viewModel = new DashboardViewModel()
      mockKit = new MockKit()
      context = {} as common.UIAbilityContext

      adminActivated = true
      firewallEnabled = true
      firewallMode = 'private'
      logTodayCount = 6
      logTotalCount = 21
      peripheralTotal = 9
      peripheralConnects = 5
      peripheralDisconnects = 4
      now = Date.now()

      let probeActivationMock = mockKit.mockFunc(EnterpriseAdminService, EnterpriseAdminService.probeActivation)
      let loadOverviewStateMock = mockKit.mockFunc(FirewallService, FirewallService.loadOverviewState)
      let activationState = new DashboardAdminActivationState()
      activationState.activated = adminActivated
      activationState.enableCommand = 'mock'
      activationState.adminType = 'byod'
      when(probeActivationMock)().afterReturn(activationState)
      let overviewState = new DashboardFirewallOverviewState()
      overviewState.enabled = firewallEnabled
      overviewState.currentMode = firewallMode
      when(loadOverviewStateMock)(context).afterReturn(overviewState)
      LogRepository.resetForTest(buildLogEntries(logTodayCount, logTotalCount, now), true)
      PeripheralTraceRepository.resetForTest()
      PeripheralTraceRepository.setRecordsForTest(buildPeripheralRecords(peripheralTotal, peripheralConnects, peripheralDisconnects, now))
    })

    afterEach(() => {
      mockKit.clearAll()
      LogRepository.resetForTest()
      PeripheralTraceRepository.resetForTest()
    })

    it('should initialize module cards and quick entries from aggregated services', 0, async (done: Function) => {
      await viewModel.initialize(context)

      expect(viewModel.moduleCards.length).assertEqual(4)
      expect(viewModel.quickEntries.length).assertEqual(6)

      let adminCard = viewModel.moduleCards.find((card) => card.id === 'admin')
      let firewallCard = viewModel.moduleCards.find((card) => card.id === 'firewall')
      let logCard = viewModel.moduleCards.find((card) => card.id === 'log-manage')
      let peripheralCard = viewModel.moduleCards.find((card) => card.id === 'peripheral-manage')

      expect(adminCard?.primaryText).assertEqual('已激活')
      expect(firewallCard?.primaryText).assertEqual('已开启')
      expect(logCard?.primaryText).assertEqual('6')
      expect(logCard?.secondaryText).assertEqual('累计 21 条')
      expect(peripheralCard?.primaryText).assertEqual('9')
      expect(peripheralCard?.secondaryText).assertEqual('连接 5 次，断开 4 次')

      expect(viewModel.quickEntries[0].route).assertEqual(RouteIds.FIREWALL)
      expect(viewModel.quickEntries[1].route).assertEqual(RouteIds.LOG_MANAGE)
      expect(viewModel.quickEntries[2].route).assertEqual(RouteIds.PERIPHERAL_MANAGE)
      expect(viewModel.quickEntries[3].route).assertEqual(RouteIds.IDENTITY)
      expect(viewModel.quickEntries[4].route).assertEqual(RouteIds.TOOL_SETTINGS)
      expect(viewModel.quickEntries[5].route).assertEqual(RouteIds.HELP_FEEDBACK)
      done()
    })

    it('should refresh only log card when log listener fires', 0, async (done: Function) => {
      await viewModel.initialize(context)

      logTodayCount = 10
      logTotalCount = 30
      LogRepository.resetForTest(buildLogEntries(logTodayCount, logTotalCount, now), true)
      await viewModel.refreshAll()

      let logCard = viewModel.moduleCards.find((card) => card.id === 'log-manage')
      let peripheralCard = viewModel.moduleCards.find((card) => card.id === 'peripheral-manage')

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
      PeripheralTraceRepository.setRecordsForTest(buildPeripheralRecords(peripheralTotal, peripheralConnects, peripheralDisconnects, now))
      await viewModel.refreshAll()

      let logCard = viewModel.moduleCards.find((card) => card.id === 'log-manage')
      let peripheralCard = viewModel.moduleCards.find((card) => card.id === 'peripheral-manage')

      expect(logCard?.primaryText).assertEqual('6')
      expect(peripheralCard?.primaryText).assertEqual('15')
      expect(peripheralCard?.secondaryText).assertEqual('连接 8 次，断开 7 次')
      done()
    })

    it('should remove registered listeners on destroy', 0, async (done: Function) => {
      await viewModel.initialize(context)
      expect(LogRepository.getListenerCountForTest()).assertEqual(1)
      expect(PeripheralTraceRepository.getListenerCountForTest()).assertEqual(1)

      viewModel.destroy()

      expect(LogRepository.getListenerCountForTest()).assertEqual(0)
      expect(PeripheralTraceRepository.getListenerCountForTest()).assertEqual(0)
      done()
    })
  })
}

function buildLogEntries(todayCount: number, totalCount: number, now: number): LogEntry[] {
  let entries: LogEntry[] = []
  for (let index = 0; index < totalCount; index++) {
    let timestamp = index < todayCount ? now - index * 1000 : now - (24 * 60 * 60 * 1000) - index * 1000
    entries.push({
      id: `log-${index}`,
      timestamp: timestamp,
      eventType: LogEventType.PERMISSION,
      detail: `detail-${index}`,
      result: LogEventResult.SUCCESS
    })
  }
  return entries
}

function buildPeripheralRecords(total: number, connects: number, disconnects: number, now: number): PeripheralTraceRecord[] {
  let records: PeripheralTraceRecord[] = []
  for (let index = 0; index < connects; index++) {
    records.push(buildPeripheralRecord(`connect-${index}`, 'connect', now - index * 1000))
  }
  for (let index = 0; index < disconnects; index++) {
    records.push(buildPeripheralRecord(`disconnect-${index}`, 'disconnect', now - (connects + index) * 1000))
  }
  for (let index = connects + disconnects; index < total; index++) {
    records.push(buildPeripheralRecord(`unknown-${index}`, 'unknown', now - index * 1000))
  }
  return records
}

function buildPeripheralRecord(
  recordId: string,
  action: 'connect' | 'disconnect' | 'unknown',
  occurAt: number
): PeripheralTraceRecord {
  return {
    recordId: recordId,
    occurAt: occurAt,
    collectAt: occurAt,
    deviceName: `device-${recordId}`,
    deviceType: PeripheralType.USB_STORAGE,
    deviceId: recordId,
    action: action,
    decision: 'allow',
    result: LogEventResult.SUCCESS,
    source: 'runtime_event',
    summary: action
  }
}

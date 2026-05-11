import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { LogEntry, LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import {
  AuditSubscribeResult,
  CrashSubscribeResult,
  InitializeResult,
  MutationResult
} from '../../main/ets/services/log-manage/common/LogManagePorts'
import { LogCollectorService } from '../../main/ets/services/log-manage/collector/LogCollectorService'
import { LogStorageMaintenanceService } from '../../main/ets/services/log-manage/maintenance/LogStorageMaintenanceService'
import { LogAuditSource } from '../../main/ets/services/log-manage/source/LogAuditSource'
import { LogCrashSource } from '../../main/ets/services/log-manage/source/LogCrashSource'

function createEntry(id: string, detail: string): LogEntry {
  return {
    id,
    timestamp: Date.now(),
    eventType: LogEventType.FILE,
    detail,
    result: LogEventResult.SUCCESS
  }
}

class FakeCollectorRepository {
  initResult: InitializeResult = { success: true, code: 'ok' }
  addEntriesResult: MutationResult = { success: true, code: 'ok' }
  savedBatches: LogEntry[][] = []
}

class FakeAuditSource {
  result: AuditSubscribeResult = {
    success: true,
    code: 'ok',
    subscribedEventIds: [1],
    failedEventIds: []
  }
  callback?: (entry: LogEntry) => void
}

class FakeCrashSource {
  result: CrashSubscribeResult = {
    success: true,
    code: 'ok'
  }
  callback?: (entry: LogEntry) => void
}

export default function logCollectorServiceTest() {
  describe('LogCollectorService', () => {
    let repository: FakeCollectorRepository
    let auditSource: FakeAuditSource
    let crashSource: FakeCrashSource
    let context: common.UIAbilityContext
    let mockKit: MockKit

    beforeEach(async () => {
      await LogCollectorService.stop()
      repository = new FakeCollectorRepository()
      auditSource = new FakeAuditSource()
      crashSource = new FakeCrashSource()
      context = {} as common.UIAbilityContext
      mockKit = new MockKit()

      let initStorageMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.initialize)
      let appendEntriesMock = mockKit.mockFunc(LogStorageMaintenanceService, LogStorageMaintenanceService.appendEntries)
      let auditSubscribeMock = mockKit.mockFunc(LogAuditSource, LogAuditSource.subscribe)
      let auditUnsubscribeMock = mockKit.mockFunc(LogAuditSource, LogAuditSource.unsubscribe)
      let crashSubscribeMock = mockKit.mockFunc(LogCrashSource, LogCrashSource.subscribe)
      let crashUnsubscribeMock = mockKit.mockFunc(LogCrashSource, LogCrashSource.unsubscribe)

      when(initStorageMock)(ArgumentMatchers.any).afterAction((_context: common.UIAbilityContext) => {
        return Promise.resolve(repository.initResult)
      })
      when(appendEntriesMock)(ArgumentMatchers.any).afterAction((entries: LogEntry[]) => {
        repository.savedBatches.push(entries.slice())
        return Promise.resolve(repository.addEntriesResult)
      })
      when(auditSubscribeMock)(ArgumentMatchers.any).afterAction((
        onEntry: (entry: LogEntry) => void,
        _eventTypes?: LogEventType[]
      ) => {
        auditSource.callback = onEntry
        return Promise.resolve(auditSource.result)
      })
      when(auditUnsubscribeMock)().afterAction(() => {
        auditSource.callback = undefined
        return true
      })
      when(crashSubscribeMock)(ArgumentMatchers.any).afterAction((onEntry: (entry: LogEntry) => void) => {
        crashSource.callback = onEntry
        return crashSource.result
      })
      when(crashUnsubscribeMock)().afterAction(() => {
        crashSource.callback = undefined
        return true
      })
    })

    afterEach(async () => {
      await LogCollectorService.stop()
      mockKit.clearAll()
    })

    it('should return ok when audit and crash sources are ready', 0, async (done: Function) => {
      let initResult = await LogCollectorService.init(context)
      let startResult = await LogCollectorService.start()

      expect(initResult.success).assertTrue()
      expect(startResult.success).assertTrue()
      expect(startResult.code).assertEqual('ok')
      expect(startResult.status.auditReady).assertTrue()
      expect(startResult.status.crashReady).assertTrue()
      expect(startResult.status.degraded).assertFalse()
      done()
    })

    it('should return partial when one enabled source fails', 0, async (done: Function) => {
      crashSource.result = {
        success: false,
        code: 'unsupported'
      }

      await LogCollectorService.init(context)
      let startResult = await LogCollectorService.start()

      expect(startResult.success).assertTrue()
      expect(startResult.code).assertEqual('partial')
      expect(startResult.status.degraded).assertTrue()
      expect(startResult.status.degradedReason).assertEqual('crash_failed')
      done()
    })

    it('should return no_source_available when all enabled sources fail', 0, async (done: Function) => {
      auditSource.result = {
        success: false,
        code: 'permission_denied',
        subscribedEventIds: [],
        failedEventIds: [1]
      }
      crashSource.result = {
        success: false,
        code: 'unsupported'
      }

      await LogCollectorService.init(context)
      let startResult = await LogCollectorService.start()

      expect(startResult.success).assertFalse()
      expect(startResult.code).assertEqual('no_source_available')
      done()
    })

    it('should return flush_failed when queued entries cannot be persisted during stop', 0, async (done: Function) => {
      repository.addEntriesResult = { success: false, code: 'save_failed' }

      await LogCollectorService.init(context)
      await LogCollectorService.start()
      if (auditSource.callback) {
        auditSource.callback(createEntry('1', 'alpha'))
      }

      let stopResult = await LogCollectorService.stop()

      expect(stopResult.success).assertFalse()
      expect(stopResult.code).assertEqual('flush_failed')
      expect(stopResult.status.pendingCount > 0).assertTrue()
      done()
    })
  })
}

import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { LogEntry, LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import {
  AuditSubscribeResult,
  CrashSubscribeResult,
  InitializeResult,
  MutationResult,
  ServiceResult,
  SourceStatus
} from '../../main/ets/services/log-manage/common/LogManagePorts'
import { LogCollectorService } from '../../main/ets/services/log-manage/collector/LogCollectorService'

interface FakeSubscriptionConfig {
  subscribeAll: boolean
  subscribedTypes: LogEventType[]
}

class FakeCollectorDeps {
  repositoryPort: FakeCollectorRepository
  configPort: FakeCollectorConfig
  auditSourcePort: FakeAuditSource
  crashSourcePort: FakeCrashSource
  setTimerFn: (task: () => void, delayMs: number) => number
  clearTimerFn: (timerId: number) => void

  constructor(
    repositoryPort: FakeCollectorRepository,
    configPort: FakeCollectorConfig,
    auditSourcePort: FakeAuditSource,
    crashSourcePort: FakeCrashSource
  ) {
    this.repositoryPort = repositoryPort
    this.configPort = configPort
    this.auditSourcePort = auditSourcePort
    this.crashSourcePort = crashSourcePort
    this.setTimerFn = (_task: () => void, _delayMs: number): number => 1
    this.clearTimerFn = (_timerId: number): void => {}
  }
}

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

  async init(_context: common.UIAbilityContext): Promise<InitializeResult> {
    return this.initResult
  }

  async addEntries(entries: LogEntry[]): Promise<MutationResult> {
    this.savedBatches.push(entries.slice())
    return this.addEntriesResult
  }
}

class FakeCollectorConfig {
  initResult: ServiceResult = { success: true, code: 'ok' }
  subscribeAll: boolean = true
  subscribedTypes: LogEventType[] = [LogEventType.FILE, LogEventType.CRASH]

  async init(_context: common.UIAbilityContext): Promise<ServiceResult> {
    return this.initResult
  }

  async loadSubscriptionConfig(): Promise<FakeSubscriptionConfig> {
    let result: FakeSubscriptionConfig = {
      subscribeAll: this.subscribeAll,
      subscribedTypes: this.subscribedTypes.slice()
    }
    return result
  }
}

class FakeAuditSource {
  result: AuditSubscribeResult = {
    success: true,
    code: 'ok',
    subscribedEventIds: [1],
    failedEventIds: []
  }
  callback?: (entry: LogEntry) => void

  async subscribe(onEntry: (entry: LogEntry) => void, _eventTypes?: LogEventType[]): Promise<AuditSubscribeResult> {
    this.callback = onEntry
    return this.result
  }

  unsubscribe(): boolean {
    this.callback = undefined
    return true
  }

  getStatus(): SourceStatus {
    return { subscribed: this.callback !== undefined }
  }
}

class FakeCrashSource {
  result: CrashSubscribeResult = {
    success: true,
    code: 'ok'
  }
  callback?: (entry: LogEntry) => void

  subscribe(onEntry: (entry: LogEntry) => void): CrashSubscribeResult {
    this.callback = onEntry
    return this.result
  }

  unsubscribe(): boolean {
    this.callback = undefined
    return true
  }

  getStatus(): SourceStatus {
    return { subscribed: this.callback !== undefined }
  }
}

export default function logCollectorServiceTest() {
  describe('LogCollectorService', () => {
    let repository: FakeCollectorRepository
    let config: FakeCollectorConfig
    let auditSource: FakeAuditSource
    let crashSource: FakeCrashSource
    let context: common.UIAbilityContext

    beforeEach(() => {
      LogCollectorService.resetForTest()
      repository = new FakeCollectorRepository()
      config = new FakeCollectorConfig()
      auditSource = new FakeAuditSource()
      crashSource = new FakeCrashSource()
      let deps = new FakeCollectorDeps(repository, config, auditSource, crashSource)
      LogCollectorService.setTestDeps(deps as Object as never)
      context = {} as common.UIAbilityContext
    })

    it('should return ok when only enabled audit source is ready', 0, async (done: Function) => {
      config.subscribeAll = false
      config.subscribedTypes = [LogEventType.FILE]

      let initResult = await LogCollectorService.init(context)
      let startResult = await LogCollectorService.start()

      expect(initResult.success).assertTrue()
      expect(startResult.success).assertTrue()
      expect(startResult.code).assertEqual('ok')
      expect(startResult.status.auditReady).assertTrue()
      expect(startResult.status.crashReady).assertFalse()
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

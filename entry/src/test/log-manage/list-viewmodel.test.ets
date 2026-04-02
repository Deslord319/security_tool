import { beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import {
  ExportActionResult,
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../main/ets/models/DataModels'
import {
  ClearLogsResult,
  CollectorStatus,
  ExportLogsResult,
  InitializeResult,
  ListViewInitializeResult,
  LogCollectorStatusPort,
  LogExportServicePort,
  LogQuery,
  LogRepositoryPort,
  LogSnapshot,
  MutationResult
} from '../../main/ets/services/log-manage/common/LogManagePorts'
import { LogListViewModel } from '../../main/ets/viewmodels/log-manage/LogListViewModel'

function createEntry(id: string, eventType: LogEventType, result: LogEventResult, detail: string): LogEntry {
  return {
    id,
    timestamp: Date.now(),
    eventType,
    detail,
    result
  }
}

class FakeLogListRepository implements LogRepositoryPort {
  entries: LogEntry[] = []
  listener: (() => void) | null = null
  initResult: InitializeResult = { success: true, code: 'ok' }
  clearResult: ClearLogsResult = { success: true, code: 'ok' }

  async init(_context: common.UIAbilityContext): Promise<InitializeResult> {
    return this.initResult
  }

  async addEntries(entries: LogEntry[]): Promise<MutationResult> {
    this.entries = entries.concat(this.entries)
    return { success: true, code: 'ok' }
  }

  snapshot(query?: LogQuery): LogSnapshot {
    let filtered = this.entries.filter((entry: LogEntry) => {
      if (query?.eventTypes && query.eventTypes.length > 0 && !query.eventTypes.includes(entry.eventType)) {
        return false
      }
      if (query?.results && query.results.length > 0 && !query.results.includes(entry.result)) {
        return false
      }
      if (query?.keyword && entry.detail.toLowerCase().indexOf(query.keyword.toLowerCase()) < 0) {
        return false
      }
      return true
    })
    let blockedCount = this.entries.filter((entry: LogEntry) => entry.result === LogEventResult.BLOCKED).length
    return {
      totalCount: this.entries.length,
      todayCount: this.entries.length,
      blockedCount: blockedCount,
      entries: filtered
    }
  }

  async clear(): Promise<ClearLogsResult> {
    if (this.clearResult.success) {
      this.entries = []
    }
    return this.clearResult
  }

  addChangeListener(listener: () => void): number {
    this.listener = listener
    return 3
  }

  removeChangeListener(_listenerId: number): void {
    this.listener = null
  }
}

class FakeLogListExporter implements LogExportServicePort {
  result: ExportLogsResult = {
    success: true,
    code: 'ok',
    fileName: 'security_log.csv'
  }

  async export(_context: common.UIAbilityContext | null, _entries: LogEntry[]): Promise<ExportLogsResult> {
    return this.result
  }
}

class FakeLogListCollector implements LogCollectorStatusPort {
  status: CollectorStatus = {
    running: true,
    auditReady: true,
    crashReady: false,
    pendingCount: 2,
    degraded: true,
    degradedReason: 'crash_failed'
  }

  getStatus(): CollectorStatus {
    return this.status
  }
}

export default function logListViewModelTest() {
  describe('LogListViewModel', () => {
    let repository: FakeLogListRepository
    let exporter: FakeLogListExporter
    let collector: FakeLogListCollector
    let viewModel: LogListViewModel
    let context: common.UIAbilityContext

    beforeEach(() => {
      repository = new FakeLogListRepository()
      repository.entries = [
        createEntry('1', LogEventType.FILE, LogEventResult.SUCCESS, 'file alpha'),
        createEntry('2', LogEventType.PERMISSION, LogEventResult.BLOCKED, 'permission beta'),
        createEntry('3', LogEventType.FILE, LogEventResult.FAILED, 'file gamma')
      ]
      exporter = new FakeLogListExporter()
      collector = new FakeLogListCollector()
      viewModel = new LogListViewModel(repository, exporter, collector)
      context = {} as common.UIAbilityContext
    })

    it('should initialize list state from repository snapshot', 0, async (done: Function) => {
      let result: ListViewInitializeResult = await viewModel.initialize(context)

      expect(result.success).assertTrue()
      expect(viewModel.state.summary.totalCount).assertEqual(3)
      expect(viewModel.state.summary.blockedCount).assertEqual(1)
      expect(viewModel.state.collectorStatus.running).assertTrue()
      expect(viewModel.state.collectorStatus.crashReady).assertFalse()
      done()
    })

    it('should reset to first page when filter changes', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.setPageSize(20)
      viewModel.setPageInputText('2')
      viewModel.jumpToPage()

      await viewModel.setKeyword('beta')

      expect(viewModel.state.pagination.currentPage).assertEqual(1)
      expect(viewModel.state.pagination.pageInputText).assertEqual('1')
      expect(viewModel.state.entries.length).assertEqual(1)
      done()
    })

    it('should refresh from listener only when active and auto refresh enabled', 0, async (done: Function) => {
      await viewModel.initialize(context)
      repository.entries = [createEntry('4', LogEventType.FILE, LogEventResult.SUCCESS, 'new entry')]

      if (repository.listener) {
        repository.listener()
      }
      expect(viewModel.state.entries.length).assertEqual(3)

      viewModel.activate()
      if (repository.listener) {
        repository.listener()
      }
      expect(viewModel.state.entries.length).assertEqual(1)

      repository.entries = [createEntry('5', LogEventType.FILE, LogEventResult.SUCCESS, 'new entry 2')]
      viewModel.setAutoRefreshEnabled(false)
      if (repository.listener) {
        repository.listener()
      }
      expect(viewModel.state.entries[0].id).assertEqual('4')
      done()
    })

    it('should map export result into presentation result', 0, async (done: Function) => {
      await viewModel.initialize(context)

      let successResult: ExportActionResult = await viewModel.exportLogs(context)
      expect(successResult.success).assertTrue()
      expect(successResult.fileName).assertEqual('security_log.csv')

      exporter.result = {
        success: false,
        code: 'empty'
      }
      let failedResult: ExportActionResult = await viewModel.exportLogs(context)
      expect(failedResult.success).assertFalse()
      expect((failedResult.reason ?? '').length > 0).assertTrue()
      done()
    })

    it('should clear logs even when current filter result is empty', 0, async (done: Function) => {
      await viewModel.initialize(context)
      await viewModel.setKeyword('missing-keyword')

      let result = await viewModel.clearLogs()

      expect(result.success).assertTrue()
      expect(viewModel.state.summary.totalCount).assertEqual(0)
      expect(viewModel.state.entries.length).assertEqual(0)
      done()
    })

    it('should clear selected entry when repository no longer contains it', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.activate()
      viewModel.selectEntry('2')
      repository.entries = [createEntry('4', LogEventType.FILE, LogEventResult.SUCCESS, 'new entry')]

      if (repository.listener) {
        repository.listener()
      }

      expect(viewModel.state.selectedEntryId).assertEqual('')
      done()
    })

    it('should expose empty filter hint instead of permission hint when query has no matches', 0, async (done: Function) => {
      await viewModel.initialize(context)

      await viewModel.setKeyword('missing-keyword')

      expect(viewModel.state.entries.length).assertEqual(0)
      expect((viewModel.state.hintMessage ?? '').length > 0).assertTrue()
      done()
    })

    it('should keep pagination state in sync after moving to next page', 0, async (done: Function) => {
      repository.entries = []
      for (let index = 0; index < 25; index++) {
        repository.entries.push(createEntry(`${index}`, LogEventType.FILE, LogEventResult.SUCCESS, `entry-${index}`))
      }
      await viewModel.initialize(context)
      viewModel.setPageSize(20)

      viewModel.goNext()

      expect(viewModel.state.pagination.currentPage).assertEqual(2)
      expect(viewModel.state.pagination.totalPages).assertEqual(2)
      expect(viewModel.state.pagedEntries.length).assertEqual(5)
      done()
    })
  })
}

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
  MutationResult,
  SaveSettingsResult
} from '../../main/ets/services/log-manage/common/LogManagePorts'
import { LogManageViewModel } from '../../main/ets/viewmodels/log-manage/overview/LogManageViewModel'
import { LogStorageSettingsViewModel } from '../../main/ets/viewmodels/log-manage/storage-settings/LogStorageSettingsViewModel'

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

class FakeLogStorageSettingsViewModel extends LogStorageSettingsViewModel {
  loadResult: SaveSettingsResult = { success: true, code: 'ok' }
  saveResult: SaveSettingsResult = { success: true, code: 'ok' }

  async load(): Promise<SaveSettingsResult> {
    return this.loadResult
  }

  async save(): Promise<SaveSettingsResult> {
    return this.saveResult
  }
}

export default function logManageViewModelTest() {
  describe('LogManageViewModel', () => {
    let repository: FakeLogListRepository
    let exporter: FakeLogListExporter
    let collector: FakeLogListCollector
    let settingsViewModel: FakeLogStorageSettingsViewModel
    let viewModel: LogManageViewModel
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
      settingsViewModel = new FakeLogStorageSettingsViewModel()
      viewModel = new LogManageViewModel(repository, exporter, collector, settingsViewModel)
      context = {} as common.UIAbilityContext
    })

    it('should initialize list state from repository snapshot', 0, async (done: Function) => {
      let result: ListViewInitializeResult = await viewModel.initialize(context)

      expect(result.success).assertTrue()
      expect(viewModel.state.summary.totalCount).assertEqual(3)
      expect(viewModel.state.summary.blockedCount).assertEqual(1)
      expect(viewModel.state.collector.running).assertTrue()
      expect(viewModel.state.collector.crashReady).assertFalse()
      done()
    })

    it('should reset to first page when filter changes', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.setPageSizeIndex(0)
      viewModel.setPageInputText('2')
      viewModel.jumpToInputPage()

      await viewModel.setKeyword('beta')

      expect(viewModel.state.pagination.currentPage).assertEqual(1)
      expect(viewModel.state.pagination.pageInputText).assertEqual('1')
      expect(viewModel.state.list.allEntries.length).assertEqual(1)
      done()
    })

    it('should refresh from listener only when active and auto refresh enabled', 0, async (done: Function) => {
      await viewModel.initialize(context)
      repository.entries = [createEntry('4', LogEventType.FILE, LogEventResult.SUCCESS, 'new entry')]

      if (repository.listener) {
        repository.listener()
      }
      expect(viewModel.state.list.allEntries.length).assertEqual(3)

      viewModel.activate()
      if (repository.listener) {
        repository.listener()
      }
      expect(viewModel.state.list.allEntries.length).assertEqual(1)

      repository.entries = [createEntry('5', LogEventType.FILE, LogEventResult.SUCCESS, 'new entry 2')]
      await viewModel.setMode('settings')
      if (repository.listener) {
        repository.listener()
      }
      expect(viewModel.state.list.allEntries[0].id).assertEqual('4')
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

      let result: ClearLogsResult = await viewModel.clearLogs()

      expect(result.success).assertTrue()
      expect(viewModel.state.summary.totalCount).assertEqual(0)
      expect(viewModel.state.list.allEntries.length).assertEqual(0)
      done()
    })

    it('should clear detail state when repository no longer contains it', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.activate()
      viewModel.openDetail('2')
      repository.entries = [createEntry('4', LogEventType.FILE, LogEventResult.SUCCESS, 'new entry')]

      if (repository.listener) {
        repository.listener()
      }

      expect(viewModel.state.detail.entryId).assertEqual('')
      expect(viewModel.state.detail.visible).assertFalse()
      done()
    })

    it('should expose empty filter hint instead of permission hint when query has no matches', 0, async (done: Function) => {
      await viewModel.initialize(context)

      await viewModel.setKeyword('missing-keyword')

      expect(viewModel.state.list.allEntries.length).assertEqual(0)
      expect((viewModel.state.filter.hintMessage ?? '').length > 0).assertTrue()
      done()
    })

    it('should keep pagination state in sync after moving to next page', 0, async (done: Function) => {
      repository.entries = []
      for (let index = 0; index < 25; index++) {
        repository.entries.push(createEntry(`${index}`, LogEventType.FILE, LogEventResult.SUCCESS, `entry-${index}`))
      }
      await viewModel.initialize(context)
      viewModel.setPageSizeIndex(0)

      viewModel.goToNextPage()

      expect(viewModel.state.pagination.currentPage).assertEqual(2)
      expect(viewModel.state.pagination.totalPages).assertEqual(2)
      expect(viewModel.state.list.pagedEntries.length).assertEqual(5)
      expect(viewModel.state.summary.currentShownCount).assertEqual(5)
      done()
    })

    it('should switch mode and restore list after saving settings', 0, async (done: Function) => {
      await viewModel.initialize(context)

      await viewModel.setMode('settings')
      expect(viewModel.state.mode).assertEqual('settings')
      expect(viewModel.state.autoRefreshEnabled).assertFalse()

      let result: SaveSettingsResult = await viewModel.saveStorageSettings()

      expect(result.success).assertTrue()
      expect(viewModel.state.mode).assertEqual('list')
      expect(viewModel.state.autoRefreshEnabled).assertTrue()
      done()
    })
  })
}

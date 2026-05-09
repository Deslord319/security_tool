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
  LogSnapshot,
  LogStoragePort,
  MutationResult,
  RefreshResult,
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

async function flushAsyncWork(): Promise<void> {
  for (let index = 0; index < 6; index++) {
    await Promise.resolve()
  }
}

class FakeLogListStorage implements LogStoragePort {
  entries: LogEntry[] = []
  listener: (() => void) | null = null
  initResult: InitializeResult = { success: true, code: 'ok' }
  clearResult: ClearLogsResult = { success: true, code: 'ok' }
  forcedHasEntry: boolean | null = null
  countCallCount: number = 0
  listCallCount: number = 0
  snapshotCallCount: number = 0
  hasEntryCallCount: number = 0
  failSnapshot: boolean = false
  lastLimit?: number
  lastOffset?: number

  private filterEntries(query?: LogQuery): LogEntry[] {
    return this.entries.filter((entry: LogEntry) => {
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
  }

  async init(_context: common.UIAbilityContext): Promise<InitializeResult> {
    return this.initResult
  }

  async addEntries(entries: LogEntry[]): Promise<MutationResult> {
    this.entries = entries.concat(this.entries)
    return { success: true, code: 'ok' }
  }

  async count(query?: LogQuery): Promise<number> {
    this.countCallCount++
    return this.filterEntries(query).length
  }

  async list(query?: LogQuery, limit?: number, offset?: number): Promise<LogEntry[]> {
    this.listCallCount++
    this.lastLimit = limit
    this.lastOffset = offset
    let filtered = this.filterEntries(query)
    let start = offset ?? 0
    let end = limit !== undefined ? start + limit : filtered.length
    return filtered.slice(start, end)
  }

  async hasEntry(entryId: string, query?: LogQuery): Promise<boolean> {
    this.hasEntryCallCount++
    if (this.forcedHasEntry !== null) {
      return this.forcedHasEntry
    }
    let filtered = this.filterEntries(query)
    for (let entry of filtered) {
      if (entry.id === entryId) {
        return true
      }
    }
    return false
  }

  async snapshot(query?: LogQuery, limit?: number, offset?: number): Promise<LogSnapshot> {
    this.snapshotCallCount++
    if (this.failSnapshot) {
      throw new Error('snapshot failed')
    }
    let filtered = this.filterEntries(query)
    let paged = await this.list(query, limit, offset)
    let blockedCount = this.entries.filter((entry: LogEntry) => entry.result === LogEventResult.BLOCKED).length
    return {
      totalCount: this.entries.length,
      todayCount: this.entries.length,
      blockedCount: blockedCount,
      filteredCount: filtered.length,
      entries: paged
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

  async export(
    _context: common.UIAbilityContext | null,
    _query?: LogQuery,
    _fileNamePrefix?: string
  ): Promise<ExportLogsResult> {
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
    let storage: FakeLogListStorage
    let exporter: FakeLogListExporter
    let collector: FakeLogListCollector
    let settingsViewModel: FakeLogStorageSettingsViewModel
    let viewModel: LogManageViewModel
    let context: common.UIAbilityContext

    beforeEach(() => {
      storage = new FakeLogListStorage()
      storage.entries = [
        createEntry('1', LogEventType.FILE, LogEventResult.SUCCESS, 'file alpha'),
        createEntry('2', LogEventType.PERMISSION, LogEventResult.BLOCKED, 'permission beta'),
        createEntry('3', LogEventType.FILE, LogEventResult.FAILED, 'file gamma')
      ]
      exporter = new FakeLogListExporter()
      collector = new FakeLogListCollector()
      settingsViewModel = new FakeLogStorageSettingsViewModel()
      viewModel = new LogManageViewModel(storage, exporter, collector, settingsViewModel)
      context = {} as common.UIAbilityContext
    })

    it('should initialize list state from repository snapshot', 0, async () => {
      let result: ListViewInitializeResult = await viewModel.initialize(context)

      expect(result.success).assertTrue()
      expect(viewModel.state.summary.totalCount).assertEqual(3)
      expect(viewModel.state.summary.blockedCount).assertEqual(1)
      expect(viewModel.state.collector.running).assertTrue()
      expect(viewModel.state.collector.crashReady).assertFalse()
      expect(storage.lastLimit).assertEqual(20)
      expect(storage.lastOffset).assertEqual(0)
      expect(storage.countCallCount).assertEqual(1)
      expect(storage.listCallCount).assertEqual(1)
      expect(storage.snapshotCallCount).assertEqual(1)
    })

    it('should keep initialized false after failed initialize and allow retry', 0, async () => {
      storage.initResult = { success: false, code: 'storage_init_failed' }

      let failedResult: ListViewInitializeResult = await viewModel.initialize(context)

      expect(failedResult.success).assertFalse()
      expect(viewModel.state.initialized).assertFalse()
      expect(viewModel.state.loading).assertFalse()
      expect(storage.snapshotCallCount).assertEqual(0)

      storage.initResult = { success: true, code: 'ok' }
      let successResult: ListViewInitializeResult = await viewModel.initialize(context)

      expect(successResult.success).assertTrue()
      expect(viewModel.state.initialized).assertTrue()
      expect(storage.snapshotCallCount).assertEqual(1)
    })

    it('should reset to first page when filter changes', 0, async () => {
      await viewModel.initialize(context)
      viewModel.setPageSizeIndex(0)
      viewModel.setPageInputText('2')
      viewModel.jumpToInputPage()

      await viewModel.setKeyword('beta')

      expect(viewModel.state.pagination.currentPage).assertEqual(1)
      expect(viewModel.state.pagination.pageInputText).assertEqual('1')
      expect(viewModel.state.list.pagedEntries.length).assertEqual(1)
    })

    it('should refresh from listener only when active and auto refresh enabled', 0, async () => {
      await viewModel.initialize(context)
      storage.entries = [createEntry('4', LogEventType.FILE, LogEventResult.SUCCESS, 'new entry')]

      if (storage.listener) {
        storage.listener()
      }
      await flushAsyncWork()
      expect(viewModel.state.list.pagedEntries.length).assertEqual(3)

      viewModel.activate()
      if (storage.listener) {
        storage.listener()
      }
      await flushAsyncWork()
      expect(viewModel.state.list.pagedEntries.length).assertEqual(1)

      storage.entries = [createEntry('5', LogEventType.FILE, LogEventResult.SUCCESS, 'new entry 2')]
      await viewModel.setMode('settings')
      if (storage.listener) {
        storage.listener()
      }
      await flushAsyncWork()
      expect(viewModel.state.list.pagedEntries[0].id).assertEqual('4')
    })

    it('should map export result into presentation result', 0, async () => {
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
    })

    it('should clear logs even when current filter result is empty', 0, async () => {
      await viewModel.initialize(context)
      await viewModel.setKeyword('missing-keyword')

      let result: ClearLogsResult = await viewModel.clearLogs()

      expect(result.success).assertTrue()
      expect(viewModel.state.summary.totalCount).assertEqual(0)
      expect(viewModel.state.list.pagedEntries.length).assertEqual(0)
    })

    it('should clear detail state when repository no longer contains it', 0, async () => {
      await viewModel.initialize(context)
      viewModel.activate()
      viewModel.openDetail('2')
      storage.entries = [createEntry('4', LogEventType.FILE, LogEventResult.SUCCESS, 'new entry')]

      if (storage.listener) {
        storage.listener()
      }
      await flushAsyncWork()

      expect(viewModel.state.detail.entryId).assertEqual('')
      expect(viewModel.state.detail.visible).assertFalse()
    })

    it('should keep detail selection stable when refreshed data still contains the same entry', 0, async () => {
      await viewModel.initialize(context)
      viewModel.activate()
      viewModel.openDetail('2')
      storage.entries = [
        createEntry('2', LogEventType.PERMISSION, LogEventResult.BLOCKED, 'permission beta updated'),
        createEntry('4', LogEventType.FILE, LogEventResult.SUCCESS, 'file delta')
      ]

      if (storage.listener) {
        storage.listener()
      }
      await flushAsyncWork()

      expect(viewModel.state.detail.visible).assertTrue()
      expect(viewModel.state.detail.entryId).assertEqual('2')
      expect(viewModel.state.list.pagedEntries.length).assertEqual(2)
    })

    it('should keep detail open when entry is off current page but still exists in filtered result', 0, async () => {
      storage.entries = []
      for (let index = 0; index < 30; index++) {
        storage.entries.push(createEntry(`${index}`, LogEventType.FILE, LogEventResult.SUCCESS, `entry-${index}`))
      }
      await viewModel.initialize(context)
      viewModel.openDetail('25')
      storage.forcedHasEntry = true

      await viewModel.refreshAll()

      expect(viewModel.state.detail.visible).assertTrue()
      expect(viewModel.state.detail.entryId).assertEqual('25')
    })

    it('should close detail when active filters no longer include the selected entry', 0, async () => {
      await viewModel.initialize(context)
      viewModel.openDetail('2')

      await viewModel.setEventTypeIndex(1)

      expect(viewModel.state.detail.visible).assertFalse()
      expect(viewModel.state.detail.entryId).assertEqual('')
      expect(storage.hasEntryCallCount > 0).assertTrue()
    })

    it('should keep empty paged result when query has no matches', 0, async () => {
      await viewModel.initialize(context)

      await viewModel.setKeyword('missing-keyword')

      expect(viewModel.state.list.pagedEntries.length).assertEqual(0)
    })

    it('should keep pagination state in sync after moving to next page', 0, async () => {
      storage.entries = []
      for (let index = 0; index < 25; index++) {
        storage.entries.push(createEntry(`${index}`, LogEventType.FILE, LogEventResult.SUCCESS, `entry-${index}`))
      }
      await viewModel.initialize(context)
      viewModel.setPageSizeIndex(0)
      await flushAsyncWork()

      viewModel.goToNextPage()
      await flushAsyncWork()

      expect(viewModel.state.pagination.currentPage).assertEqual(2)
      expect(viewModel.state.pagination.totalPages).assertEqual(2)
      expect(viewModel.state.list.pagedEntries.length).assertEqual(5)
      expect(viewModel.state.summary.currentShownCount).assertEqual(5)
      expect(storage.lastLimit).assertEqual(20)
      expect(storage.lastOffset).assertEqual(20)
    })

    it('should request repository pagination instead of slicing full filtered entries locally', 0, async () => {
      storage.entries = []
      for (let index = 0; index < 55; index++) {
        storage.entries.push(createEntry(`${index}`, LogEventType.FILE, LogEventResult.SUCCESS, `entry-${index}`))
      }
      await viewModel.initialize(context)
      viewModel.setPageSizeIndex(1)
      await flushAsyncWork()

      viewModel.goToNextPage()
      await flushAsyncWork()

      expect(viewModel.state.pagination.currentPage).assertEqual(2)
      expect(viewModel.state.list.pagedEntries.length).assertEqual(5)
      expect(storage.lastLimit).assertEqual(50)
      expect(storage.lastOffset).assertEqual(50)
      expect(storage.listCallCount >= 2).assertTrue()
      expect(storage.snapshotCallCount).assertEqual(3)
    })

    it('should avoid redundant list queries when jumping directly to a later page', 0, async () => {
      storage.entries = []
      for (let index = 0; index < 120; index++) {
        storage.entries.push(createEntry(`${index}`, LogEventType.FILE, LogEventResult.SUCCESS, `entry-${index}`))
      }
      await viewModel.initialize(context)
      storage.listCallCount = 0
      storage.snapshotCallCount = 0
      storage.countCallCount = 0
      viewModel.setPageInputText('3')

      viewModel.jumpToInputPage()
      await flushAsyncWork()

      expect(viewModel.state.pagination.currentPage).assertEqual(3)
      expect(storage.countCallCount).assertEqual(1)
      expect(storage.snapshotCallCount).assertEqual(1)
      expect(storage.listCallCount).assertEqual(1)
      expect(storage.lastLimit).assertEqual(20)
      expect(storage.lastOffset).assertEqual(40)
    })

    it('should return query_failed and restore pagination when page refresh fails', 0, async () => {
      storage.entries = []
      for (let index = 0; index < 25; index++) {
        storage.entries.push(createEntry(`${index}`, LogEventType.FILE, LogEventResult.SUCCESS, `entry-${index}`))
      }
      await viewModel.initialize(context)
      let previousFirstEntryId = viewModel.state.list.pagedEntries[0].id
      storage.failSnapshot = true

      let result: RefreshResult = await viewModel.goToNextPage()

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('query_failed')
      expect(viewModel.state.pagination.currentPage).assertEqual(1)
      expect(viewModel.state.pagination.pageInputText).assertEqual('1')
      expect(viewModel.state.list.pagedEntries[0].id).assertEqual(previousFirstEntryId)
    })

    it('should switch mode and restore list after saving settings', 0, async () => {
      await viewModel.initialize(context)

      await viewModel.setMode('settings')
      expect(viewModel.state.mode).assertEqual('settings')
      expect(viewModel.state.autoRefreshEnabled).assertFalse()

      let result: SaveSettingsResult = await viewModel.saveStorageSettings()

      expect(result.success).assertTrue()
      expect(viewModel.state.mode).assertEqual('list')
      expect(viewModel.state.autoRefreshEnabled).assertTrue()
    })

    it('should skip refresh when list is inactive', 0, async () => {
      await viewModel.initialize(context)

      let result = await viewModel.refreshIfActive()

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('skipped_inactive')
    })
  })
}

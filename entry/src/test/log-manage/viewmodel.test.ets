import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import {
  DEFAULT_LOG_STORAGE_CONFIG,
  LogExportResult,
  LogEntry,
  LogEventResult,
  LogEventType,
  LogFilter,
  LogStorageConfig,
  LogStatistics
} from '../../main/ets/models/DataModels'
import { LogManageViewModel } from '../../main/ets/viewmodels/LogManageViewModel'
import { LogRuntimeCollectorService, LogRuntimeCollectorStatus } from '../../main/ets/services/LogRuntimeCollectorService'
import { LogCsvExportPayload, LogStorageChangeEvent, LogStorageService } from '../../main/ets/services/LogStorageService'

function createEntry(id: string, eventType: LogEventType, result: LogEventResult, detail: string): LogEntry {
  return {
    id,
    timestamp: Date.now(),
    eventType,
    detail,
    result
  }
}

function createStatistics(totalCount: number, todayCount: number, blockedCount: number): LogStatistics {
  return {
    totalCount,
    todayCount,
    blockedCount,
    byType: new Map<LogEventType, number>()
  }
}

export default function logManageViewModelTest() {
  describe('LogManageViewModel', () => {
    let viewModel: LogManageViewModel
    let context: common.UIAbilityContext
    let entries: LogEntry[]
    let statistics: LogStatistics
    let listener: ((event: LogStorageChangeEvent) => void) | null
    let clearSuccess: boolean
    let exportSuccess: boolean
    let removedListenerIds: number[]

    let originalInit: (context: common.UIAbilityContext) => Promise<boolean>
    let originalGetConfig: () => LogStorageConfig
    let originalQueryEntries: (filter?: LogFilter) => LogEntry[]
    let originalGetStatistics: () => LogStatistics
    let originalAddChangeListener: (listener: (event: LogStorageChangeEvent) => void) => number
    let originalRemoveChangeListener: (listenerId: number) => void
    let originalClearAll: () => Promise<boolean>
    let originalBuildCsvContent: (entries: LogEntry[]) => string
    let originalExportToCsvFile: (payload: LogCsvExportPayload) => Promise<LogExportResult>
    let originalCollectorInit: (context: common.UIAbilityContext) => Promise<boolean>
    let originalCollectorGetStatus: () => LogRuntimeCollectorStatus
    let originalUpdateConfig: (config: LogStorageConfig) => Promise<boolean>

    beforeEach(() => {
      viewModel = new LogManageViewModel()
      context = {} as common.UIAbilityContext
      entries = [
        createEntry('1', LogEventType.FILE, LogEventResult.SUCCESS, 'file log'),
        createEntry('2', LogEventType.PERMISSION, LogEventResult.BLOCKED, 'permission log')
      ]
      statistics = createStatistics(2, 2, 1)
      statistics.byType.set(LogEventType.FILE, 1)
      statistics.byType.set(LogEventType.PERMISSION, 1)
      listener = null
      clearSuccess = true
      exportSuccess = true
      removedListenerIds = []

      originalInit = LogStorageService.init
      originalGetConfig = LogStorageService.getConfig
      originalQueryEntries = LogStorageService.queryEntries
      originalGetStatistics = LogStorageService.getStatistics
      originalAddChangeListener = LogStorageService.addChangeListener
      originalRemoveChangeListener = LogStorageService.removeChangeListener
      originalClearAll = LogStorageService.clearAll
      originalBuildCsvContent = LogStorageService.buildCsvContent
      originalExportToCsvFile = LogStorageService.exportToCsvFile
      originalCollectorInit = LogRuntimeCollectorService.init
      originalCollectorGetStatus = LogRuntimeCollectorService.getStatus
      originalUpdateConfig = LogStorageService.updateConfig

      LogStorageService.init = async (_context: common.UIAbilityContext): Promise<boolean> => true
      LogStorageService.getConfig = (): LogStorageConfig => ({
        maxLocalEntries: DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries,
        retentionDays: DEFAULT_LOG_STORAGE_CONFIG.retentionDays
      })
      LogStorageService.queryEntries = (_filter?: LogFilter): LogEntry[] => entries.slice()
      LogStorageService.getStatistics = (): LogStatistics => statistics
      LogStorageService.addChangeListener = (nextListener: (event: LogStorageChangeEvent) => void): number => {
        listener = nextListener
        return 7
      }
      LogStorageService.removeChangeListener = (listenerId: number): void => {
        removedListenerIds.push(listenerId)
      }
      LogStorageService.clearAll = async (): Promise<boolean> => {
        if (clearSuccess) {
          entries = []
          statistics = createStatistics(0, 0, 0)
        }
        return clearSuccess
      }
      LogStorageService.buildCsvContent = (_entries: LogEntry[]): string => 'csv-content'
      LogStorageService.exportToCsvFile = async (_payload: LogCsvExportPayload): Promise<LogExportResult> => {
        if (exportSuccess) {
          return {
            success: true,
            timestamp: Date.now(),
            fileName: 'security_log.csv'
          }
        }
        return {
          success: false,
          timestamp: Date.now(),
          errorMessage: '导出失败'
        }
      }
      LogStorageService.updateConfig = async (_config: LogStorageConfig): Promise<boolean> => true
      LogRuntimeCollectorService.init = async (_context: common.UIAbilityContext): Promise<boolean> => true
      LogRuntimeCollectorService.getStatus = (): LogRuntimeCollectorStatus => ({
        running: true,
        subscribed: true
      })
    })

    afterEach(() => {
      LogStorageService.init = originalInit
      LogStorageService.getConfig = originalGetConfig
      LogStorageService.queryEntries = originalQueryEntries
      LogStorageService.getStatistics = originalGetStatistics
      LogStorageService.addChangeListener = originalAddChangeListener
      LogStorageService.removeChangeListener = originalRemoveChangeListener
      LogStorageService.clearAll = originalClearAll
      LogStorageService.buildCsvContent = originalBuildCsvContent
      LogStorageService.exportToCsvFile = originalExportToCsvFile
      LogStorageService.updateConfig = originalUpdateConfig
      LogRuntimeCollectorService.init = originalCollectorInit
      LogRuntimeCollectorService.getStatus = originalCollectorGetStatus
    })

    it('should initialize aggregated state from storage and collector', 0, async (done: Function) => {
      await viewModel.initialize(context)

      expect(viewModel.state.summary.totalCount).assertEqual(2)
      expect(viewModel.state.summary.todayCount).assertEqual(2)
      expect(viewModel.state.summary.blockedCount).assertEqual(1)
      expect(viewModel.state.summary.currentShownCount).assertEqual(2)
      expect(viewModel.state.list.allEntries.length).assertEqual(2)
      expect(viewModel.state.list.pagedEntries.length).assertEqual(2)
      expect(viewModel.state.collector.running).assertTrue()
      expect(viewModel.state.collector.fileSubscribed).assertTrue()
      done()
    })

    it('should refresh from listener only when active and auto refresh is enabled', 0, async (done: Function) => {
      await viewModel.initialize(context)

      entries = [createEntry('3', LogEventType.FILE, LogEventResult.SUCCESS, 'new log')]
      statistics = createStatistics(1, 1, 0)
      if (listener) {
        listener({ totalCount: 1, addedCount: 1, timestamp: Date.now() })
      }
      expect(viewModel.state.list.allEntries.length).assertEqual(2)

      viewModel.activate()
      if (listener) {
        listener({ totalCount: 1, addedCount: 1, timestamp: Date.now() })
      }
      expect(viewModel.state.list.allEntries.length).assertEqual(1)

      viewModel.setMode('settings')
      entries = [
        createEntry('4', LogEventType.PERMISSION, LogEventResult.BLOCKED, 'blocked log'),
        createEntry('5', LogEventType.FILE, LogEventResult.SUCCESS, 'file log')
      ]
      statistics = createStatistics(2, 2, 1)
      if (listener) {
        listener({ totalCount: 2, addedCount: 1, timestamp: Date.now() })
      }
      expect(viewModel.state.list.allEntries.length).assertEqual(1)
      done()
    })

    it('should update pagination and reset current page on filter change', 0, async (done: Function) => {
      await viewModel.initialize(context)

      viewModel.setPageSizeIndex(0)
      viewModel.setPageInputText('2')
      viewModel.jumpToInputPage()
      viewModel.setKeyword('abc')

      expect(viewModel.state.pagination.currentPage).assertEqual(1)
      expect(viewModel.state.pagination.pageInputText).assertEqual('1')
      done()
    })

    it('should return failure when exporting empty logs and success when entries exist', 0, async (done: Function) => {
      await viewModel.initialize(context)

      entries = []
      statistics = createStatistics(0, 0, 0)
      viewModel.refreshAll()
      let emptyResult = await viewModel.exportLogs()
      expect(emptyResult.success).assertFalse()

      entries = [createEntry('6', LogEventType.FILE, LogEventResult.SUCCESS, 'export log')]
      statistics = createStatistics(1, 1, 0)
      viewModel.refreshAll()
      let exportResult = await viewModel.exportLogs()
      expect(exportResult.success).assertTrue()
      expect(exportResult.fileName).assertEqual('security_log.csv')
      done()
    })

    it('should clear logs and reset detail state', 0, async (done: Function) => {
      await viewModel.initialize(context)
      viewModel.openDetail('1')

      let success = await viewModel.clearLogs()

      expect(success).assertTrue()
      expect(viewModel.state.list.allEntries.length).assertEqual(0)
      expect(viewModel.state.list.pagedEntries.length).assertEqual(0)
      expect(viewModel.state.summary.totalCount).assertEqual(0)
      expect(viewModel.state.detail.visible).assertFalse()
      expect(viewModel.state.detail.entryId).assertEqual('')
      done()
    })

    it('should unregister listener on destroy', 0, async (done: Function) => {
      await viewModel.initialize(context)

      viewModel.destroy()

      expect(removedListenerIds.length).assertEqual(1)
      expect(removedListenerIds[0]).assertEqual(7)
      done()
    })
  })
}

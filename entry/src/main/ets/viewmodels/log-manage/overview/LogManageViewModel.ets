import { common } from '@kit.AbilityKit'
import { MessageText } from '../../../constants/StringCatalog'
import { LogManageClearingStrings } from '../../../constants/modules/LogManageStrings'
import {
  ExportActionResult,
  LogEntry,
  LOG_EVENT_RESULT_OPTIONS,
  LOG_EVENT_TYPE_OPTIONS
} from '../../../models/DataModels'
import { LOG_PAGE_SIZE_OPTIONS, LogManageMode, LogManageState } from '../../../models/LogManageModels'
import {
  ClearLogsResult,
  ExportLogsResult,
  InitializeResult,
  ListViewInitializeResult,
  LogExportServicePort,
  LogQuery,
  LogStoragePort,
  LogSnapshot,
  RefreshResult,
  SaveSettingsResult
} from '../../../services/log-manage/common/LogManagePorts'
import { LogExportService } from '../../../services/log-manage/export/LogExportService'
import { LogStorageMaintenanceService } from '../../../services/log-manage/maintenance/LogStorageMaintenanceService'
import { LogEntryRepository } from '../../../services/log-manage/repository/LogEntryRepository'
import { LogUtils } from '../../../utils/LogUtils'
import { LogStorageSettingsViewModel } from '../storage-settings/LogStorageSettingsViewModel'

const TAG = 'LogManageViewModel'

interface LogPaginationSnapshot {
  currentPage: number
  pageSizeIndex: number
  pageInputText: string
  totalPages: number
}

class DefaultLogManageStorage implements LogStoragePort {
  init(context: common.UIAbilityContext): Promise<InitializeResult> {
    return LogStorageMaintenanceService.initialize(context)
  }

  count(query?: LogQuery): Promise<number> {
    return LogEntryRepository.countByQuery(query)
  }

  list(query?: LogQuery, limit?: number, offset?: number): Promise<LogEntry[]> {
    return LogEntryRepository.listByQuery(query, limit, offset)
  }

  hasEntry(entryId: string, query?: LogQuery): Promise<boolean> {
    return LogEntryRepository.hasEntry(entryId, query)
  }

  async snapshot(query?: LogQuery, limit?: number, offset?: number, filteredCount?: number): Promise<LogSnapshot> {
    let statistics = await LogEntryRepository.getStatistics()
    let resolvedFilteredCount = filteredCount ?? await this.count(query)
    let entries = await this.list(query, limit, offset)
    return {
      totalCount: statistics.totalCount,
      todayCount: statistics.todayCount,
      blockedCount: statistics.blockedCount,
      filteredCount: resolvedFilteredCount,
      entries
    }
  }

  clear(): Promise<ClearLogsResult> {
    return LogStorageMaintenanceService.clearAll()
  }

  addChangeListener(listener: () => void): number {
    return LogEntryRepository.addChangeListener(listener)
  }

  removeChangeListener(listenerId: number): void {
    LogEntryRepository.removeChangeListener(listenerId)
  }
}

class DefaultLogManageExporter implements LogExportServicePort {
  export(context: common.UIAbilityContext | null, query?: LogQuery, fileNamePrefix?: string): Promise<ExportLogsResult> {
    return LogExportService.export(context, query, fileNamePrefix)
  }
}

@ObservedV2
export class LogManageViewModel {
  @Trace state: LogManageState = new LogManageState()
  readonly settingsViewModel: LogStorageSettingsViewModel
  private listenerId: number = -1
  private initialized: boolean = false
  private storage: LogStoragePort
  private exporter: LogExportServicePort

  constructor(
    storage: LogStoragePort = new DefaultLogManageStorage(),
    exporter: LogExportServicePort = new DefaultLogManageExporter(),
    settingsViewModel: LogStorageSettingsViewModel = new LogStorageSettingsViewModel()
  ) {
    this.storage = storage
    this.exporter = exporter
    this.settingsViewModel = settingsViewModel
  }

  async initialize(context: common.UIAbilityContext): Promise<ListViewInitializeResult> {
    this.state.initialized = false
    this.state.loading = true
    let initializeResult: ListViewInitializeResult = { success: false, code: 'storage_init_failed' }
    try {
      if (!this.initialized) {
        let initResult = await this.storage.init(context)
        if (!initResult.success) {
          LogUtils.error(TAG, `initialize storage failed: ${initResult.code}`)
          return initializeResult
        }
        this.registerStorageListener()
        this.initialized = true
      }
      await this.settingsViewModel.load()
      this.state.mode = 'list'
      this.state.autoRefreshEnabled = true
      initializeResult = await this.initializeSnapshot()
      return initializeResult
    } catch (err) {
      LogUtils.error(TAG, `initialize failed: ${JSON.stringify(err)}`)
      return initializeResult
    } finally {
      this.state.initialized = initializeResult.success
      this.state.loading = false
    }
  }

  activate(): void {
    this.state.active = true
  }

  deactivate(): void {
    this.state.active = false
  }

  destroy(): void {
    this.unregisterStorageListener()
    this.initialized = false
    this.state.initialized = false
    this.state.active = false
    this.state.autoRefreshEnabled = false
  }

  async refreshAll(): Promise<RefreshResult> {
    try {
      await this.rebuildStateFromSnapshot()
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `refreshAll failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'query_failed' }
    }
  }

  async refreshIfActive(): Promise<RefreshResult> {
    if (!this.state.active || !this.state.autoRefreshEnabled) {
      return { success: false, code: 'skipped_inactive' }
    }
    return this.refreshAll()
  }

  async setMode(mode: LogManageMode): Promise<void> {
    if (mode === 'settings') {
      await this.settingsViewModel.load()
      this.closeDetail()
      this.state.mode = 'settings'
      this.state.active = false
      this.state.autoRefreshEnabled = false
      return
    }

    this.state.mode = 'list'
    this.state.active = true
    this.state.autoRefreshEnabled = true
    await this.refreshAll()
  }

  async setEventTypeIndex(index: number): Promise<void> {
    this.state.filter.eventTypeIndex = this.normalizeFilterIndex(index, LOG_EVENT_TYPE_OPTIONS.length + 1)
    this.resetToFirstPage()
    await this.refreshAll()
  }

  async setResultIndex(index: number): Promise<void> {
    this.state.filter.resultIndex = this.normalizeFilterIndex(index, LOG_EVENT_RESULT_OPTIONS.length + 1)
    this.resetToFirstPage()
    await this.refreshAll()
  }

  async setKeyword(keyword: string): Promise<void> {
    this.state.filter.keyword = keyword
    this.resetToFirstPage()
    await this.refreshAll()
  }

  async setPageSizeIndex(index: number): Promise<RefreshResult> {
    let previousPagination = this.capturePaginationState()
    this.state.pagination.pageSizeIndex = this.normalizePageSizeIndex(index)
    this.resetToFirstPage()
    return this.rebuildPaginationSafely('setPageSizeIndex', previousPagination)
  }

  setPageInputText(text: string): void {
    this.state.pagination.pageInputText = text.replace(/[^0-9]/g, '')
  }

  async jumpToInputPage(): Promise<RefreshResult> {
    return this.changePage(this.normalizePage(this.state.pagination.pageInputText, this.state.pagination.totalPages))
  }

  async goToPreviousPage(): Promise<RefreshResult> {
    if (this.state.pagination.currentPage <= 1) {
      return { success: true, code: 'ok' }
    }
    return this.changePage(this.state.pagination.currentPage - 1)
  }

  async goToNextPage(): Promise<RefreshResult> {
    if (this.state.pagination.currentPage >= this.state.pagination.totalPages) {
      return { success: true, code: 'ok' }
    }
    return this.changePage(this.state.pagination.currentPage + 1)
  }

  openDetail(entryId: string): void {
    this.state.detail.visible = true
    this.state.detail.entryId = entryId
  }

  closeDetail(): void {
    this.state.detail.visible = false
    this.state.detail.entryId = ''
  }

  async clearLogs(): Promise<ClearLogsResult> {
    if (this.state.summary.totalCount <= 0) {
      return { success: false, code: 'already_empty' }
    }
    let result = await this.storage.clear()
    if (!result.success) {
      return { success: false, code: 'clear_failed' }
    }
    this.closeDetail()
    await this.rebuildStateFromSnapshot()
    return { success: true, code: 'ok' }
  }

  async exportLogs(context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    let result: ExportLogsResult = await this.exporter.export(context, this.buildQuery())
    if (result.success) {
      return {
        success: true,
        fileName: result.fileName
      }
    }
    return {
      success: false,
      reason: this.mapExportError(result.code)
    }
  }

  async saveStorageSettings(): Promise<SaveSettingsResult> {
    let result = await this.settingsViewModel.save()
    if (result.success) {
      await this.setMode('list')
    }
    return result
  }

  private registerStorageListener(): void {
    if (this.listenerId > 0) {
      return
    }
    this.listenerId = this.storage.addChangeListener(() => {
      void this.refreshIfActive()
    })
  }

  private unregisterStorageListener(): void {
    if (this.listenerId > 0) {
      this.storage.removeChangeListener(this.listenerId)
      this.listenerId = -1
    }
  }

  private async initializeSnapshot(): Promise<ListViewInitializeResult> {
    let refreshResult = await this.refreshAll()
    if (refreshResult.success) {
      return { success: true, code: 'ok' }
    }
    return {
      success: false,
      code: refreshResult.code === 'query_failed' ? 'query_failed' : 'storage_init_failed'
    }
  }

  private async rebuildStateFromSnapshot(): Promise<void> {
    let pageSize = LOG_PAGE_SIZE_OPTIONS[this.state.pagination.pageSizeIndex] ?? LOG_PAGE_SIZE_OPTIONS[0]
    let currentQuery = this.buildQuery()
    let filteredCount = await this.storage.count(currentQuery)
    let totalPages = this.calcTotalPages(filteredCount, pageSize)
    let currentPage = this.normalizePage(`${this.state.pagination.currentPage}`, totalPages)
    let pageStart = (currentPage - 1) * pageSize
    let snapshot = await this.storage.snapshot(currentQuery, pageSize, pageStart, filteredCount)

    this.applySummaryState(snapshot, snapshot.entries.length)
    this.applyListState(snapshot)
    this.applyPaginationState(currentPage, totalPages)
    await this.syncDetailState(currentQuery)
  }

  private buildQuery(): LogQuery | undefined {
    let query: LogQuery = {}
    let hasQuery = false
    if (this.state.filter.eventTypeIndex > 0) {
      query.eventTypes = [LOG_EVENT_TYPE_OPTIONS[this.state.filter.eventTypeIndex - 1].value]
      hasQuery = true
    }
    if (this.state.filter.resultIndex > 0) {
      let resultOption = LOG_EVENT_RESULT_OPTIONS[this.state.filter.resultIndex - 1]
      if (resultOption) {
        query.results = [resultOption.value]
        hasQuery = true
      }
    }
    let keyword = this.state.filter.keyword.trim()
    if (keyword.length > 0) {
      query.keyword = keyword
      hasQuery = true
    }
    return hasQuery ? query : undefined
  }

  private applySummaryState(snapshot: LogSnapshot, currentShownCount: number): void {
    this.state.summary.totalCount = snapshot.totalCount
    this.state.summary.filteredCount = snapshot.filteredCount
    this.state.summary.todayCount = snapshot.todayCount
    this.state.summary.blockedCount = snapshot.blockedCount
    this.state.summary.currentShownCount = currentShownCount
  }

  private applyListState(snapshot: LogSnapshot): void {
    this.state.list.pagedEntries = snapshot.entries.slice()
  }

  private applyPaginationState(currentPage: number, totalPages: number): void {
    this.state.pagination.currentPage = currentPage
    this.state.pagination.totalPages = totalPages
    this.state.pagination.pageInputText = `${currentPage}`
  }

  private async syncDetailState(query?: LogQuery): Promise<void> {
    if (this.state.detail.entryId.length === 0) {
      return
    }
    let exists = await this.storage.hasEntry(this.state.detail.entryId, query)
    if (exists) {
      return
    }
    this.closeDetail()
  }

  private resetToFirstPage(): void {
    this.state.pagination.currentPage = 1
    this.state.pagination.pageInputText = '1'
  }

  private normalizeFilterIndex(index: number, optionCount: number): number {
    if (index < 0) {
      return 0
    }
    if (index >= optionCount) {
      return optionCount - 1
    }
    return index
  }

  private normalizePageSizeIndex(index: number): number {
    if (index < 0) {
      return 0
    }
    if (index >= LOG_PAGE_SIZE_OPTIONS.length) {
      return LOG_PAGE_SIZE_OPTIONS.length - 1
    }
    return index
  }

  private normalizePage(text: string, totalPages: number): number {
    let parsed = Number(text.trim())
    if (!Number.isFinite(parsed) || parsed < 1) {
      return 1
    }
    if (parsed > totalPages) {
      return totalPages
    }
    return Math.floor(parsed)
  }

  private calcTotalPages(totalCount: number, pageSize: number): number {
    if (totalCount <= 0) {
      return 1
    }
    return Math.max(1, Math.ceil(totalCount / pageSize))
  }

  private async changePage(targetPage: number): Promise<RefreshResult> {
    let previousPagination = this.capturePaginationState()
    let currentPage = this.normalizePage(`${targetPage}`, this.state.pagination.totalPages)
    this.state.pagination.currentPage = currentPage
    this.state.pagination.pageInputText = `${currentPage}`
    return this.rebuildPaginationSafely('changePage', previousPagination)
  }

  private capturePaginationState(): LogPaginationSnapshot {
    return {
      currentPage: this.state.pagination.currentPage,
      pageSizeIndex: this.state.pagination.pageSizeIndex,
      pageInputText: this.state.pagination.pageInputText,
      totalPages: this.state.pagination.totalPages
    }
  }

  private restorePaginationState(snapshot: LogPaginationSnapshot): void {
    this.state.pagination.currentPage = snapshot.currentPage
    this.state.pagination.pageSizeIndex = snapshot.pageSizeIndex
    this.state.pagination.pageInputText = snapshot.pageInputText
    this.state.pagination.totalPages = snapshot.totalPages
  }

  private async rebuildPaginationSafely(
    operationName: string,
    previousPagination: LogPaginationSnapshot
  ): Promise<RefreshResult> {
    try {
      await this.rebuildStateFromSnapshot()
      return { success: true, code: 'ok' }
    } catch (err) {
      this.restorePaginationState(previousPagination)
      LogUtils.error(TAG, `${operationName} failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'query_failed' }
    }
  }

  private mapExportError(code: string): string {
    if (code === 'empty') {
      return LogManageClearingStrings.NO_EXPORTABLE_LOGS
    }
    return MessageText.RETRY_LATER
  }
}

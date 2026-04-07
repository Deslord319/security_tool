import { common } from '@kit.AbilityKit'
import { CommonStrings } from '../../../constants/CommonStrings'
import { EmptyStateStrings } from '../../../constants/modules/DialogStrings'
import { LogManageStrings } from '../../../constants/modules/LogManageStrings'
import {
  ExportActionResult,
  LogEntry,
  LogEventResult,
  LOG_EVENT_TYPE_OPTIONS
} from '../../../models/DataModels'
import { LogManageMode, LogManageState } from '../../../models/LogManageModels'
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
  RefreshResult,
  SaveSettingsResult
} from '../../../services/log-manage/common/LogManagePorts'
import { LogCollectorService } from '../../../services/log-manage/collector/LogCollectorService'
import { LogExportService } from '../../../services/log-manage/export/LogExportService'
import { LogRepository } from '../../../services/log-manage/repository/LogRepository'
import { LogUtils } from '../../../utils/LogUtils'
import { LogStorageSettingsViewModel } from '../storage-settings/LogStorageSettingsViewModel'

const TAG = 'LogManageViewModel'
const PAGE_SIZE_OPTIONS: number[] = [20, 50, 100]

class DefaultLogManageRepository implements LogRepositoryPort {
  init(context: common.UIAbilityContext): Promise<InitializeResult> {
    return LogRepository.init(context)
  }

  addEntries(entries: LogEntry[]): Promise<MutationResult> {
    return LogRepository.addEntries(entries)
  }

  snapshot(query?: LogQuery): LogSnapshot {
    return LogRepository.snapshot(query)
  }

  clear(): Promise<ClearLogsResult> {
    return LogRepository.clear()
  }

  addChangeListener(listener: () => void): number {
    return LogRepository.addChangeListener(listener)
  }

  removeChangeListener(listenerId: number): void {
    LogRepository.removeChangeListener(listenerId)
  }
}

class DefaultLogManageExporter implements LogExportServicePort {
  export(context: common.UIAbilityContext | null, entries: LogEntry[], fileNamePrefix?: string): Promise<ExportLogsResult> {
    return LogExportService.export(context, entries, fileNamePrefix)
  }
}

class DefaultLogManageCollector implements LogCollectorStatusPort {
  getStatus(): CollectorStatus {
    return LogCollectorService.getStatus()
  }
}

@ObservedV2
export class LogManageViewModel {
  @Trace state: LogManageState = new LogManageState()
  readonly settingsViewModel: LogStorageSettingsViewModel
  private listenerId: number = -1
  private initialized: boolean = false
  private repository: LogRepositoryPort
  private exporter: LogExportServicePort
  private collector: LogCollectorStatusPort

  constructor(
    repository: LogRepositoryPort = new DefaultLogManageRepository(),
    exporter: LogExportServicePort = new DefaultLogManageExporter(),
    collector: LogCollectorStatusPort = new DefaultLogManageCollector(),
    settingsViewModel: LogStorageSettingsViewModel = new LogStorageSettingsViewModel()
  ) {
    this.repository = repository
    this.exporter = exporter
    this.collector = collector
    this.settingsViewModel = settingsViewModel
  }

  async initialize(context: common.UIAbilityContext): Promise<ListViewInitializeResult> {
    this.state.initialized = false
    this.state.loading = true
    try {
      if (!this.initialized) {
        let initResult = await this.repository.init(context)
        if (!initResult.success) {
          return { success: false, code: 'storage_init_failed' }
        }
        this.registerStorageListener()
        this.initialized = true
      }
      await this.settingsViewModel.load()
      this.state.mode = 'list'
      this.state.autoRefreshEnabled = true
      return await this.initializeSnapshot()
    } catch (err) {
      LogUtils.error(TAG, `initialize failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'storage_init_failed' }
    } finally {
      this.state.initialized = true
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
      this.rebuildStateFromSnapshot()
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
    this.state.filter.resultIndex = this.normalizeFilterIndex(index, 4)
    this.resetToFirstPage()
    await this.refreshAll()
  }

  async setKeyword(keyword: string): Promise<void> {
    this.state.filter.keyword = keyword
    this.resetToFirstPage()
    await this.refreshAll()
  }

  setPageSizeIndex(index: number): void {
    this.state.pagination.pageSizeIndex = this.normalizePageSizeIndex(index)
    this.resetToFirstPage()
    this.rebuildStateFromSnapshot()
  }

  setPageInputText(text: string): void {
    this.state.pagination.pageInputText = text.replace(/[^0-9]/g, '')
  }

  jumpToInputPage(): void {
    this.changePage(this.normalizePage(this.state.pagination.pageInputText, this.state.pagination.totalPages))
  }

  goToPreviousPage(): void {
    if (this.state.pagination.currentPage <= 1) {
      return
    }
    this.changePage(this.state.pagination.currentPage - 1)
  }

  goToNextPage(): void {
    if (this.state.pagination.currentPage >= this.state.pagination.totalPages) {
      return
    }
    this.changePage(this.state.pagination.currentPage + 1)
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
    let result = await this.repository.clear()
    if (!result.success) {
      return { success: false, code: 'clear_failed' }
    }
    this.closeDetail()
    this.rebuildStateFromSnapshot()
    return { success: true, code: 'ok' }
  }

  async exportLogs(context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    let result: ExportLogsResult = await this.exporter.export(context, this.state.list.allEntries)
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
    this.listenerId = this.repository.addChangeListener(() => {
      void this.refreshIfActive()
    })
  }

  private unregisterStorageListener(): void {
    if (this.listenerId > 0) {
      this.repository.removeChangeListener(this.listenerId)
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

  private rebuildStateFromSnapshot(): void {
    let snapshot = this.repository.snapshot(this.buildQuery())
    let pageSize = PAGE_SIZE_OPTIONS[this.state.pagination.pageSizeIndex] ?? PAGE_SIZE_OPTIONS[0]
    let totalPages = this.calcTotalPages(snapshot.entries.length, pageSize)
    let currentPage = this.normalizePage(`${this.state.pagination.currentPage}`, totalPages)
    let pageStart = (currentPage - 1) * pageSize
    let pagedEntries = snapshot.entries.slice(pageStart, pageStart + pageSize)

    this.applyCollectorState()
    this.applySummaryState(snapshot, pagedEntries.length)
    this.applyListState(snapshot, pagedEntries)
    this.applyPaginationState(currentPage, totalPages)
    this.rebuildFilterHint(snapshot)
    this.syncDetailState()
  }

  private buildQuery(): LogQuery | undefined {
    let query: LogQuery = {}
    let hasQuery = false
    if (this.state.filter.eventTypeIndex > 0) {
      query.eventTypes = [LOG_EVENT_TYPE_OPTIONS[this.state.filter.eventTypeIndex - 1].value]
      hasQuery = true
    }
    if (this.state.filter.resultIndex > 0) {
      query.results = [this.mapResultIndexToValue(this.state.filter.resultIndex)]
      hasQuery = true
    }
    let keyword = this.state.filter.keyword.trim()
    if (keyword.length > 0) {
      query.keyword = keyword
      hasQuery = true
    }
    return hasQuery ? query : undefined
  }

  private applyCollectorState(): void {
    let source = this.collector.getStatus()
    this.state.collector.running = source.running
    this.state.collector.auditReady = source.auditReady
    this.state.collector.crashReady = source.crashReady
    this.state.collector.pendingCount = source.pendingCount
    this.state.collector.degraded = source.degraded
    this.state.collector.degradedReason = source.degradedReason
  }

  private applySummaryState(snapshot: LogSnapshot, currentShownCount: number): void {
    this.state.summary.totalCount = snapshot.totalCount
    this.state.summary.todayCount = snapshot.todayCount
    this.state.summary.blockedCount = snapshot.blockedCount
    this.state.summary.currentShownCount = currentShownCount
  }

  private applyListState(snapshot: LogSnapshot, pagedEntries: LogEntry[]): void {
    this.state.list.allEntries = snapshot.entries.slice()
    this.state.list.pagedEntries = pagedEntries
  }

  private applyPaginationState(currentPage: number, totalPages: number): void {
    this.state.pagination.currentPage = currentPage
    this.state.pagination.totalPages = totalPages
    this.state.pagination.pageInputText = `${currentPage}`
  }

  private rebuildFilterHint(snapshot: LogSnapshot): void {
    if (snapshot.entries.length > 0) {
      this.state.filter.hintMessage = this.state.filter.eventTypeIndex === 1 ? LogManageStrings.fileFilterHint : ''
      return
    }
    if (this.state.filter.eventTypeIndex === 1) {
      this.state.filter.hintMessage = LogManageStrings.fileFilterEmptyHint
      return
    }
    if (this.state.filter.eventTypeIndex > 0 ||
      this.state.filter.resultIndex > 0 ||
      this.state.filter.keyword.trim().length > 0) {
      this.state.filter.hintMessage = LogManageStrings.emptyDescription
      return
    }
    this.state.filter.hintMessage = (!this.state.collector.running || this.state.collector.degraded) ?
      EmptyStateStrings.CHECK_PERMISSIONS :
      LogManageStrings.emptyDescription
  }

  private syncDetailState(): void {
    if (this.state.detail.entryId.length === 0) {
      return
    }
    for (let entry of this.state.list.allEntries) {
      if (entry.id === this.state.detail.entryId) {
        return
      }
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
    if (index >= PAGE_SIZE_OPTIONS.length) {
      return PAGE_SIZE_OPTIONS.length - 1
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

  private changePage(targetPage: number): void {
    let currentPage = this.normalizePage(`${targetPage}`, this.state.pagination.totalPages)
    this.state.pagination.currentPage = currentPage
    this.state.pagination.pageInputText = `${currentPage}`
    this.rebuildStateFromSnapshot()
  }

  private mapResultIndexToValue(index: number): LogEventResult {
    switch (index) {
      case 1:
        return LogEventResult.SUCCESS
      case 2:
        return LogEventResult.BLOCKED
      case 3:
        return LogEventResult.FAILED
      default:
        return LogEventResult.SUCCESS
    }
  }

  private mapExportError(code: string): string {
    if (code === 'empty') {
      return LogManageStrings.noExportableLogs
    }
    return CommonStrings.messageRetryLater
  }
}

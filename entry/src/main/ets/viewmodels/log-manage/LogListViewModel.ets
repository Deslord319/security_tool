import { common } from '@kit.AbilityKit'
import { CommonStrings } from '../../constants/CommonStrings'
import { EmptyStateStrings } from '../../constants/modules/DialogStrings'
import { LogManageStrings } from '../../constants/modules/LogManageStrings'
import {
  ExportActionResult,
  LogEntry,
  LogEventResult,
  LOG_EVENT_TYPE_OPTIONS
} from '../../models/DataModels'
import {
  LogCollectorUiStatus,
  LogFilterUiState,
  LogListPageState,
  LogPaginationState,
  LogSummaryState
} from '../../models/LogListModels'
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
  RefreshResult
} from '../../services/log-manage/common/LogManagePorts'
import { LogCollectorService } from '../../services/log-manage/collector/LogCollectorService'
import { LogExportService } from '../../services/log-manage/export/LogExportService'
import { LogRepository } from '../../services/log-manage/repository/LogRepository'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'LogListViewModel'
const PAGE_SIZE_OPTIONS: number[] = [20, 50, 100]

class DefaultLogListRepository implements LogRepositoryPort {
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

class DefaultLogListExporter implements LogExportServicePort {
  export(context: common.UIAbilityContext | null, entries: LogEntry[], fileNamePrefix?: string): Promise<ExportLogsResult> {
    return LogExportService.export(context, entries, fileNamePrefix)
  }
}

class DefaultLogListCollector implements LogCollectorStatusPort {
  getStatus(): CollectorStatus {
    return LogCollectorService.getStatus()
  }
}

@Observed
export class LogListViewModel {
  state: LogListPageState = new LogListPageState()
  private listenerId: number = -1
  private initialized: boolean = false
  private repository: LogRepositoryPort
  private exporter: LogExportServicePort
  private collector: LogCollectorStatusPort

  constructor(
    repository: LogRepositoryPort = new DefaultLogListRepository(),
    exporter: LogExportServicePort = new DefaultLogListExporter(),
    collector: LogCollectorStatusPort = new DefaultLogListCollector()
  ) {
    this.repository = repository
    this.exporter = exporter
    this.collector = collector
  }

  async initialize(context: common.UIAbilityContext): Promise<ListViewInitializeResult> {
    this.setLoading(true)
    try {
      if (!this.initialized) {
        let initResult = await this.repository.init(context)
        if (!initResult.success) {
          return { success: false, code: 'storage_init_failed' }
        }
        this.registerListener()
        this.initialized = true
      }
      return await this.initializeSnapshot()
    } catch (err) {
      LogUtils.error(TAG, `initialize failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'storage_init_failed' }
    } finally {
      this.setLoading(false)
    }
  }

  activate(): void {
    this.updatePageState(true, this.state.autoRefreshEnabled)
  }

  deactivate(): void {
    this.updatePageState(false, this.state.autoRefreshEnabled)
  }

  setAutoRefreshEnabled(enabled: boolean): void {
    this.updatePageState(this.state.active, enabled)
  }

  destroy(): void {
    if (this.listenerId > 0) {
      this.repository.removeChangeListener(this.listenerId)
      this.listenerId = -1
    }
    this.initialized = false
    this.updatePageState(false, false)
  }

  async refresh(): Promise<RefreshResult> {
    try {
      this.rebuildStateFromSnapshot()
      return { success: true, code: 'ok' }
    } catch (err) {
      LogUtils.error(TAG, `refresh failed: ${JSON.stringify(err)}`)
      return { success: false, code: 'query_failed' }
    }
  }

  async refreshIfActive(): Promise<RefreshResult> {
    if (!this.state.active || !this.state.autoRefreshEnabled) {
      return { success: false, code: 'skipped_inactive' }
    }
    return this.refresh()
  }

  async setEventTypeIndex(index: number): Promise<void> {
    let nextState = this.cloneState()
    nextState.filter.eventTypeIndex = this.normalizeFilterIndex(index, LOG_EVENT_TYPE_OPTIONS.length + 1)
    this.applyResetToFirstPage(nextState)
    this.setState(nextState)
    await this.refresh()
  }

  async setResultIndex(index: number): Promise<void> {
    let nextState = this.cloneState()
    nextState.filter.resultIndex = this.normalizeFilterIndex(index, 4)
    this.applyResetToFirstPage(nextState)
    this.setState(nextState)
    await this.refresh()
  }

  async setKeyword(text: string): Promise<void> {
    let nextState = this.cloneState()
    nextState.filter.keywordText = text
    this.applyResetToFirstPage(nextState)
    this.setState(nextState)
    await this.refresh()
  }

  setPageSize(size: number): void {
    let nextState = this.cloneState()
    nextState.pagination.pageSize = PAGE_SIZE_OPTIONS.includes(size) ? size : PAGE_SIZE_OPTIONS[0]
    this.applyResetToFirstPage(nextState)
    this.setState(nextState)
    this.rebuildStateFromSnapshot()
  }

  setPageInputText(text: string): void {
    let nextState = this.cloneState()
    nextState.pagination.pageInputText = text.replace(/[^0-9]/g, '')
    this.setState(nextState)
  }

  jumpToPage(): void {
    this.changePage(this.normalizePage(this.state.pagination.pageInputText, this.state.pagination.totalPages))
  }

  goPrev(): void {
    if (this.state.pagination.currentPage <= 1) {
      return
    }
    this.changePage(this.state.pagination.currentPage - 1)
  }

  goNext(): void {
    if (this.state.pagination.currentPage >= this.state.pagination.totalPages) {
      return
    }
    this.changePage(this.state.pagination.currentPage + 1)
  }

  selectEntry(entryId: string): void {
    let nextState = this.cloneState()
    nextState.selectedEntryId = entryId
    this.setState(nextState)
  }

  clearSelectedEntry(): void {
    if (this.state.selectedEntryId.length === 0) {
      return
    }
    let nextState = this.cloneState()
    nextState.selectedEntryId = ''
    this.setState(nextState)
  }

  getSelectedEntry(): LogEntry | null {
    if (this.state.selectedEntryId.length === 0) {
      return null
    }
    for (let entry of this.state.entries) {
      if (entry.id === this.state.selectedEntryId) {
        return entry
      }
    }
    return null
  }

  getPageSizeOptions(): number[] {
    return PAGE_SIZE_OPTIONS.slice()
  }

  getCurrentRangeText(): string {
    if (this.state.entries.length === 0 || this.state.pagedEntries.length === 0) {
      return '0-0'
    }
    let start = (this.state.pagination.currentPage - 1) * this.state.pagination.pageSize + 1
    let end = start + this.state.pagedEntries.length - 1
    return `${start}-${end}`
  }

  hasActiveFilters(): boolean {
    return this.state.filter.eventTypeIndex > 0 ||
      this.state.filter.resultIndex > 0 ||
      this.state.filter.keywordText.trim().length > 0
  }

  async clearLogs(): Promise<ClearLogsResult> {
    if (this.state.summary.totalCount <= 0) {
      return { success: false, code: 'already_empty' }
    }
    let result = await this.repository.clear()
    if (!result.success) {
      return { success: false, code: 'clear_failed' }
    }
    this.clearSelectedEntry()
    this.rebuildStateFromSnapshot()
    return { success: true, code: 'ok' }
  }

  async exportLogs(context: common.UIAbilityContext | null): Promise<ExportActionResult> {
    let result: ExportLogsResult = await this.exporter.export(context, this.state.entries)
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

  private registerListener(): void {
    if (this.listenerId > 0) {
      return
    }
    this.listenerId = this.repository.addChangeListener(() => {
      void this.refreshIfActive()
    })
  }

  private async initializeSnapshot(): Promise<ListViewInitializeResult> {
    let refreshResult = await this.refresh()
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
    let pageSize = this.state.pagination.pageSize
    let totalPages = this.calcTotalPages(snapshot.entries.length, pageSize)
    let currentPage = this.normalizePage(`${this.state.pagination.currentPage}`, totalPages)
    let pageStart = (currentPage - 1) * pageSize
    let pagedEntries = snapshot.entries.slice(pageStart, pageStart + pageSize)
    let nextState = this.cloneState()
    nextState.collectorStatus = this.buildCollectorStatus()
    nextState.summary = this.buildSummary(snapshot)
    nextState.entries = snapshot.entries.slice()
    nextState.pagedEntries = pagedEntries
    nextState.selectedEntryId = this.resolveSelectedEntryId(snapshot.entries, nextState.selectedEntryId)
    nextState.hintMessage = this.buildHintMessage(snapshot, nextState.collectorStatus)
    nextState.pagination.currentPage = currentPage
    nextState.pagination.totalPages = totalPages
    nextState.pagination.pageInputText = `${currentPage}`
    this.setState(nextState)
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
    let keyword = this.state.filter.keywordText.trim()
    if (keyword.length > 0) {
      query.keyword = keyword
      hasQuery = true
    }
    return hasQuery ? query : undefined
  }

  private buildSummary(snapshot: LogSnapshot): LogSummaryState {
    let summary = new LogSummaryState()
    summary.totalCount = snapshot.totalCount
    summary.todayCount = snapshot.todayCount
    summary.blockedCount = snapshot.blockedCount
    return summary
  }

  private buildCollectorStatus(): LogCollectorUiStatus {
    let source = this.collector.getStatus()
    let status = new LogCollectorUiStatus()
    status.running = source.running
    status.auditReady = source.auditReady
    status.crashReady = source.crashReady
    status.pendingCount = source.pendingCount
    status.degraded = source.degraded
    status.degradedReason = source.degradedReason
    return status
  }

  private updatePageState(active: boolean, autoRefreshEnabled: boolean): void {
    let nextState = this.cloneState()
    nextState.active = active
    nextState.autoRefreshEnabled = autoRefreshEnabled
    this.setState(nextState)
  }

  private buildHintMessage(snapshot: LogSnapshot, collectorStatus: LogCollectorUiStatus): string {
    if (snapshot.entries.length > 0) {
      if (this.state.filter.eventTypeIndex === 1) {
        return LogManageStrings.fileFilterHint
      }
      return ''
    }
    if (this.state.filter.eventTypeIndex === 1) {
      return LogManageStrings.fileFilterEmptyHint
    }
    if (this.hasActiveFilters()) {
      return LogManageStrings.emptyDescription
    }
    if (!collectorStatus.running || collectorStatus.degraded) {
      return EmptyStateStrings.CHECK_PERMISSIONS
    }
    return LogManageStrings.emptyDescription
  }

  private resolveSelectedEntryId(entries: LogEntry[], selectedEntryId: string): string {
    if (selectedEntryId.length === 0) {
      return ''
    }
    for (let entry of entries) {
      if (entry.id === selectedEntryId) {
        return selectedEntryId
      }
    }
    return ''
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

  private setLoading(loading: boolean): void {
    let nextState = this.cloneState()
    nextState.loading = loading
    this.setState(nextState)
  }

  private changePage(targetPage: number): void {
    let nextState = this.cloneState()
    let currentPage = this.normalizePage(`${targetPage}`, nextState.pagination.totalPages)
    nextState.pagination.currentPage = currentPage
    nextState.pagination.pageInputText = `${currentPage}`
    this.setState(nextState)
    this.rebuildStateFromSnapshot()
  }

  private setState(nextState: LogListPageState): void {
    this.state = nextState
  }

  private applyResetToFirstPage(state: LogListPageState): void {
    state.pagination.currentPage = 1
    state.pagination.pageInputText = '1'
  }

  private cloneState(): LogListPageState {
    let nextState = new LogListPageState()
    nextState.loading = this.state.loading
    nextState.active = this.state.active
    nextState.autoRefreshEnabled = this.state.autoRefreshEnabled
    nextState.collectorStatus = this.cloneCollectorStatus(this.state.collectorStatus)

    let summary = new LogSummaryState()
    summary.totalCount = this.state.summary.totalCount
    summary.todayCount = this.state.summary.todayCount
    summary.blockedCount = this.state.summary.blockedCount
    nextState.summary = summary

    let filter = new LogFilterUiState()
    filter.eventTypeIndex = this.state.filter.eventTypeIndex
    filter.resultIndex = this.state.filter.resultIndex
    filter.keywordText = this.state.filter.keywordText
    nextState.filter = filter

    let pagination = new LogPaginationState()
    pagination.currentPage = this.state.pagination.currentPage
    pagination.totalPages = this.state.pagination.totalPages
    pagination.pageSize = this.state.pagination.pageSize
    pagination.pageInputText = this.state.pagination.pageInputText
    nextState.pagination = pagination

    nextState.entries = this.state.entries.slice()
    nextState.pagedEntries = this.state.pagedEntries.slice()
    nextState.selectedEntryId = this.state.selectedEntryId
    nextState.hintMessage = this.state.hintMessage
    return nextState
  }

  private cloneCollectorStatus(source: LogCollectorUiStatus): LogCollectorUiStatus {
    let status = new LogCollectorUiStatus()
    status.running = source.running
    status.auditReady = source.auditReady
    status.crashReady = source.crashReady
    status.pendingCount = source.pendingCount
    status.degraded = source.degraded
    status.degradedReason = source.degradedReason
    return status
  }
}

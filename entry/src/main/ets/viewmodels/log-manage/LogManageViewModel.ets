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
  LogCollectorState,
  LogDetailState,
  LogFilterState,
  LogListState,
  LogManageMode,
  LogManageState,
  LogPaginationState,
  LogSummaryState
} from '../../models/LogManageModels'
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
} from '../../services/log-manage/common/LogManagePorts'
import { LogCollectorService } from '../../services/log-manage/collector/LogCollectorService'
import { LogExportService } from '../../services/log-manage/export/LogExportService'
import { LogRepository } from '../../services/log-manage/repository/LogRepository'
import { LogUtils } from '../../utils/LogUtils'
import { LogStorageSettingsViewModel } from './LogStorageSettingsViewModel'

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

@Observed
export class LogManageViewModel {
  state: LogManageState = new LogManageState()
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
    this.setLoading(true)
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
      this.setLoading(false)
    }
  }

  activate(): void {
    this.updatePageState(true, this.state.autoRefreshEnabled)
  }

  deactivate(): void {
    this.updatePageState(false, this.state.autoRefreshEnabled)
  }

  destroy(): void {
    this.unregisterStorageListener()
    this.initialized = false
    this.updatePageState(false, false)
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
      let nextState = this.cloneState()
      nextState.mode = 'settings'
      nextState.active = false
      nextState.autoRefreshEnabled = false
      this.setState(nextState)
      return
    }

    let nextState = this.cloneState()
    nextState.mode = 'list'
    nextState.active = true
    nextState.autoRefreshEnabled = true
    this.setState(nextState)
    await this.refreshAll()
  }

  async setEventTypeIndex(index: number): Promise<void> {
    let nextState = this.cloneState()
    nextState.filter.eventTypeIndex = this.normalizeFilterIndex(index, LOG_EVENT_TYPE_OPTIONS.length + 1)
    this.applyResetToFirstPage(nextState)
    this.setState(nextState)
    await this.refreshAll()
  }

  async setResultIndex(index: number): Promise<void> {
    let nextState = this.cloneState()
    nextState.filter.resultIndex = this.normalizeFilterIndex(index, 4)
    this.applyResetToFirstPage(nextState)
    this.setState(nextState)
    await this.refreshAll()
  }

  async setKeyword(keyword: string): Promise<void> {
    let nextState = this.cloneState()
    nextState.filter.keyword = keyword
    this.applyResetToFirstPage(nextState)
    this.setState(nextState)
    await this.refreshAll()
  }

  setPageSizeIndex(index: number): void {
    let nextState = this.cloneState()
    nextState.pagination.pageSizeIndex = this.normalizePageSizeIndex(index)
    this.applyResetToFirstPage(nextState)
    this.setState(nextState)
    this.rebuildStateFromSnapshot()
  }

  setPageInputText(text: string): void {
    let nextState = this.cloneState()
    nextState.pagination.pageInputText = text.replace(/[^0-9]/g, '')
    this.setState(nextState)
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
    let nextState = this.cloneState()
    nextState.detail.visible = true
    nextState.detail.entryId = entryId
    this.setState(nextState)
  }

  closeDetail(): void {
    if (!this.state.detail.visible && this.state.detail.entryId.length === 0) {
      return
    }
    let nextState = this.cloneState()
    nextState.detail.visible = false
    nextState.detail.entryId = ''
    this.setState(nextState)
  }

  getCurrentDetailEntry(): LogEntry | null {
    if (this.state.detail.entryId.length === 0) {
      return null
    }
    for (let entry of this.state.list.allEntries) {
      if (entry.id === this.state.detail.entryId) {
        return entry
      }
    }
    return null
  }

  getPageSizeOptions(): number[] {
    return PAGE_SIZE_OPTIONS.slice()
  }

  getCurrentPageSize(): number {
    return PAGE_SIZE_OPTIONS[this.state.pagination.pageSizeIndex] ?? PAGE_SIZE_OPTIONS[0]
  }

  hasActiveFilters(): boolean {
    return this.state.filter.eventTypeIndex > 0 ||
      this.state.filter.resultIndex > 0 ||
      this.state.filter.keyword.trim().length > 0
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
    let pageSize = this.getCurrentPageSize()
    let totalPages = this.calcTotalPages(snapshot.entries.length, pageSize)
    let currentPage = this.normalizePage(`${this.state.pagination.currentPage}`, totalPages)
    let pageStart = (currentPage - 1) * pageSize
    let pagedEntries = snapshot.entries.slice(pageStart, pageStart + pageSize)
    let nextState = this.cloneState()
    nextState.collector = this.buildCollectorState()
    nextState.summary = this.buildSummary(snapshot, pagedEntries.length)
    nextState.list.allEntries = snapshot.entries.slice()
    nextState.list.pagedEntries = pagedEntries
    nextState.detail = this.syncDetailState(snapshot.entries, nextState.detail)
    nextState.filter.hintMessage = this.buildFilterHint(snapshot, nextState.collector)
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
    let keyword = this.state.filter.keyword.trim()
    if (keyword.length > 0) {
      query.keyword = keyword
      hasQuery = true
    }
    return hasQuery ? query : undefined
  }

  private buildSummary(snapshot: LogSnapshot, currentShownCount: number): LogSummaryState {
    let summary = new LogSummaryState()
    summary.totalCount = snapshot.totalCount
    summary.todayCount = snapshot.todayCount
    summary.blockedCount = snapshot.blockedCount
    summary.currentShownCount = currentShownCount
    return summary
  }

  private buildCollectorState(): LogCollectorState {
    let source = this.collector.getStatus()
    let state = new LogCollectorState()
    state.running = source.running
    state.auditReady = source.auditReady
    state.crashReady = source.crashReady
    state.pendingCount = source.pendingCount
    state.degraded = source.degraded
    state.degradedReason = source.degradedReason
    return state
  }

  private updatePageState(active: boolean, autoRefreshEnabled: boolean): void {
    let nextState = this.cloneState()
    nextState.active = active
    nextState.autoRefreshEnabled = autoRefreshEnabled
    this.setState(nextState)
  }

  private buildFilterHint(snapshot: LogSnapshot, collectorState: LogCollectorState): string {
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
    if (!collectorState.running || collectorState.degraded) {
      return EmptyStateStrings.CHECK_PERMISSIONS
    }
    return LogManageStrings.emptyDescription
  }

  private syncDetailState(entries: LogEntry[], detailState: LogDetailState): LogDetailState {
    if (detailState.entryId.length === 0) {
      return detailState
    }
    for (let entry of entries) {
      if (entry.id === detailState.entryId) {
        return detailState
      }
    }
    let nextDetail = new LogDetailState()
    nextDetail.visible = false
    nextDetail.entryId = ''
    return nextDetail
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

  private setState(nextState: LogManageState): void {
    this.state = nextState
  }

  private applyResetToFirstPage(state: LogManageState): void {
    state.pagination.currentPage = 1
    state.pagination.pageInputText = '1'
  }

  private cloneState(): LogManageState {
    let nextState = new LogManageState()
    nextState.loading = this.state.loading
    nextState.active = this.state.active
    nextState.autoRefreshEnabled = this.state.autoRefreshEnabled
    nextState.mode = this.state.mode
    nextState.collector = this.cloneCollectorState(this.state.collector)

    let summary = new LogSummaryState()
    summary.totalCount = this.state.summary.totalCount
    summary.todayCount = this.state.summary.todayCount
    summary.blockedCount = this.state.summary.blockedCount
    summary.currentShownCount = this.state.summary.currentShownCount
    nextState.summary = summary

    let filter = new LogFilterState()
    filter.eventTypeIndex = this.state.filter.eventTypeIndex
    filter.resultIndex = this.state.filter.resultIndex
    filter.keyword = this.state.filter.keyword
    filter.hintMessage = this.state.filter.hintMessage
    nextState.filter = filter

    let pagination = new LogPaginationState()
    pagination.currentPage = this.state.pagination.currentPage
    pagination.pageSizeIndex = this.state.pagination.pageSizeIndex
    pagination.pageInputText = this.state.pagination.pageInputText
    pagination.totalPages = this.state.pagination.totalPages
    nextState.pagination = pagination

    let list = new LogListState()
    list.allEntries = this.state.list.allEntries.slice()
    list.pagedEntries = this.state.list.pagedEntries.slice()
    nextState.list = list

    let detail = new LogDetailState()
    detail.visible = this.state.detail.visible
    detail.entryId = this.state.detail.entryId
    nextState.detail = detail
    return nextState
  }

  private cloneCollectorState(source: LogCollectorState): LogCollectorState {
    let state = new LogCollectorState()
    state.running = source.running
    state.auditReady = source.auditReady
    state.crashReady = source.crashReady
    state.pendingCount = source.pendingCount
    state.degraded = source.degraded
    state.degradedReason = source.degradedReason
    return state
  }
}

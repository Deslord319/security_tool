import { LogUtils } from './utils/LogUtils'
import { common } from '@kit.AbilityKit'
import { CommonStrings } from '../constants/CommonStrings'
import { LogManageStrings } from '../constants/modules/LogManageStrings'
import {
  DEFAULT_LOG_STORAGE_CONFIG,
  ExportActionResult,
  LogEntry,
  LogEventResult,
  LogEventType,
  LogFilter,
  LogStatistics,
  LOG_EVENT_TYPE_OPTIONS,
  LOG_MAX_ENTRIES_OPTIONS,
  LOG_RETENTION_OPTIONS,
  LogStorageConfig
} from '../models/DataModels'
import {
  LogDetailState,
  LogFilterState,
  LogListState,
  LogManageMode,
  LogManageState,
  LogPaginationState,
  LogStorageSettingsState,
  LogSummaryState
} from '../models/LogManageModels'
import { LogStorageService } from '../services/LogStorageService'

const TAG = 'LogManageViewModel'
const DOMAIN = 0x0012

export interface LogStorageSettingsSaveResult {
  success: boolean
  message: string
}

@Observed
export class LogManageViewModel {
  private static readonly PAGE_SIZE_OPTIONS: number[] = [20, 50, 100]
  private static readonly DEFAULT_MAX_ENTRIES_INDEX: number = LogManageViewModel.findOptionIndex(
    LOG_MAX_ENTRIES_OPTIONS,
    DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries,
    0
  )
  private static readonly DEFAULT_RETENTION_INDEX: number = LogManageViewModel.findOptionIndex(
    LOG_RETENTION_OPTIONS,
    DEFAULT_LOG_STORAGE_CONFIG.retentionDays,
    0
  )

  state: LogManageState = LogManageViewModel.buildDefaultState()

  private logStorageListenerId: number = -1
  private statisticsCache: LogStatistics = LogManageViewModel.buildEmptyStatistics()
  private active: boolean = false
  private autoRefreshEnabled: boolean = true

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.setLoading(true)
    try {
      await LogStorageService.init(context)
      this.loadStorageSettings(LogStorageService.getConfig())
      this.refreshAll()
      this.registerStorageListener()
    } catch (err) {
      LogUtils.error(TAG, `initialize failed: ${JSON.stringify(err)}`)
    } finally {
      this.setLoading(false)
    }
  }

  activate(): void {
    this.active = true
  }

  deactivate(): void {
    this.active = false
  }

  destroy(): void {
    if (this.logStorageListenerId > 0) {
      LogStorageService.removeChangeListener(this.logStorageListenerId)
      this.logStorageListenerId = -1
    }
    this.deactivate()
  }

  refreshAll(): void {
    // 1. 先更新 statisticsCache 和 summary（卡片数据优先刷新）
    this.statisticsCache = LogStorageService.getStatistics()
    this.rebuildSummary()
    
    // 2. 再更新列表数据
    this.reloadEntries()
    
    // 3. 同步详情状态
    this.syncDetailState()
  }

  refreshIfActive(): void {
    if (!this.active || !this.autoRefreshEnabled) {
      return
    }
    this.refreshAll()
  }

  setMode(mode: LogManageMode): void {
    if (this.state.mode === mode) {
      return
    }
    if (mode === 'settings') {
      this.loadStorageSettings(LogStorageService.getConfig())
    }
    this.autoRefreshEnabled = mode === 'list'
    this.updateState((state: LogManageState) => {
      state.mode = mode
    })
    if (mode === 'list') {
      this.refreshAll()
    }
  }

  setEventTypeIndex(index: number): void {
    let normalizedIndex = this.normalizeFilterIndex(index, this.getEventTypeOptionCount())
    this.updateState((state: LogManageState) => {
      state.filter.eventTypeIndex = normalizedIndex
      state.pagination.currentPage = 1
      state.pagination.pageInputText = '1'
    })
    this.refreshListState()
  }

  setResultIndex(index: number): void {
    let normalizedIndex = this.normalizeFilterIndex(index, this.getResultOptionCount())
    this.updateState((state: LogManageState) => {
      state.filter.resultIndex = normalizedIndex
      state.pagination.currentPage = 1
      state.pagination.pageInputText = '1'
    })
    this.refreshListState()
  }

  setKeyword(keyword: string): void {
    this.updateState((state: LogManageState) => {
      state.filter.keyword = keyword
      state.pagination.currentPage = 1
      state.pagination.pageInputText = '1'
    })
    this.refreshListState()
  }

  setPageSizeIndex(index: number): void {
    let normalizedIndex = this.normalizeFilterIndex(index, LogManageViewModel.PAGE_SIZE_OPTIONS.length)
    this.updateState((state: LogManageState) => {
      state.pagination.pageSizeIndex = normalizedIndex
      state.pagination.currentPage = 1
      state.pagination.pageInputText = '1'
    })
    this.rebuildPagination()
    this.rebuildPagedEntries()
  }

  setPageInputText(text: string): void {
    this.updateState((state: LogManageState) => {
      state.pagination.pageInputText = text.replace(/[^0-9]/g, '')
    })
  }

  goToPreviousPage(): void {
    if (this.state.pagination.currentPage <= 1) {
      return
    }
    this.updateState((state: LogManageState) => {
      state.pagination.currentPage = state.pagination.currentPage - 1
      state.pagination.pageInputText = `${state.pagination.currentPage}`
    })
    this.rebuildPagedEntries()
  }

  goToNextPage(): void {
    if (this.state.pagination.currentPage >= this.state.pagination.totalPages) {
      return
    }
    this.updateState((state: LogManageState) => {
      state.pagination.currentPage = state.pagination.currentPage + 1
      state.pagination.pageInputText = `${state.pagination.currentPage}`
    })
    this.rebuildPagedEntries()
  }

  jumpToInputPage(): void {
    let cleaned = this.state.pagination.pageInputText.trim()
    if (cleaned.length === 0) {
      this.syncPageInput()
      return
    }
    let targetPage = parseInt(cleaned, 10)
    if (!Number.isFinite(targetPage) || targetPage < 1) {
      targetPage = 1
    }
    if (targetPage > this.state.pagination.totalPages) {
      targetPage = this.state.pagination.totalPages
    }
    this.updateState((state: LogManageState) => {
      state.pagination.currentPage = targetPage
      state.pagination.pageInputText = `${targetPage}`
    })
    this.rebuildPagedEntries()
  }

  openDetail(entryId: string): void {
    this.updateState((state: LogManageState) => {
      state.detail.visible = true
      state.detail.entryId = entryId
    })
  }

  closeDetail(): void {
    if (!this.state.detail.visible && this.state.detail.entryId.length === 0) {
      return
    }
    this.updateState((state: LogManageState) => {
      state.detail.visible = false
      state.detail.entryId = ''
    })
  }

  async exportLogs(): Promise<ExportActionResult> {
    if (this.state.list.allEntries.length <= 0) {
      return {
        success: false,
        reason: LogManageStrings.noExportableLogs
      }
    }

    let result = await LogStorageService.exportToCsvFile({
      csvContent: LogStorageService.buildCsvContent(this.state.list.allEntries)
    })

    if (!result.success) {
      return {
        success: false,
        reason: LogManageStrings.buildExportFailedText(result.errorMessage ?? CommonStrings.messageRetryLater)
      }
    }

    return {
      success: true,
      fileName: result.fileName
    }
  }

  async clearLogs(): Promise<boolean> {
    let success = await LogStorageService.clearAll()
    if (!success) {
      return false
    }
    this.closeDetail()
    this.refreshAll()
    return true
  }

  setStorageMaxEntriesIndex(index: number): void {
    let normalizedIndex = LogManageViewModel.normalizeSettingsIndex(
      index,
      LOG_MAX_ENTRIES_OPTIONS.length,
      LogManageViewModel.DEFAULT_MAX_ENTRIES_INDEX
    )
    this.updateState((state: LogManageState) => {
      state.settings.maxEntriesIndex = normalizedIndex
      state.settings.hasChanges = LogManageViewModel.hasStorageSettingsChanges(state.settings)
    })
  }

  setStorageRetentionIndex(index: number): void {
    let normalizedIndex = LogManageViewModel.normalizeSettingsIndex(
      index,
      LOG_RETENTION_OPTIONS.length,
      LogManageViewModel.DEFAULT_RETENTION_INDEX
    )
    this.updateState((state: LogManageState) => {
      state.settings.retentionIndex = normalizedIndex
      state.settings.hasChanges = LogManageViewModel.hasStorageSettingsChanges(state.settings)
    })
  }

  async saveStorageSettings(): Promise<LogStorageSettingsSaveResult> {
    if (!this.state.settings.hasChanges) {
      return {
        success: false,
        message: CommonStrings.messageNoChanges
      }
    }

    let success = await LogStorageService.updateConfig(this.buildStorageConfig())
    if (!success) {
      return {
        success: false,
        message: LogManageStrings.saveSettingsFailed
      }
    }

    this.loadStorageSettings(LogStorageService.getConfig())
    this.refreshAll()
    return {
      success: true,
      message: LogManageStrings.saveSettingsSuccess
    }
  }

  getCurrentPageSize(): number {
    let index = this.state.pagination.pageSizeIndex
    if (index < 0 || index >= LogManageViewModel.PAGE_SIZE_OPTIONS.length) {
      return LogManageViewModel.PAGE_SIZE_OPTIONS[0]
    }
    return LogManageViewModel.PAGE_SIZE_OPTIONS[index]
  }

  getCurrentRangeText(): string {
    if (this.state.list.allEntries.length <= 0 || this.state.list.pagedEntries.length <= 0) {
      return '0-0'
    }
    let pageSize = this.getCurrentPageSize()
    let start = (this.state.pagination.currentPage - 1) * pageSize + 1
    let end = start + this.state.list.pagedEntries.length - 1
    return `${start}-${end}`
  }

  private registerStorageListener(): void {
    if (this.logStorageListenerId > 0) {
      return
    }
    this.logStorageListenerId = LogStorageService.addChangeListener(() => {
      this.refreshIfActive()
    })
  }

  private reloadEntries(): void {
    let filter = this.buildFilter()
    let allEntries = LogStorageService.queryEntries(filter)
    this.updateState((state: LogManageState) => {
      // 替换整个 list 对象以确保触发响应式更新
      state.list = new LogListState()
      state.list.allEntries = allEntries
    })
    this.rebuildPagination()
    this.rebuildPagedEntries()
    this.rebuildFilterHint()
  }

  private refreshListState(): void {
    this.reloadEntries()
    this.syncDetailState()
  }

  private buildFilter(): LogFilter | undefined {
    let filter: LogFilter = {}
    let hasFilter = false

    if (this.state.filter.eventTypeIndex > 0) {
      filter.eventTypes = [LOG_EVENT_TYPE_OPTIONS[this.state.filter.eventTypeIndex - 1].value]
      hasFilter = true
    }

    if (this.state.filter.resultIndex > 0) {
      filter.results = [this.mapResultIndexToValue(this.state.filter.resultIndex)]
      hasFilter = true
    }

    let keyword = this.state.filter.keyword.trim()
    if (keyword.length > 0) {
      filter.keyword = keyword
      hasFilter = true
    }

    return hasFilter ? filter : undefined
  }

  private rebuildSummary(): void {
    let nextSummary: LogSummaryState = {
      totalCount: this.statisticsCache.totalCount,
      todayCount: this.statisticsCache.todayCount,
      blockedCount: this.statisticsCache.blockedCount
    }
    this.updateState((state: LogManageState) => {
      state.summary = nextSummary
    })
  }

  private rebuildPagination(): void {
    let totalPages = this.calculateTotalPages(this.state.list.allEntries.length, this.getCurrentPageSize())
    let currentPage = this.state.pagination.currentPage
    if (currentPage < 1) {
      currentPage = 1
    }
    if (currentPage > totalPages) {
      currentPage = totalPages
    }
    this.updateState((state: LogManageState) => {
      state.pagination.currentPage = currentPage
      state.pagination.totalPages = totalPages
      state.pagination.pageInputText = `${currentPage}`
    })
  }

  private rebuildPagedEntries(): void {
    let pageSize = this.getCurrentPageSize()
    let start = (this.state.pagination.currentPage - 1) * pageSize
    let pagedEntries = this.state.list.allEntries.slice(start, start + pageSize)
    this.updateState((state: LogManageState) => {
      // 替换整个 list 对象以确保触发响应式更新
      state.list = new LogListState()
      state.list.allEntries = [...this.state.list.allEntries]
      state.list.pagedEntries = pagedEntries
    })
  }

  private rebuildFilterHint(): void {
    let hintMessage = ''
    if (this.state.filter.eventTypeIndex > 0) {
      let selectedType = LOG_EVENT_TYPE_OPTIONS[this.state.filter.eventTypeIndex - 1].value
      if (selectedType === LogEventType.FILE) {
        hintMessage = this.state.list.allEntries.length > 0 ? LogManageStrings.fileFilterHint : LogManageStrings.fileFilterEmptyHint
      } else {
        let totalByType = this.statisticsCache.byType.get(selectedType) || 0
        if (totalByType > 0 && this.state.list.allEntries.length === 0) {
          hintMessage = LogManageStrings.emptyDescription
        }
      }
    }
    this.updateState((state: LogManageState) => {
      state.filter.hintMessage = hintMessage
    })
  }

  private syncDetailState(): void {
    if (!this.state.detail.visible || this.state.detail.entryId.length === 0) {
      return
    }
    let hasEntry = this.state.list.allEntries.some((entry: LogEntry) => entry.id === this.state.detail.entryId)
    if (!hasEntry) {
      this.updateState((state: LogManageState) => {
        state.detail.visible = false
        state.detail.entryId = ''
      })
    }
  }

  private loadStorageSettings(config: LogStorageConfig): void {
    let maxEntriesIndex = LogManageViewModel.findOptionIndex(
      LOG_MAX_ENTRIES_OPTIONS,
      config.maxLocalEntries,
      LogManageViewModel.DEFAULT_MAX_ENTRIES_INDEX
    )
    let retentionIndex = LogManageViewModel.findOptionIndex(
      LOG_RETENTION_OPTIONS,
      config.retentionDays,
      LogManageViewModel.DEFAULT_RETENTION_INDEX
    )
    this.updateState((state: LogManageState) => {
      state.settings = {
        maxEntriesIndex,
        retentionIndex,
        initialMaxEntriesIndex: maxEntriesIndex,
        initialRetentionIndex: retentionIndex,
        hasChanges: false
      }
    })
  }

  private buildStorageConfig(): LogStorageConfig {
    return {
      maxLocalEntries: LOG_MAX_ENTRIES_OPTIONS[this.state.settings.maxEntriesIndex],
      retentionDays: LOG_RETENTION_OPTIONS[this.state.settings.retentionIndex]
    }
  }

  private syncPageInput(): void {
    this.updateState((state: LogManageState) => {
      state.pagination.pageInputText = `${state.pagination.currentPage}`
    })
  }

  private setLoading(loading: boolean): void {
    this.updateState((state: LogManageState) => {
      state.loading = loading
    })
  }

  private calculateTotalPages(totalCount: number, pageSize: number): number {
    if (totalCount <= 0) {
      return 1
    }
    return Math.max(1, Math.ceil(totalCount / pageSize))
  }

  private getEventTypeOptionCount(): number {
    return LOG_EVENT_TYPE_OPTIONS.length + 1
  }

  private getResultOptionCount(): number {
    return 4
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

  private updateState(editor: (state: LogManageState) => void): void {
    let nextState = LogManageViewModel.cloneState(this.state)
    editor(nextState)
    this.state = nextState
  }

  private static buildDefaultState(): LogManageState {
    return {
      loading: false,
      mode: 'list',
      summary: new LogSummaryState(),
      filter: new LogFilterState(),
      pagination: new LogPaginationState(),
      list: new LogListState(),
      detail: new LogDetailState(),
      settings: new LogStorageSettingsState()
    }
  }

  private static buildEmptyStatistics(): LogStatistics {
    return {
      totalCount: 0,
      todayCount: 0,
      blockedCount: 0,
      byType: new Map<LogEventType, number>()
    }
  }

  private static cloneState(state: LogManageState): LogManageState {
    let nextState = new LogManageState()
    nextState.loading = state.loading
    nextState.mode = state.mode
    nextState.summary.totalCount = state.summary.totalCount
    nextState.summary.todayCount = state.summary.todayCount
    nextState.summary.blockedCount = state.summary.blockedCount
    nextState.filter.eventTypeIndex = state.filter.eventTypeIndex
    nextState.filter.resultIndex = state.filter.resultIndex
    nextState.filter.keyword = state.filter.keyword
    nextState.filter.hintMessage = state.filter.hintMessage
    nextState.pagination.currentPage = state.pagination.currentPage
    nextState.pagination.pageSizeIndex = state.pagination.pageSizeIndex
    nextState.pagination.pageInputText = state.pagination.pageInputText
    nextState.pagination.totalPages = state.pagination.totalPages
    nextState.list.allEntries = [...state.list.allEntries]
    nextState.list.pagedEntries = [...state.list.pagedEntries]
    nextState.detail.visible = state.detail.visible
    nextState.detail.entryId = state.detail.entryId
    nextState.settings.maxEntriesIndex = state.settings.maxEntriesIndex
    nextState.settings.retentionIndex = state.settings.retentionIndex
    nextState.settings.initialMaxEntriesIndex = state.settings.initialMaxEntriesIndex
    nextState.settings.initialRetentionIndex = state.settings.initialRetentionIndex
    nextState.settings.hasChanges = state.settings.hasChanges
    return nextState
  }

  private static findOptionIndex(options: number[], value: number, fallbackIndex: number): number {
    let index = options.indexOf(value)
    return LogManageViewModel.normalizeSettingsIndex(index, options.length, fallbackIndex)
  }

  private static normalizeSettingsIndex(index: number, optionCount: number, fallbackIndex: number): number {
    if (index >= 0 && index < optionCount) {
      return index
    }
    return fallbackIndex
  }

  private static hasStorageSettingsChanges(state: LogStorageSettingsState): boolean {
    return state.maxEntriesIndex !== state.initialMaxEntriesIndex ||
      state.retentionIndex !== state.initialRetentionIndex
  }
}

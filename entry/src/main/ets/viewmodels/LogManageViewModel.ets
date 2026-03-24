import { common } from '@kit.AbilityKit'
import {
  LogEntry,
  LogFilter,
  LogStatistics,
  LogEventType,
  LogEventResult
} from '../models/DataModels'
import { LogDataService } from '../services/LogDataService'
import { LogExportService } from '../services/LogExportService'
import { LogConfigService } from '../services/LogConfigService'

export class LogManageViewModel {
  logEntries: LogEntry[] = []
  filteredEntries: LogEntry[] = []
  statistics: LogStatistics | null = null
  
  filterEventType: number = -1
  filterResult: number = -1
  filterKeyword: string = ''
  
  currentPage: number = 1
  pageSize: number = 20
  totalEntries: number = 0
  
  isLoading: boolean = false
  isExporting: boolean = false
  errorMessage: string | null = null

  private listenerId: number = -1

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.isLoading = true
    try {
      const [dataOk, configOk] = await Promise.all([
        LogDataService.init(context),
        LogConfigService.init(context)
      ])
      
      if (!dataOk || !configOk) {
        this.errorMessage = '服务初始化失败'
        return
      }
      
      LogExportService.init(context)
      await this.refresh()
      
      this.listenerId = LogDataService.addChangeListener((event) => {
        this.handleDataChange(event)
      })
    } catch (err) {
      this.errorMessage = `初始化失败：${JSON.stringify(err)}`
    } finally {
      this.isLoading = false
    }
  }

  destroy(): void {
    if (this.listenerId > 0) {
      LogDataService.removeChangeListener(this.listenerId)
      this.listenerId = -1
    }
  }
  
  async refresh(): Promise<void> {
    this.isLoading = true
    try {
      this.logEntries = LogDataService.queryEntries()
      this.statistics = LogDataService.getStatistics()
      this.totalEntries = this.logEntries.length
      this.applyFilter()
    } catch (err) {
      this.errorMessage = `刷新失败：${JSON.stringify(err)}`
    } finally {
      this.isLoading = false
    }
  }
  
  private applyFilter(): void {
    const filter = this.buildFilter()
    this.filteredEntries = LogDataService.queryEntries(filter)
    this.totalEntries = this.filteredEntries.length
    this.currentPage = 1
  }
  
  private buildFilter(): LogFilter | undefined {
    const hasFilter = 
      this.filterEventType >= 0 || 
      this.filterResult >= 0 || 
      this.filterKeyword.length > 0
    
    if (!hasFilter) {
      return undefined
    }
    
    const filter: LogFilter = {}
    
    if (this.filterEventType >= 0) {
      filter.eventTypes = [this.filterEventType as LogEventType]
    }
    
    if (this.filterResult >= 0) {
      filter.results = [this.filterResult as LogEventResult]
    }
    
    if (this.filterKeyword.length > 0) {
      filter.keyword = this.filterKeyword
    }
    
    return filter
  }
  
  async exportToCSV(): Promise<boolean> {
    if (this.logEntries.length === 0) {
      this.errorMessage = '没有可导出的日志'
      return false
    }
    
    this.isExporting = true
    try {
      const result = await LogExportService.exportToCSV(this.logEntries)
      
      if (!result.success) {
        this.errorMessage = result.errorMessage || '导出失败'
        return false
      }
      
      return true
    } catch (err) {
      this.errorMessage = `导出异常：${JSON.stringify(err)}`
      return false
    } finally {
      this.isExporting = false
    }
  }
  
  async clearAll(): Promise<boolean> {
    try {
      const success = await LogDataService.clearAll()
      if (success) {
        await this.refresh()
      }
      return success
    } catch (err) {
      this.errorMessage = `清空失败：${JSON.stringify(err)}`
      return false
    }
  }
  
  updateFilter(options: {
    eventType?: number
    result?: number
    keyword?: string
  }): void {
    if (options.eventType !== undefined) {
      this.filterEventType = options.eventType
    }
    if (options.result !== undefined) {
      this.filterResult = options.result
    }
    if (options.keyword !== undefined) {
      this.filterKeyword = options.keyword
    }
    this.applyFilter()
  }
  
  updatePagination(page: number, pageSize: number): void {
    this.currentPage = page
    this.pageSize = pageSize
  }
  
  private handleDataChange(event: { totalCount: number; addedCount: number }): void {
    this.totalEntries = event.totalCount
    void this.refresh()
  }
  
  get pagedEntries(): LogEntry[] {
    const start = (this.currentPage - 1) * this.pageSize
    const end = start + this.pageSize
    return this.filteredEntries.slice(start, end)
  }
  
  get totalPages(): number {
    if (this.filteredEntries.length === 0) {
      return 1
    }
    return Math.ceil(this.filteredEntries.length / this.pageSize)
  }
  
  get currentRangeText(): string {
    if (this.filteredEntries.length === 0) {
      return '0-0'
    }
    const start = (this.currentPage - 1) * this.pageSize + 1
    const end = Math.min(this.currentPage * this.pageSize, this.filteredEntries.length)
    return `${start}-${end}`
  }
}

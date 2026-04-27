import { LogEntry } from './DataModels'
import { CollectorStatus } from '../services/log-manage/common/LogManagePorts'

export type LogManageMode = 'list' | 'settings'
export const LOG_PAGE_SIZE_OPTIONS: number[] = [20, 50, 100]

@ObservedV2
export class LogCollectorState implements CollectorStatus {
  @Trace running: boolean = false
  @Trace auditReady: boolean = false
  @Trace crashReady: boolean = false
  @Trace pendingCount: number = 0
  @Trace degraded: boolean = false
  @Trace degradedReason?: 'audit_failed' | 'crash_failed' | 'partial'
}

@ObservedV2
export class LogSummaryState {
  @Trace totalCount: number = 0
  @Trace filteredCount: number = 0
  @Trace todayCount: number = 0
  @Trace blockedCount: number = 0
  @Trace currentShownCount: number = 0
}

@ObservedV2
export class LogFilterState {
  @Trace eventTypeIndex: number = 0
  @Trace resultIndex: number = 0
  @Trace keyword: string = ''
}

@ObservedV2
export class LogPaginationState {
  @Trace currentPage: number = 1
  @Trace pageSizeIndex: number = 0
  @Trace pageInputText: string = '1'
  @Trace totalPages: number = 1
}

@ObservedV2
export class LogListState {
  @Trace pagedEntries: LogEntry[] = []
}

@ObservedV2
export class LogDetailState {
  @Trace visible: boolean = false
  @Trace entryId: string = ''
}

@ObservedV2
export class LogManageState {
  @Trace initialized: boolean = false
  @Trace loading: boolean = false
  @Trace active: boolean = false
  @Trace autoRefreshEnabled: boolean = true
  @Trace mode: LogManageMode = 'list'
  @Trace summary: LogSummaryState = new LogSummaryState()
  @Trace collector: LogCollectorState = new LogCollectorState()
  @Trace filter: LogFilterState = new LogFilterState()
  @Trace pagination: LogPaginationState = new LogPaginationState()
  @Trace list: LogListState = new LogListState()
  @Trace detail: LogDetailState = new LogDetailState()
}

@ObservedV2
export class LogStorageSettingsState {
  @Trace maxLocalEntries: number = 0
  @Trace retentionDays: number = 0
  @Trace dirty: boolean = false
  @Trace saving: boolean = false
}

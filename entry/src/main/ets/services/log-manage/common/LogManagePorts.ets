import { common } from '@kit.AbilityKit'
import {
  LogEntry,
  LogEventResult,
  LogEventType,
  LogStorageConfig,
  LogSubscriptionConfig
} from '../../../models/DataModels'
import { StorageResult } from '../../../storage/StorageResult'

export interface ServiceResult<TCode extends string = string, TData = void> extends StorageResult<TCode, TData> {
}

export interface InitializeResult extends ServiceResult<'ok' | 'storage_init_failed' | 'config_init_failed' | 'collector_init_failed'> {
}

export interface ListViewInitializeResult extends ServiceResult<'ok' | 'storage_init_failed' | 'query_failed'> {
}

export interface MutationResult extends ServiceResult<'ok' | 'not_initialized' | 'save_failed' | 'clear_failed' | 'flush_failed'> {
}

export interface RefreshResult extends ServiceResult<'ok' | 'skipped_inactive' | 'query_failed'> {
}

export interface ClearLogsResult extends ServiceResult<'ok' | 'already_empty' | 'clear_failed'> {
}

export interface SaveSettingsResult extends ServiceResult<'ok' | 'no_changes' | 'invalid_retention' | 'invalid_max_entries' | 'save_failed'> {
}

export interface ExportLogsResult extends ServiceResult<'ok' | 'empty' | 'user_canceled' | 'io_failed' | 'context_missing'> {
  fileName?: string
  fullPath?: string
}

export interface LogQuery {
  eventTypes?: LogEventType[]
  results?: LogEventResult[]
  keyword?: string
}

export interface LogSnapshot {
  totalCount: number
  todayCount: number
  blockedCount: number
  filteredCount: number
  entries: LogEntry[]
}

export interface SourceStatus {
  subscribed: boolean
  errorCode?: number
}

export interface AuditSubscribeResult extends ServiceResult<'ok' | 'unsupported' | 'permission_denied' | 'partial'> {
  subscribedEventIds: number[]
  failedEventIds: number[]
}

export interface CrashSubscribeResult extends ServiceResult<'ok' | 'unsupported' | 'permission_denied'> {
}

export interface CollectorStatus {
  running: boolean
  auditReady: boolean
  crashReady: boolean
  pendingCount: number
  degraded: boolean
  degradedReason?: 'audit_failed' | 'crash_failed' | 'partial'
}

export interface CollectorStartResult extends ServiceResult<'ok' | 'partial' | 'no_source_available' | 'not_initialized'> {
  status: CollectorStatus
}

export interface CollectorStopResult extends ServiceResult<'ok' | 'not_running' | 'flush_failed'> {
  status: CollectorStatus
}

export interface LogCollectorStatusPort {
  getStatus(): CollectorStatus
}

export interface LogStoragePort {
  init(context: common.UIAbilityContext): Promise<InitializeResult>
  addEntries(entries: LogEntry[]): Promise<MutationResult>
  count(query?: LogQuery): Promise<number>
  list(query?: LogQuery, limit?: number, offset?: number): Promise<LogEntry[]>
  hasEntry(entryId: string, query?: LogQuery): Promise<boolean>
  snapshot(query?: LogQuery, limit?: number, offset?: number): Promise<LogSnapshot>
  clear(): Promise<ClearLogsResult>
  addChangeListener(listener: () => void): number
  removeChangeListener(id: number): void
}

export interface LogStorageMaintenancePort {
  reconcileStorageConfig(): Promise<MutationResult>
}

export interface LogExportServicePort {
  export(context: common.UIAbilityContext | null, query?: LogQuery, fileNamePrefix?: string): Promise<ExportLogsResult>
}

export interface LogAuditSourcePort {
  subscribe(onEntry: (entry: LogEntry) => void, eventTypes?: LogEventType[]): Promise<AuditSubscribeResult>
  unsubscribe(): boolean
  getStatus(): SourceStatus
}

export interface LogCrashSourcePort {
  subscribe(onEntry: (entry: LogEntry) => void): CrashSubscribeResult
  unsubscribe(): boolean
  getStatus(): SourceStatus
}

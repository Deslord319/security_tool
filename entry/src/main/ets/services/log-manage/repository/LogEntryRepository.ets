import relationalStore from '@ohos.data.relationalStore'
import { AppInfo } from '../../../constants/AppConstants'
import { LogUtils } from '../../../utils/LogUtils'
import {
  LogDetailTableRow,
  LogEntry,
  LogEventResult,
  LogEventType,
  LogStatistics,
  parseLogEventResult
} from '../../../models/DataModels'
import { RdbRepository, SqlBundle } from '../../../storage/rdb/RdbRepository'
import { LogQuery } from '../common/LogManagePorts'
import { pickNumber, pickString } from '../common/LogValuePicker'
import { LogEntryNormalizer } from '../mapper/LogEntryNormalizer'
import { RdbResultSetReader } from '../../../storage/rdb/RdbResultSetReader'
import { LooseRecord } from '../../../types/LooseValueTypes'

const TAG = 'LogEntryRepository'
const TABLE_NAME = 'log_entries'

const CREATE_TABLE_SQL = `
CREATE TABLE IF NOT EXISTS log_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id TEXT UNIQUE,
  timestamp INTEGER NOT NULL,
  event_type TEXT NOT NULL,
  result TEXT NOT NULL,
  source TEXT NOT NULL,
  detail TEXT NOT NULL,
  process_name TEXT,
  file_path TEXT,
  extra_json TEXT
)`

const CREATE_INDEX_TIMESTAMP_SQL = `
CREATE INDEX IF NOT EXISTS idx_log_entries_timestamp
ON log_entries(timestamp DESC, id DESC)
`

const CREATE_INDEX_EVENT_TYPE_SQL = `
CREATE INDEX IF NOT EXISTS idx_log_entries_event_type
ON log_entries(event_type)
`

const CREATE_INDEX_RESULT_SQL = `
CREATE INDEX IF NOT EXISTS idx_log_entries_result
ON log_entries(result)
`

interface LogEntryExtraData {
  pid?: number
  uid?: number
  remoteAddr?: string
  sourceEventId?: number
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
  detailRows?: LogDetailTableRow[]
}

export function serializeLogEntryExtraData(entry: LogEntry): string | null {
  let extra: LogEntryExtraData = {}
  if (entry.pid !== undefined) {
    extra.pid = entry.pid
  }
  if (entry.uid !== undefined) {
    extra.uid = entry.uid
  }
  if (entry.remoteAddr !== undefined) {
    extra.remoteAddr = entry.remoteAddr
  }
  if (entry.sourceEventId !== undefined) {
    extra.sourceEventId = entry.sourceEventId
  }
  if (entry.rawEventName !== undefined) {
    extra.rawEventName = entry.rawEventName
  }
  if (entry.rawOutcome !== undefined) {
    extra.rawOutcome = entry.rawOutcome
  }
  if (entry.rawAction !== undefined) {
    extra.rawAction = entry.rawAction
  }
  let detailRows = LogEntryNormalizer.normalizeDetailRows(entry.detailRows)
  if (detailRows !== undefined) {
    extra.detailRows = detailRows
  }
  let keys = Object.keys(extra)
  return keys.length > 0 ? JSON.stringify(extra) : null
}

export function deserializeLogEntryExtraData(rawValue: string | undefined): LogEntryExtraData {
  if (!rawValue || rawValue.length === 0) {
    return {}
  }
  try {
    let parsed = JSON.parse(rawValue) as Object
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      return {}
    }
    let extra = parsed as LooseRecord
    return {
      pid: pickNumber([extra], ['pid']),
      uid: pickNumber([extra], ['uid']),
      remoteAddr: pickString([extra], ['remoteAddr']),
      sourceEventId: pickNumber([extra], ['sourceEventId']),
      rawEventName: pickString([extra], ['rawEventName']),
      rawOutcome: pickString([extra], ['rawOutcome']),
      rawAction: pickString([extra], ['rawAction']),
      detailRows: LogEntryNormalizer.normalizeDetailRows(extra.detailRows as LogDetailTableRow[] | undefined)
    }
  } catch (err) {
    LogUtils.warn(TAG, `parseExtraJson failed: ${JSON.stringify(err)}`)
    return {}
  }
}

class LogEntryRdbRepository extends RdbRepository<LogEntry, LogQuery> {
  constructor() {
    super({
      tag: TAG,
      dbName: AppInfo.DB_NAME,
      tableName: TABLE_NAME,
      createStatements: [
        CREATE_TABLE_SQL,
        CREATE_INDEX_TIMESTAMP_SQL,
        CREATE_INDEX_EVENT_TYPE_SQL,
        CREATE_INDEX_RESULT_SQL
      ]
    })
  }

  async upsertEntries(entries: LogEntry[]): Promise<boolean> {
    return this.replaceBatch(
      entries,
      `INSERT OR REPLACE INTO ${TABLE_NAME} (
        record_id, timestamp, event_type, result, source, detail,
        process_name, file_path, extra_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      (entry: LogEntry) => [
        entry.id,
        entry.timestamp,
        this.serializeEventType(entry.eventType),
        this.serializeResult(entry.result),
        this.resolveSource(entry),
        entry.detail,
        entry.processName ?? null,
        entry.filePath ?? null,
        this.buildExtraJson(entry)
      ],
      'upsertEntries'
    )
  }

  async listByQuery(query?: LogQuery, limit?: number, offset?: number): Promise<LogEntry[]> {
    return this.queryRows(
      this.buildSelectSqlForQuery(query, limit, offset),
      (reader: RdbResultSetReader) => this.mapResultSet(reader),
      'listByQuery'
    )
  }

  async countByQuery(query?: LogQuery): Promise<number> {
    return this.countByQueryBuilt(query, (nextQuery?: LogQuery) => this.buildCountSqlForQuery(nextQuery), 'countByQuery')
  }

  async hasEntry(entryId: string, query?: LogQuery): Promise<boolean> {
    let where = this.buildWhereClause(query)
    let sql = `SELECT COUNT(1) AS count FROM ${TABLE_NAME} WHERE record_id = ?`
    let args: Array<relationalStore.ValueType> = [entryId]
    if (where.sql.length > 0) {
      sql += ` AND (${where.sql.substring(' WHERE '.length)})`
      args = args.concat(where.args)
    }
    return (await this.queryCount({ sql, args }, 'hasEntry')) > 0
  }

  async getStatistics(): Promise<LogStatistics> {
    let byType = new Map<LogEventType, number>()
    byType.set(LogEventType.CRASH, 0)
    byType.set(LogEventType.FILE, 0)
    byType.set(LogEventType.ACCOUNT, 0)
    byType.set(LogEventType.PERMISSION, 0)
    let todayStart = new Date()
    todayStart.setHours(0, 0, 0, 0)
    let todayTimestamp = todayStart.getTime()
    let totalCount = await this.countByQuery()
    let todayCount = await this.countByRawWhere('timestamp >= ?', [todayTimestamp])
    let blockedCount = await this.countByRawWhere('result = ?', [this.serializeResult(LogEventResult.BLOCKED)])
    let grouped = await this.groupCountByEventType()
    grouped.forEach((count: number, type: LogEventType) => {
      byType.set(type, count)
    })
    return {
      totalCount,
      todayCount,
      blockedCount,
      byType
    }
  }

  async deleteExpired(cutoffTimestamp: number): Promise<boolean> {
    return this.deleteExpiredByColumn('timestamp', cutoffTimestamp)
  }

  async trimToMaxEntries(maxEntries: number): Promise<boolean> {
    return this.trimToMaxEntriesByOrder('timestamp DESC, id DESC', maxEntries)
  }

  async clearAll(): Promise<boolean> {
    return this.clearAllRows()
  }

  private async groupCountByEventType(): Promise<Map<LogEventType, number>> {
    let result = new Map<LogEventType, number>()
    let entries = await this.queryGroupCounts('event_type', { sql: '', args: [] }, 'groupCountByEventType')
    entries.forEach((count: number, rawType: string) => {
      result.set(this.parseEventType(rawType), count)
    })
    return result
  }

  private mapResultSet(reader: RdbResultSetReader): LogEntry[] {
    let entries: LogEntry[] = []
    if (!reader.moveToFirst()) {
      return entries
    }
    let recordIdIndex = reader.getColumnIndex('record_id')
    let timestampIndex = reader.getColumnIndex('timestamp')
    let eventTypeIndex = reader.getColumnIndex('event_type')
    let resultIndex = reader.getColumnIndex('result')
    let detailIndex = reader.getColumnIndex('detail')
    let processNameIndex = reader.getColumnIndex('process_name')
    let filePathIndex = reader.getColumnIndex('file_path')
    let extraJsonIndex = reader.getColumnIndex('extra_json')
    do {
      let extra = this.parseExtraJson(reader.getOptionalString(extraJsonIndex))
      entries.push({
        id: reader.getRequiredString(recordIdIndex),
        timestamp: reader.getRequiredNumber(timestampIndex),
        eventType: this.parseEventType(reader.getRequiredString(eventTypeIndex)),
        result: this.parseResult(reader.getRequiredString(resultIndex)),
        detail: reader.getRequiredString(detailIndex),
        processName: reader.getOptionalString(processNameIndex),
        pid: pickNumber(extra, ['pid']),
        uid: pickNumber(extra, ['uid']),
        filePath: reader.getOptionalString(filePathIndex),
        remoteAddr: pickString(extra, ['remoteAddr']),
        sourceEventId: pickNumber(extra, ['sourceEventId']),
        rawEventName: pickString(extra, ['rawEventName']),
        rawOutcome: pickString(extra, ['rawOutcome']),
        rawAction: pickString(extra, ['rawAction']),
        detailRows: LogEntryNormalizer.normalizeDetailRows(extra.detailRows)
      })
    } while (reader.moveToNext())
    return entries
  }

  private buildSelectSqlForQuery(query?: LogQuery, limit?: number, offset?: number): SqlBundle {
    return this.buildSelectSql(
      'record_id, timestamp, event_type, result, detail, process_name, file_path, extra_json',
      this.buildWhereClause(query),
      'timestamp DESC, id DESC',
      limit,
      offset
    )
  }

  private buildCountSqlForQuery(query?: LogQuery): SqlBundle {
    return this.buildCountSql(this.buildWhereClause(query))
  }

  private buildWhereClause(query?: LogQuery): SqlBundle {
    let clauses: string[] = []
    let args: Array<relationalStore.ValueType> = []
    if (query?.eventTypes && query.eventTypes.length > 0) {
      let placeholders = query.eventTypes.map(() => '?').join(', ')
      clauses.push(`event_type IN (${placeholders})`)
      query.eventTypes.forEach((type: LogEventType) => args.push(this.serializeEventType(type)))
    }
    if (query?.results && query.results.length > 0) {
      let placeholders = query.results.map(() => '?').join(', ')
      clauses.push(`result IN (${placeholders})`)
      query.results.forEach((result: LogEventResult) => args.push(this.serializeResult(result)))
    }
    if (query?.keyword && query.keyword.trim().length > 0) {
      let pattern = `%${query.keyword.trim().toLowerCase()}%`
      clauses.push('(LOWER(detail) LIKE ? OR LOWER(COALESCE(process_name, \'\')) LIKE ? OR LOWER(COALESCE(file_path, \'\')) LIKE ?)')
      args.push(pattern, pattern, pattern)
    }
    return {
      sql: clauses.length > 0 ? ` WHERE ${clauses.join(' AND ')}` : '',
      args
    }
  }

  private serializeEventType(eventType: LogEventType): string {
    return eventType.toString()
  }

  private serializeResult(result: LogEventResult): string {
    return result.toString()
  }

  private resolveSource(entry: LogEntry): string {
    if (entry.sourceEventId !== undefined) {
      return 'audit_event'
    }
    if (entry.eventType === LogEventType.CRASH) {
      return 'crash_event'
    }
    return 'runtime_event'
  }

  private buildExtraJson(entry: LogEntry): string | null {
    return serializeLogEntryExtraData(entry)
  }

  private parseEventType(rawValue: string): LogEventType {
    let numeric = Number(rawValue)
    if (numeric === LogEventType.CRASH || numeric === LogEventType.FILE ||
      numeric === LogEventType.ACCOUNT || numeric === LogEventType.PERMISSION) {
      return numeric as LogEventType
    }
    return LogEventType.FILE
  }

  private parseResult(rawValue: string): LogEventResult {
    return parseLogEventResult(rawValue, LogEventResult.SUCCESS)
  }

  private parseExtraJson(rawValue: string | undefined): LogEntryExtraData {
    return deserializeLogEntryExtraData(rawValue)
  }
}

export const LogEntryRepository = new LogEntryRdbRepository()

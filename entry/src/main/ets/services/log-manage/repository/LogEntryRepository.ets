import relationalStore from '@ohos.data.relationalStore'
import { common } from '@kit.AbilityKit'
import { LogEntry, LogEventResult, LogEventType, LogStatistics } from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { RdbStoreProvider } from '../../../storage/rdb/RdbStoreProvider'
import { LogQuery } from '../common/LogManagePorts'

const TAG = 'LogEntryRepository'
const DB_NAME = 'security_tool.db'
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

interface SqlBundle {
  sql: string
  args: Array<relationalStore.ValueType>
}

interface LogEntryExtraData {
  pid?: number
  uid?: number
  remoteAddr?: string
  sourceEventId?: number
  sourceSubType?: number
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
}

export class LogEntryRepository {
  private static context: common.UIAbilityContext | null = null
  private static initialized: boolean = false

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    LogEntryRepository.context = context
    if (LogEntryRepository.initialized) {
      return true
    }
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return false
    }
    try {
      await store.executeSql(CREATE_TABLE_SQL)
      await LogEntryRepository.ensureColumn(store, "ALTER TABLE log_entries ADD COLUMN source TEXT NOT NULL DEFAULT 'unknown'")
      await LogEntryRepository.ensureColumn(store, 'ALTER TABLE log_entries ADD COLUMN extra_json TEXT')
      await store.executeSql(CREATE_INDEX_TIMESTAMP_SQL)
      await store.executeSql(CREATE_INDEX_EVENT_TYPE_SQL)
      await store.executeSql(CREATE_INDEX_RESULT_SQL)
      LogEntryRepository.initialized = true
      return true
    } catch (err) {
      LogUtils.error(TAG, `init failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async upsertEntries(entries: LogEntry[]): Promise<boolean> {
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return false
    }
    try {
      for (let entry of entries) {
        let args: Array<relationalStore.ValueType> = [
          entry.id,
          entry.timestamp,
          LogEntryRepository.serializeEventType(entry.eventType),
          LogEntryRepository.serializeResult(entry.result),
          LogEntryRepository.resolveSource(entry),
          entry.detail,
          entry.processName ?? null,
          entry.filePath ?? null,
          LogEntryRepository.buildExtraJson(entry)
        ]
        await store.executeSql(
          `INSERT OR REPLACE INTO ${TABLE_NAME} (
            record_id, timestamp, event_type, result, source, detail,
            process_name, file_path, extra_json
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          args
        )
      }
      return true
    } catch (err) {
      LogUtils.error(TAG, `upsertEntries failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async listLatest(limit: number): Promise<LogEntry[]> {
    return LogEntryRepository.listByQuery(undefined, limit, 0)
  }

  static async listByQuery(query?: LogQuery, limit?: number, offset?: number): Promise<LogEntry[]> {
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return []
    }
    let resultSet: relationalStore.ResultSet | null = null
    try {
      let built = LogEntryRepository.buildSelectSql(query, limit, offset)
      resultSet = await store.querySql(
        built.sql,
        built.args
      )
      return LogEntryRepository.mapResultSet(resultSet)
    } catch (err) {
      LogUtils.error(TAG, `listByQuery failed: ${JSON.stringify(err)}`)
      return []
    } finally {
      LogEntryRepository.closeResultSet(resultSet)
    }
  }

  static async countByQuery(query?: LogQuery): Promise<number> {
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return 0
    }
    let resultSet: relationalStore.ResultSet | null = null
    try {
      let built = LogEntryRepository.buildCountSql(query)
      resultSet = await store.querySql(built.sql, built.args)
      return LogEntryRepository.readFirstLong(resultSet, 'count')
    } catch (err) {
      LogUtils.error(TAG, `countByQuery failed: ${JSON.stringify(err)}`)
      return 0
    } finally {
      LogEntryRepository.closeResultSet(resultSet)
    }
  }

  static async getStatistics(): Promise<LogStatistics> {
    let byType = new Map<LogEventType, number>()
    byType.set(LogEventType.CRASH, 0)
    byType.set(LogEventType.FILE, 0)
    byType.set(LogEventType.ACCOUNT, 0)
    byType.set(LogEventType.PERMISSION, 0)
    let todayStart = new Date()
    todayStart.setHours(0, 0, 0, 0)
    let todayTimestamp = todayStart.getTime()
    let totalCount = await LogEntryRepository.countByQuery()
    let todayCount = await LogEntryRepository.countByRawWhere('timestamp >= ?', [todayTimestamp])
    let blockedCount = await LogEntryRepository.countByRawWhere('result = ?', [LogEntryRepository.serializeResult(LogEventResult.BLOCKED)])
    let grouped = await LogEntryRepository.groupCountByEventType()
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

  static async deleteExpired(cutoffTimestamp: number): Promise<boolean> {
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return false
    }
    try {
      await store.executeSql(`DELETE FROM ${TABLE_NAME} WHERE timestamp < ?`, [cutoffTimestamp])
      return true
    } catch (err) {
      LogUtils.error(TAG, `deleteExpired failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async trimToMaxEntries(maxEntries: number): Promise<boolean> {
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return false
    }
    try {
      await store.executeSql(
        `DELETE FROM ${TABLE_NAME}
         WHERE id NOT IN (
           SELECT id FROM ${TABLE_NAME}
           ORDER BY timestamp DESC, id DESC
           LIMIT ?
         )`,
        [maxEntries]
      )
      return true
    } catch (err) {
      LogUtils.error(TAG, `trimToMaxEntries failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async clearAll(): Promise<boolean> {
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return false
    }
    try {
      await store.executeSql(`DELETE FROM ${TABLE_NAME}`)
      return true
    } catch (err) {
      LogUtils.error(TAG, `clearAll failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static async getStore(): Promise<relationalStore.RdbStore | null> {
    if (!LogEntryRepository.context) {
      return null
    }
    return RdbStoreProvider.getStore(LogEntryRepository.context, DB_NAME)
  }

  private static async countByRawWhere(whereClause: string, args: Array<relationalStore.ValueType>): Promise<number> {
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return 0
    }
    let resultSet: relationalStore.ResultSet | null = null
    try {
      resultSet = await store.querySql(`SELECT COUNT(1) AS count FROM ${TABLE_NAME} WHERE ${whereClause}`, args)
      return LogEntryRepository.readFirstLong(resultSet, 'count')
    } catch (err) {
      LogUtils.error(TAG, `countByRawWhere failed: ${JSON.stringify(err)}`)
      return 0
    } finally {
      LogEntryRepository.closeResultSet(resultSet)
    }
  }

  private static async groupCountByEventType(): Promise<Map<LogEventType, number>> {
    let store = await LogEntryRepository.getStore()
    let result = new Map<LogEventType, number>()
    if (!store) {
      return result
    }
    let resultSet: relationalStore.ResultSet | null = null
    try {
      resultSet = await store.querySql(
        `SELECT event_type, COUNT(1) AS count
         FROM ${TABLE_NAME}
         GROUP BY event_type`
      )
      if (!LogEntryRepository.hasRows(resultSet)) {
        return result
      }
      let eventTypeIndex = LogEntryRepository.getColumnIndex(resultSet, 'event_type')
      let countIndex = LogEntryRepository.getColumnIndex(resultSet, 'count')
      do {
        let eventType = LogEntryRepository.parseEventType(LogEntryRepository.getRequiredString(resultSet, eventTypeIndex))
        let count = LogEntryRepository.getRequiredNumber(resultSet, countIndex)
        result.set(eventType, count)
      } while (LogEntryRepository.goToNextRow(resultSet))
      return result
    } catch (err) {
      LogUtils.error(TAG, `groupCountByEventType failed: ${JSON.stringify(err)}`)
      return result
    } finally {
      LogEntryRepository.closeResultSet(resultSet)
    }
  }

  private static mapResultSet(resultSet: relationalStore.ResultSet): LogEntry[] {
    let entries: LogEntry[] = []
    if (!LogEntryRepository.hasRows(resultSet)) {
      return entries
    }
    let recordIdIndex = LogEntryRepository.getColumnIndex(resultSet, 'record_id')
    let timestampIndex = LogEntryRepository.getColumnIndex(resultSet, 'timestamp')
    let eventTypeIndex = LogEntryRepository.getColumnIndex(resultSet, 'event_type')
    let resultIndex = LogEntryRepository.getColumnIndex(resultSet, 'result')
    let detailIndex = LogEntryRepository.getColumnIndex(resultSet, 'detail')
    let processNameIndex = LogEntryRepository.getColumnIndex(resultSet, 'process_name')
    let filePathIndex = LogEntryRepository.getColumnIndex(resultSet, 'file_path')
    let extraJsonIndex = LogEntryRepository.getColumnIndex(resultSet, 'extra_json')
    do {
      let extra = LogEntryRepository.parseExtraJson(LogEntryRepository.getOptionalString(resultSet, extraJsonIndex))
      entries.push({
        id: LogEntryRepository.getRequiredString(resultSet, recordIdIndex),
        timestamp: LogEntryRepository.getRequiredNumber(resultSet, timestampIndex),
        eventType: LogEntryRepository.parseEventType(LogEntryRepository.getRequiredString(resultSet, eventTypeIndex)),
        result: LogEntryRepository.parseResult(LogEntryRepository.getRequiredString(resultSet, resultIndex)),
        detail: LogEntryRepository.getRequiredString(resultSet, detailIndex),
        processName: LogEntryRepository.getOptionalString(resultSet, processNameIndex),
        pid: LogEntryRepository.pickNumber(extra, 'pid'),
        uid: LogEntryRepository.pickNumber(extra, 'uid'),
        filePath: LogEntryRepository.getOptionalString(resultSet, filePathIndex),
        remoteAddr: LogEntryRepository.pickString(extra, 'remoteAddr'),
        sourceEventId: LogEntryRepository.pickNumber(extra, 'sourceEventId'),
        sourceSubType: LogEntryRepository.pickNumber(extra, 'sourceSubType'),
        rawEventName: LogEntryRepository.pickString(extra, 'rawEventName'),
        rawOutcome: LogEntryRepository.pickString(extra, 'rawOutcome'),
        rawAction: LogEntryRepository.pickString(extra, 'rawAction')
      })
    } while (LogEntryRepository.goToNextRow(resultSet))
    return entries
  }

  private static buildSelectSql(
    query?: LogQuery,
    limit?: number,
    offset?: number
  ): SqlBundle {
    let built = LogEntryRepository.buildWhereClause(query)
    let sql =
      `SELECT record_id, timestamp, event_type, result, source, detail, process_name, file_path, extra_json
       FROM ${TABLE_NAME}${built.sql}
       ORDER BY timestamp DESC, id DESC`
    let args = built.args.slice()
    if (limit !== undefined) {
      sql += ' LIMIT ?'
      args.push(limit)
      if (offset !== undefined && offset > 0) {
        sql += ' OFFSET ?'
        args.push(offset)
      }
    }
    return { sql, args }
  }

  private static buildCountSql(query?: LogQuery): SqlBundle {
    let built = LogEntryRepository.buildWhereClause(query)
    return {
      sql: `SELECT COUNT(1) AS count FROM ${TABLE_NAME}${built.sql}`,
      args: built.args
    }
  }

  private static buildWhereClause(query?: LogQuery): SqlBundle {
    let clauses: string[] = []
    let args: Array<relationalStore.ValueType> = []
    if (query?.eventTypes && query.eventTypes.length > 0) {
      let placeholders = query.eventTypes.map(() => '?').join(', ')
      clauses.push(`event_type IN (${placeholders})`)
      query.eventTypes.forEach((type: LogEventType) => args.push(LogEntryRepository.serializeEventType(type)))
    }
    if (query?.results && query.results.length > 0) {
      let placeholders = query.results.map(() => '?').join(', ')
      clauses.push(`result IN (${placeholders})`)
      query.results.forEach((result: LogEventResult) => args.push(LogEntryRepository.serializeResult(result)))
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

  private static async ensureColumn(store: relationalStore.RdbStore, sql: string): Promise<void> {
    try {
      await store.executeSql(sql)
    } catch (_) {
    }
  }

  private static serializeEventType(eventType: LogEventType): string {
    return eventType.toString()
  }

  private static serializeResult(result: LogEventResult): string {
    return result.toString()
  }

  private static resolveSource(entry: LogEntry): string {
    if (entry.sourceEventId !== undefined || entry.sourceSubType !== undefined) {
      return 'audit_event'
    }
    if (entry.eventType === LogEventType.CRASH) {
      return 'crash_event'
    }
    return 'runtime_event'
  }

  private static buildExtraJson(entry: LogEntry): string | null {
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
    if (entry.sourceSubType !== undefined) {
      extra.sourceSubType = entry.sourceSubType
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
    let keys = Object.keys(extra)
    return keys.length > 0 ? JSON.stringify(extra) : null
  }

  private static parseEventType(rawValue: string): LogEventType {
    let numeric = Number(rawValue)
    if (numeric === LogEventType.CRASH || numeric === LogEventType.FILE ||
      numeric === LogEventType.ACCOUNT || numeric === LogEventType.PERMISSION) {
      return numeric as LogEventType
    }
    return LogEventType.FILE
  }

  private static parseResult(rawValue: string): LogEventResult {
    let numeric = Number(rawValue)
    if (numeric === LogEventResult.SUCCESS || numeric === LogEventResult.BLOCKED || numeric === LogEventResult.FAILED) {
      return numeric as LogEventResult
    }
    return LogEventResult.SUCCESS
  }

  private static parseExtraJson(rawValue: string | undefined): LogEntryExtraData {
    if (!rawValue || rawValue.length === 0) {
      return {}
    }
    try {
      let parsed = JSON.parse(rawValue) as Object
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as LogEntryExtraData : {}
    } catch (err) {
      LogUtils.warn(TAG, `parseExtraJson failed: ${JSON.stringify(err)}`)
      return {}
    }
  }

  private static pickString(source: LogEntryExtraData, key: string): string | undefined {
    switch (key) {
      case 'remoteAddr':
        return source.remoteAddr
      case 'rawEventName':
        return source.rawEventName
      case 'rawOutcome':
        return source.rawOutcome
      case 'rawAction':
        return source.rawAction
      default:
        return undefined
    }
  }

  private static pickNumber(source: LogEntryExtraData, key: string): number | undefined {
    let value: number | undefined
    switch (key) {
      case 'pid':
        value = source.pid
        break
      case 'uid':
        value = source.uid
        break
      case 'sourceEventId':
        value = source.sourceEventId
        break
      case 'sourceSubType':
        value = source.sourceSubType
        break
      default:
        value = undefined
        break
    }
    return value !== undefined && Number.isFinite(value) ? value : undefined
  }

  private static hasRows(resultSet: relationalStore.ResultSet): boolean {
    try {
      return resultSet.rowCount > 0 && resultSet.goToFirstRow()
    } catch (err) {
      LogUtils.error(TAG, `hasRows failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static goToNextRow(resultSet: relationalStore.ResultSet): boolean {
    try {
      return resultSet.goToNextRow()
    } catch (err) {
      LogUtils.error(TAG, `goToNextRow failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static getColumnIndex(resultSet: relationalStore.ResultSet, column: string): number {
    try {
      return resultSet.getColumnIndex(column)
    } catch (err) {
      LogUtils.error(TAG, `getColumnIndex failed: column=${column}, err=${JSON.stringify(err)}`)
      return -1
    }
  }

  private static getRequiredString(resultSet: relationalStore.ResultSet, columnIndex: number): string {
    if (columnIndex < 0) {
      return ''
    }
    try {
      return resultSet.getString(columnIndex)
    } catch (err) {
      LogUtils.error(TAG, `getRequiredString failed: index=${columnIndex}, err=${JSON.stringify(err)}`)
      return ''
    }
  }

  private static getOptionalString(resultSet: relationalStore.ResultSet, columnIndex: number): string | undefined {
    if (columnIndex < 0) {
      return undefined
    }
    try {
      return resultSet.isColumnNull(columnIndex) ? undefined : resultSet.getString(columnIndex)
    } catch (err) {
      LogUtils.error(TAG, `getOptionalString failed: index=${columnIndex}, err=${JSON.stringify(err)}`)
      return undefined
    }
  }

  private static getRequiredNumber(resultSet: relationalStore.ResultSet, columnIndex: number): number {
    if (columnIndex < 0) {
      return 0
    }
    try {
      return resultSet.getLong(columnIndex)
    } catch (err) {
      LogUtils.error(TAG, `getRequiredNumber failed: index=${columnIndex}, err=${JSON.stringify(err)}`)
      return 0
    }
  }

  private static closeResultSet(resultSet: relationalStore.ResultSet | null): void {
    if (!resultSet) {
      return
    }
    try {
      if (!resultSet.isClosed) {
        resultSet.close()
      }
    } catch (err) {
      LogUtils.warn(TAG, `closeResultSet failed: ${JSON.stringify(err)}`)
    }
  }

  private static readFirstLong(resultSet: relationalStore.ResultSet | null, column: string): number {
    if (!resultSet || !LogEntryRepository.hasRows(resultSet)) {
      return 0
    }
    let columnIndex = LogEntryRepository.getColumnIndex(resultSet, column)
    return LogEntryRepository.getRequiredNumber(resultSet, columnIndex)
  }
}

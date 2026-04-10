import relationalStore from '@ohos.data.relationalStore'
import { common } from '@kit.AbilityKit'
import { LogEntry, LogEventResult, LogEventType, LogStatistics } from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { RdbStoreProvider } from '../../../storage/rdb/RdbStoreProvider'
import { LogQuery } from '../common/LogManagePorts'
import { RdbResultSetReader } from '../../../storage/rdb/RdbResultSetReader'

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
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
}

type ChangeListener = () => void

export class LogEntryRepository {
  private static context: common.UIAbilityContext | null = null
  private static initialized: boolean = false
  private static initializedContextDir: string = ''
  private static initPromise: Promise<boolean> | null = null
  private static nextListenerId: number = 1
  private static listeners: Map<number, ChangeListener> = new Map()

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    LogEntryRepository.context = context
    let contextDir = context.filesDir || ''
    if (LogEntryRepository.initialized && LogEntryRepository.initializedContextDir === contextDir) {
      return true
    }
    if (LogEntryRepository.initPromise) {
      return LogEntryRepository.initPromise
    }
    LogEntryRepository.initPromise = LogEntryRepository.doInit(context, contextDir)
    let ready = await LogEntryRepository.initPromise
    LogEntryRepository.initPromise = null
    return ready
  }

  static isReady(): boolean {
    return LogEntryRepository.initialized
  }

  static addChangeListener(listener: ChangeListener): number {
    let id = LogEntryRepository.nextListenerId++
    LogEntryRepository.listeners.set(id, listener)
    return id
  }

  static removeChangeListener(listenerId: number): void {
    LogEntryRepository.listeners.delete(listenerId)
  }

  static notifyChanged(): void {
    LogEntryRepository.listeners.forEach((listener: ChangeListener) => {
      try {
        listener()
      } catch (err) {
        LogUtils.warn(TAG, `listener failed: ${JSON.stringify(err)}`)
      }
    })
  }

  private static async doInit(context: common.UIAbilityContext, contextDir: string): Promise<boolean> {
    LogEntryRepository.context = context
    let store = await LogEntryRepository.getStore()
    if (!store) {
      LogEntryRepository.initialized = false
      LogEntryRepository.initializedContextDir = ''
      return false
    }
    try {
      await store.executeSql(CREATE_TABLE_SQL)
      await LogEntryRepository.ensureColumn(
        store,
        "ALTER TABLE log_entries ADD COLUMN source TEXT NOT NULL DEFAULT 'unknown'",
        'source'
      )
      await LogEntryRepository.ensureColumn(store, 'ALTER TABLE log_entries ADD COLUMN extra_json TEXT', 'extra_json')
      await store.executeSql(CREATE_INDEX_TIMESTAMP_SQL)
      await store.executeSql(CREATE_INDEX_EVENT_TYPE_SQL)
      await store.executeSql(CREATE_INDEX_RESULT_SQL)
      LogEntryRepository.initialized = true
      LogEntryRepository.initializedContextDir = contextDir
      return true
    } catch (err) {
      LogEntryRepository.initialized = false
      LogEntryRepository.initializedContextDir = ''
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

  static async listByQuery(query?: LogQuery, limit?: number, offset?: number): Promise<LogEntry[]> {
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return []
    }
    let reader: RdbResultSetReader | null = null
    try {
      let built = LogEntryRepository.buildSelectSql(query, limit, offset)
      let resultSet = await store.querySql(
        built.sql,
        built.args
      )
      reader = new RdbResultSetReader(resultSet, TAG)
      return LogEntryRepository.mapResultSet(reader)
    } catch (err) {
      LogUtils.error(TAG, `listByQuery failed: ${JSON.stringify(err)}`)
      return []
    } finally {
      reader?.close()
    }
  }

  static async countByQuery(query?: LogQuery): Promise<number> {
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return 0
    }
    let reader: RdbResultSetReader | null = null
    try {
      let built = LogEntryRepository.buildCountSql(query)
      let resultSet = await store.querySql(built.sql, built.args)
      reader = new RdbResultSetReader(resultSet, TAG)
      return reader.readFirstLong('count')
    } catch (err) {
      LogUtils.error(TAG, `countByQuery failed: ${JSON.stringify(err)}`)
      return 0
    } finally {
      reader?.close()
    }
  }

  static async hasEntry(entryId: string, query?: LogQuery): Promise<boolean> {
    let store = await LogEntryRepository.getStore()
    if (!store) {
      return false
    }
    let reader: RdbResultSetReader | null = null
    try {
      let built = LogEntryRepository.buildWhereClause(query)
      let sql = `SELECT COUNT(1) AS count FROM ${TABLE_NAME} WHERE record_id = ?`
      let args: Array<relationalStore.ValueType> = [entryId]
      if (built.sql.length > 0) {
        sql += ` AND (${built.sql.substring(' WHERE '.length)})`
        args = args.concat(built.args)
      }
      let resultSet = await store.querySql(sql, args)
      reader = new RdbResultSetReader(resultSet, TAG)
      return reader.readFirstLong('count') > 0
    } catch (err) {
      LogUtils.error(TAG, `hasEntry failed: ${JSON.stringify(err)}`)
      return false
    } finally {
      reader?.close()
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
    let reader: RdbResultSetReader | null = null
    try {
      let resultSet = await store.querySql(`SELECT COUNT(1) AS count FROM ${TABLE_NAME} WHERE ${whereClause}`, args)
      reader = new RdbResultSetReader(resultSet, TAG)
      return reader.readFirstLong('count')
    } catch (err) {
      LogUtils.error(TAG, `countByRawWhere failed: ${JSON.stringify(err)}`)
      return 0
    } finally {
      reader?.close()
    }
  }

  private static async groupCountByEventType(): Promise<Map<LogEventType, number>> {
    let store = await LogEntryRepository.getStore()
    let result = new Map<LogEventType, number>()
    if (!store) {
      return result
    }
    let reader: RdbResultSetReader | null = null
    try {
      let resultSet = await store.querySql(
        `SELECT event_type, COUNT(1) AS count
         FROM ${TABLE_NAME}
         GROUP BY event_type`
      )
      reader = new RdbResultSetReader(resultSet, TAG)
      if (!reader.moveToFirst()) {
        return result
      }
      let eventTypeIndex = reader.getColumnIndex('event_type')
      let countIndex = reader.getColumnIndex('count')
      do {
        let eventType = LogEntryRepository.parseEventType(reader.getRequiredString(eventTypeIndex))
        let count = reader.getRequiredNumber(countIndex)
        result.set(eventType, count)
      } while (reader.moveToNext())
      return result
    } catch (err) {
      LogUtils.error(TAG, `groupCountByEventType failed: ${JSON.stringify(err)}`)
      return result
    } finally {
      reader?.close()
    }
  }

  private static mapResultSet(reader: RdbResultSetReader): LogEntry[] {
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
      let extra = LogEntryRepository.parseExtraJson(reader.getOptionalString(extraJsonIndex))
      entries.push({
        id: reader.getRequiredString(recordIdIndex),
        timestamp: reader.getRequiredNumber(timestampIndex),
        eventType: LogEntryRepository.parseEventType(reader.getRequiredString(eventTypeIndex)),
        result: LogEntryRepository.parseResult(reader.getRequiredString(resultIndex)),
        detail: reader.getRequiredString(detailIndex),
        processName: reader.getOptionalString(processNameIndex),
        pid: LogEntryRepository.pickNumber(extra, 'pid'),
        uid: LogEntryRepository.pickNumber(extra, 'uid'),
        filePath: reader.getOptionalString(filePathIndex),
        remoteAddr: LogEntryRepository.pickString(extra, 'remoteAddr'),
        sourceEventId: LogEntryRepository.pickNumber(extra, 'sourceEventId'),
        rawEventName: LogEntryRepository.pickString(extra, 'rawEventName'),
        rawOutcome: LogEntryRepository.pickString(extra, 'rawOutcome'),
        rawAction: LogEntryRepository.pickString(extra, 'rawAction')
      })
    } while (reader.moveToNext())
    return entries
  }

  private static buildSelectSql(
    query?: LogQuery,
    limit?: number,
    offset?: number
  ): SqlBundle {
    let built = LogEntryRepository.buildWhereClause(query)
    let sql =
      `SELECT record_id, timestamp, event_type, result, detail, process_name, file_path, extra_json
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

  private static async ensureColumn(
    store: relationalStore.RdbStore,
    sql: string,
    columnName: string
  ): Promise<void> {
    try {
      await store.executeSql(sql)
    } catch (err) {
      if (LogEntryRepository.isDuplicateColumnError(err, columnName)) {
        return
      }
      throw new Error(JSON.stringify(err))
    }
  }

  private static serializeEventType(eventType: LogEventType): string {
    return eventType.toString()
  }

  private static serializeResult(result: LogEventResult): string {
    return result.toString()
  }

  private static resolveSource(entry: LogEntry): string {
    if (entry.sourceEventId !== undefined) {
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
      default:
        value = undefined
        break
    }
    return value !== undefined && Number.isFinite(value) ? value : undefined
  }

  private static isDuplicateColumnError(err: Object, columnName: string): boolean {
    let text = JSON.stringify(err).toLowerCase()
    return text.includes('duplicate') && text.includes(columnName.toLowerCase())
  }
}

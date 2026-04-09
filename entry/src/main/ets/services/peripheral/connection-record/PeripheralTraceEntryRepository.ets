import relationalStore from '@ohos.data.relationalStore'
import { common } from '@kit.AbilityKit'
import {
  LogEventResult,
  PeripheralMatchedPolicyKind,
  PeripheralRecordAction,
  PeripheralRecordPolicyHit,
  PeripheralRecordSource,
  PeripheralTraceQuery,
  PeripheralTraceRecord,
  PeripheralType,
  UsbStoragePolicy
} from '../../../models/DataModels'
import { LogUtils } from '../../../utils/LogUtils'
import { RdbStoreProvider } from '../../../storage/rdb/RdbStoreProvider'

const TAG = 'PeripheralTraceEntryRepo'
const DB_NAME = 'security_tool.db'
const TABLE_NAME = 'peripheral_trace_entries'

const CREATE_TABLE_SQL = `
CREATE TABLE IF NOT EXISTS peripheral_trace_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_id TEXT UNIQUE,
  occur_at INTEGER NOT NULL,
  collect_at INTEGER NOT NULL,
  device_name TEXT NOT NULL,
  device_type TEXT NOT NULL,
  device_id TEXT NOT NULL,
  action TEXT NOT NULL,
  decision TEXT NOT NULL,
  result TEXT NOT NULL,
  source TEXT NOT NULL,
  summary TEXT NOT NULL,
  detail TEXT,
  process_name TEXT,
  raw_payload TEXT,
  extra_json TEXT
)`

const CREATE_INDEX_OCCUR_AT_SQL = `
CREATE INDEX IF NOT EXISTS idx_peripheral_trace_occur_at
ON peripheral_trace_entries(occur_at DESC, id DESC)
`

const CREATE_INDEX_DEVICE_ID_SQL = `
CREATE INDEX IF NOT EXISTS idx_peripheral_trace_device_id
ON peripheral_trace_entries(device_id)
`

const CREATE_INDEX_ACTION_SQL = `
CREATE INDEX IF NOT EXISTS idx_peripheral_trace_action
ON peripheral_trace_entries(action)
`

interface SqlBundle {
  sql: string
  args: Array<relationalStore.ValueType>
}

interface PeripheralTraceExtraData {
  correlationId?: string
  policyVersion?: string
  rawEventId?: number
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
  usbPolicy?: number
  effectivePolicyLabel?: string
  matchedPolicyKind?: string
}

export class PeripheralTraceEntryRepository {
  private static context: common.UIAbilityContext | null = null
  private static initialized: boolean = false

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    PeripheralTraceEntryRepository.context = context
    if (PeripheralTraceEntryRepository.initialized) {
      return true
    }
    let store = await PeripheralTraceEntryRepository.getStore()
    if (!store) {
      return false
    }
    try {
      await store.executeSql(CREATE_TABLE_SQL)
      await store.executeSql(CREATE_INDEX_OCCUR_AT_SQL)
      await store.executeSql(CREATE_INDEX_DEVICE_ID_SQL)
      await store.executeSql(CREATE_INDEX_ACTION_SQL)
      PeripheralTraceEntryRepository.initialized = true
      return true
    } catch (err) {
      LogUtils.error(TAG, `init failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async upsertBatch(records: PeripheralTraceRecord[]): Promise<boolean> {
    let store = await PeripheralTraceEntryRepository.getStore()
    if (!store) {
      return false
    }
    try {
      for (let record of records) {
        let args: Array<relationalStore.ValueType> = [
          record.recordId,
          record.occurAt,
          record.collectAt,
          record.deviceName,
          record.deviceType,
          record.deviceId,
          record.action,
          record.decision,
          PeripheralTraceEntryRepository.serializeResult(record.result),
          record.source,
          record.summary,
          record.detail ?? null,
          record.processName ?? null,
          record.rawPayload ?? null,
          PeripheralTraceEntryRepository.buildExtraJson(record)
        ]
        await store.executeSql(
          `INSERT OR REPLACE INTO ${TABLE_NAME} (
            record_id, occur_at, collect_at, device_name, device_type, device_id,
            action, decision, result, source, summary, detail, process_name, raw_payload, extra_json
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          args
        )
      }
      return true
    } catch (err) {
      LogUtils.error(TAG, `upsertBatch failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async listByQuery(query?: PeripheralTraceQuery, limit?: number, offset?: number): Promise<PeripheralTraceRecord[]> {
    let store = await PeripheralTraceEntryRepository.getStore()
    if (!store) {
      return []
    }
    let resultSet: relationalStore.ResultSet | null = null
    try {
      let built = PeripheralTraceEntryRepository.buildSelectSql(query, limit, offset)
      resultSet = await store.querySql(built.sql, built.args)
      return PeripheralTraceEntryRepository.mapResultSet(resultSet)
    } catch (err) {
      LogUtils.error(TAG, `listByQuery failed: ${JSON.stringify(err)}`)
      return []
    } finally {
      PeripheralTraceEntryRepository.closeResultSet(resultSet)
    }
  }

  static async countByQuery(query?: PeripheralTraceQuery): Promise<number> {
    let store = await PeripheralTraceEntryRepository.getStore()
    if (!store) {
      return 0
    }
    let resultSet: relationalStore.ResultSet | null = null
    try {
      let built = PeripheralTraceEntryRepository.buildCountSql(query)
      resultSet = await store.querySql(built.sql, built.args)
      return PeripheralTraceEntryRepository.readFirstLong(resultSet, 'count')
    } catch (err) {
      LogUtils.error(TAG, `countByQuery failed: ${JSON.stringify(err)}`)
      return 0
    } finally {
      PeripheralTraceEntryRepository.closeResultSet(resultSet)
    }
  }

  static async deleteExpired(cutoffTimestamp: number): Promise<boolean> {
    let store = await PeripheralTraceEntryRepository.getStore()
    if (!store) {
      return false
    }
    try {
      await store.executeSql(`DELETE FROM ${TABLE_NAME} WHERE occur_at < ?`, [cutoffTimestamp])
      return true
    } catch (err) {
      LogUtils.error(TAG, `deleteExpired failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static async trimToMaxEntries(maxEntries: number): Promise<boolean> {
    let store = await PeripheralTraceEntryRepository.getStore()
    if (!store) {
      return false
    }
    try {
      await store.executeSql(
        `DELETE FROM ${TABLE_NAME}
         WHERE id NOT IN (
           SELECT id FROM ${TABLE_NAME}
           ORDER BY occur_at DESC, id DESC
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
    let store = await PeripheralTraceEntryRepository.getStore()
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
    if (!PeripheralTraceEntryRepository.context) {
      return null
    }
    return RdbStoreProvider.getStore(PeripheralTraceEntryRepository.context, DB_NAME)
  }

  private static buildSelectSql(
    query?: PeripheralTraceQuery,
    limit?: number,
    offset?: number
  ): SqlBundle {
    let built = PeripheralTraceEntryRepository.buildWhereClause(query)
    let sql =
      `SELECT record_id, occur_at, collect_at, device_name, device_type, device_id,
              action, decision, result, source, summary, detail, process_name, raw_payload, extra_json
       FROM ${TABLE_NAME}${built.sql}
       ORDER BY occur_at DESC, id DESC`
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

  private static buildCountSql(query?: PeripheralTraceQuery): SqlBundle {
    let built = PeripheralTraceEntryRepository.buildWhereClause(query)
    return {
      sql: `SELECT COUNT(1) AS count FROM ${TABLE_NAME}${built.sql}`,
      args: built.args
    }
  }

  private static buildWhereClause(query?: PeripheralTraceQuery): SqlBundle {
    let clauses: string[] = []
    let args: Array<relationalStore.ValueType> = []
    if (!query) {
      return { sql: '', args }
    }
    if (query.startTime !== undefined && Number.isFinite(query.startTime)) {
      clauses.push('occur_at >= ?')
      args.push(Math.floor(query.startTime))
    }
    if (query.endTime !== undefined && Number.isFinite(query.endTime)) {
      clauses.push('occur_at <= ?')
      args.push(Math.floor(query.endTime))
    }
    if (query.deviceId && query.deviceId.trim().length > 0) {
      clauses.push('device_id = ?')
      args.push(PeripheralTraceEntryRepository.normalizeDeviceId(query.deviceId))
    }
    if (query.deviceTypes && query.deviceTypes.length > 0) {
      let placeholders = query.deviceTypes.map(() => '?').join(', ')
      clauses.push(`device_type IN (${placeholders})`)
      query.deviceTypes.forEach((deviceType: PeripheralType) => args.push(deviceType))
    }
    if (query.actions && query.actions.length > 0) {
      let placeholders = query.actions.map(() => '?').join(', ')
      clauses.push(`action IN (${placeholders})`)
      query.actions.forEach((action: PeripheralRecordAction) => args.push(action))
    }
    if (query.decisions && query.decisions.length > 0) {
      let placeholders = query.decisions.map(() => '?').join(', ')
      clauses.push(`decision IN (${placeholders})`)
      query.decisions.forEach((decision: PeripheralRecordPolicyHit) => args.push(decision))
    }
    if (query.results && query.results.length > 0) {
      let placeholders = query.results.map(() => '?').join(', ')
      clauses.push(`result IN (${placeholders})`)
      query.results.forEach((result: LogEventResult) => args.push(PeripheralTraceEntryRepository.serializeResult(result)))
    }
    if (query.sources && query.sources.length > 0) {
      let placeholders = query.sources.map(() => '?').join(', ')
      clauses.push(`source IN (${placeholders})`)
      query.sources.forEach((source: PeripheralRecordSource) => args.push(source))
    }
    if (query.keyword && query.keyword.trim().length > 0) {
      let pattern = `%${query.keyword.trim().toLowerCase()}%`
      clauses.push(
        '(LOWER(device_name) LIKE ? OR LOWER(device_id) LIKE ? OR LOWER(summary) LIKE ? OR LOWER(COALESCE(detail, \'\')) LIKE ? OR LOWER(COALESCE(process_name, \'\')) LIKE ?)'
      )
      args.push(pattern, pattern, pattern, pattern, pattern)
    }
    return {
      sql: clauses.length > 0 ? ` WHERE ${clauses.join(' AND ')}` : '',
      args
    }
  }

  private static serializeResult(result: LogEventResult): string {
    return result.toString()
  }

  private static buildExtraJson(record: PeripheralTraceRecord): string | null {
    let extra: PeripheralTraceExtraData = {}
    extra.correlationId = record.correlationId
    extra.policyVersion = record.policyVersion
    extra.rawEventId = record.rawEventId
    extra.rawEventName = record.rawEventName
    extra.rawOutcome = record.rawOutcome
    extra.rawAction = record.rawAction
    extra.usbPolicy = record.usbPolicy
    extra.effectivePolicyLabel = record.effectivePolicyLabel
    extra.matchedPolicyKind = record.matchedPolicyKind
    if (
      extra.correlationId === undefined &&
      extra.policyVersion === undefined &&
      extra.rawEventId === undefined &&
      extra.rawEventName === undefined &&
      extra.rawOutcome === undefined &&
      extra.rawAction === undefined &&
      extra.usbPolicy === undefined &&
      extra.effectivePolicyLabel === undefined &&
      extra.matchedPolicyKind === undefined
    ) {
      return null
    }
    return JSON.stringify(extra)
  }

  private static mapResultSet(resultSet: relationalStore.ResultSet): PeripheralTraceRecord[] {
    let records: PeripheralTraceRecord[] = []
    if (!PeripheralTraceEntryRepository.hasRows(resultSet)) {
      return records
    }
    let recordIdIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'record_id')
    let occurAtIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'occur_at')
    let collectAtIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'collect_at')
    let deviceNameIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'device_name')
    let deviceTypeIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'device_type')
    let deviceIdIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'device_id')
    let actionIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'action')
    let decisionIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'decision')
    let resultIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'result')
    let sourceIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'source')
    let summaryIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'summary')
    let detailIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'detail')
    let processNameIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'process_name')
    let rawPayloadIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'raw_payload')
    let extraJsonIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, 'extra_json')
    do {
      let extra = PeripheralTraceEntryRepository.parseExtraJson(
        PeripheralTraceEntryRepository.getOptionalString(resultSet, extraJsonIndex)
      )
      records.push({
        recordId: PeripheralTraceEntryRepository.getRequiredString(resultSet, recordIdIndex),
        occurAt: PeripheralTraceEntryRepository.getRequiredNumber(resultSet, occurAtIndex),
        collectAt: PeripheralTraceEntryRepository.getRequiredNumber(resultSet, collectAtIndex),
        deviceName: PeripheralTraceEntryRepository.getRequiredString(resultSet, deviceNameIndex),
        deviceType: PeripheralTraceEntryRepository.parseDeviceType(
          PeripheralTraceEntryRepository.getRequiredString(resultSet, deviceTypeIndex)
        ),
        deviceId: PeripheralTraceEntryRepository.getRequiredString(resultSet, deviceIdIndex),
        action: PeripheralTraceEntryRepository.parseAction(
          PeripheralTraceEntryRepository.getRequiredString(resultSet, actionIndex)
        ),
        decision: PeripheralTraceEntryRepository.parseDecision(
          PeripheralTraceEntryRepository.getRequiredString(resultSet, decisionIndex)
        ),
        result: PeripheralTraceEntryRepository.parseResult(
          PeripheralTraceEntryRepository.getRequiredString(resultSet, resultIndex)
        ),
        source: PeripheralTraceEntryRepository.parseSource(
          PeripheralTraceEntryRepository.getRequiredString(resultSet, sourceIndex)
        ),
        summary: PeripheralTraceEntryRepository.getRequiredString(resultSet, summaryIndex),
        detail: PeripheralTraceEntryRepository.getOptionalString(resultSet, detailIndex),
        processName: PeripheralTraceEntryRepository.getOptionalString(resultSet, processNameIndex),
        rawPayload: PeripheralTraceEntryRepository.getOptionalString(resultSet, rawPayloadIndex),
        correlationId: extra.correlationId,
        policyVersion: extra.policyVersion,
        rawEventId: extra.rawEventId,
        rawEventName: extra.rawEventName,
        rawOutcome: extra.rawOutcome,
        rawAction: extra.rawAction,
        usbPolicy: PeripheralTraceEntryRepository.parseUsbPolicy(extra.usbPolicy),
        effectivePolicyLabel: extra.effectivePolicyLabel,
        matchedPolicyKind: PeripheralTraceEntryRepository.parseMatchedPolicyKind(extra.matchedPolicyKind)
      })
    } while (PeripheralTraceEntryRepository.goToNextRow(resultSet))
    return records
  }

  private static parseExtraJson(rawValue: string | undefined): PeripheralTraceExtraData {
    if (!rawValue || rawValue.length === 0) {
      return {}
    }
    try {
      let parsed = JSON.parse(rawValue) as Object
      return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as PeripheralTraceExtraData : {}
    } catch (err) {
      LogUtils.warn(TAG, `parseExtraJson failed: ${JSON.stringify(err)}`)
      return {}
    }
  }

  private static parseResult(rawValue: string): LogEventResult {
    let numeric = Number(rawValue)
    if (numeric === LogEventResult.SUCCESS || numeric === LogEventResult.BLOCKED || numeric === LogEventResult.FAILED) {
      return numeric as LogEventResult
    }
    return LogEventResult.SUCCESS
  }

  private static parseAction(rawValue: string): PeripheralRecordAction {
    if (rawValue === 'connect' || rawValue === 'disconnect' || rawValue === 'discover' || rawValue === 'intercept' || rawValue === 'unknown') {
      return rawValue
    }
    return 'unknown'
  }

  private static parseDecision(rawValue: string): PeripheralRecordPolicyHit {
    if (rawValue === 'allow' || rawValue === 'deny' || rawValue === 'unknown') {
      return rawValue
    }
    return 'unknown'
  }

  private static parseSource(rawValue: string): PeripheralRecordSource {
    if (rawValue === 'runtime_event' || rawValue === 'audit_event' || rawValue === 'policy_snapshot') {
      return rawValue
    }
    return 'audit_event'
  }

  private static parseDeviceType(rawValue: string): PeripheralType {
    switch (rawValue) {
      case PeripheralType.USB_STORAGE:
      case PeripheralType.USB_CAMERA:
      case PeripheralType.USB_PRINTER:
      case PeripheralType.USB_HID:
      case PeripheralType.USB_OTHER:
      case PeripheralType.BLUETOOTH:
        return rawValue as PeripheralType
      default:
        return PeripheralType.USB_OTHER
    }
  }

  private static parseUsbPolicy(value?: number): UsbStoragePolicy | undefined {
    if (value === UsbStoragePolicy.READ_WRITE || value === UsbStoragePolicy.READ_ONLY || value === UsbStoragePolicy.DISABLED) {
      return value as UsbStoragePolicy
    }
    return undefined
  }

  private static parseMatchedPolicyKind(value?: string): PeripheralMatchedPolicyKind | undefined {
    switch (value) {
      case 'usb_disabled':
      case 'usb_storage_disabled':
      case 'usb_storage_read_only':
      case 'device_deny':
      case 'bluetooth_connection_event':
      case 'bluetooth_discovery':
      case 'default_allow':
      case 'disconnect_event':
      case 'unknown':
        return value as PeripheralMatchedPolicyKind
      default:
        return undefined
    }
  }

  private static normalizeDeviceId(deviceId: string): string {
    let value = (deviceId || '').trim()
    if (value.length === 0) {
      return 'UNKNOWN'
    }
    return value.replace(/\s+/g, ' ').toUpperCase()
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

  private static readFirstLong(resultSet: relationalStore.ResultSet | null, column: string): number {
    if (!resultSet || !PeripheralTraceEntryRepository.hasRows(resultSet)) {
      return 0
    }
    let columnIndex = PeripheralTraceEntryRepository.getColumnIndex(resultSet, column)
    return PeripheralTraceEntryRepository.getRequiredNumber(resultSet, columnIndex)
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
}

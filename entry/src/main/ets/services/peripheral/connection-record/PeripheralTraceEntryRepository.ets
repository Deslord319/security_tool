import relationalStore from '@ohos.data.relationalStore'
import { AppInfo } from '../../../constants/AppConstants'
import {
  parseSecurityEventResult,
  SecurityEventResult
} from '../../../models/CommonModels'
import {
  normalizeDeviceId,
  normalizePeripheralAction,
  normalizePeripheralDecision,
  normalizePeripheralSource,
  PeripheralMatchedPolicyKind,
  PeripheralRecordAction,
  PeripheralRecordPolicyHit,
  PeripheralRecordSource,
  PeripheralTraceQuery,
  PeripheralTraceRecord,
  PeripheralTraceStats,
  PeripheralType,
  UsbStoragePolicy
} from '../../../models/PeripheralModels'
import { RdbRepository, SqlBundle } from '../../../storage/rdb/RdbRepository'
import { RdbResultSetReader } from '../../../storage/rdb/RdbResultSetReader'
import { PeripheralConnectionRecordStrings } from '../../../constants/modules/PeripheralStrings'

const TAG = 'PeripheralTraceEntryRepo'
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

class PeripheralTraceEntryRdbRepository extends RdbRepository<PeripheralTraceRecord, PeripheralTraceQuery> {
  constructor() {
    super({
      tag: TAG,
      dbName: AppInfo.DB_NAME,
      tableName: TABLE_NAME,
      createStatements: [
        CREATE_TABLE_SQL,
        CREATE_INDEX_OCCUR_AT_SQL,
        CREATE_INDEX_DEVICE_ID_SQL,
        CREATE_INDEX_ACTION_SQL
      ]
    })
  }

  async upsertBatch(records: PeripheralTraceRecord[]): Promise<boolean> {
    return this.replaceBatch(
      records,
      `INSERT OR REPLACE INTO ${TABLE_NAME} (
        record_id, occur_at, collect_at, device_name, device_type, device_id,
        action, decision, result, source, summary, detail, process_name, raw_payload, extra_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      (record: PeripheralTraceRecord) => [
        record.recordId,
        record.occurAt,
        record.collectAt,
        record.deviceName,
        record.deviceType,
        record.deviceId,
        record.action,
        record.decision,
        this.serializeResult(record.result),
        record.source,
        record.summary,
        record.detail ?? null,
        record.processName ?? null,
        record.rawPayload ?? null,
        this.buildExtraJson(record)
      ],
      'upsertBatch'
    )
  }

  async refreshBluetoothUnnamedDeviceNames(updates: PeripheralTraceRecord[]): Promise<boolean> {
    let refreshedNames = new Map<string, string>()
    for (let record of updates) {
      if (record.deviceType !== PeripheralType.BLUETOOTH) {
        continue
      }
      let deviceId = normalizeDeviceId(record.deviceId)
      let deviceName = (record.deviceName ?? '').trim()
      if (
        deviceId.length === 0 ||
        deviceName.length === 0 ||
        deviceName === PeripheralConnectionRecordStrings.UNNAMED_BLUETOOTH
      ) {
        continue
      }
      refreshedNames.set(deviceId, deviceName)
    }
    if (refreshedNames.size === 0) {
      return true
    }

    let success = true
    for (let item of Array.from(refreshedNames.entries())) {
      let updated = await this.executeSql(
        `UPDATE ${TABLE_NAME}
         SET device_name = ?
         WHERE device_type = ?
           AND device_id = ?
           AND device_name = ?`,
        [item[1], PeripheralType.BLUETOOTH, item[0], PeripheralConnectionRecordStrings.UNNAMED_BLUETOOTH],
        'refreshBluetoothUnnamedDeviceNames'
      )
      success = success && updated
    }
    return success
  }

  async listByQuery(query?: PeripheralTraceQuery): Promise<PeripheralTraceRecord[]> {
    return this.queryRows(
      this.buildSelectSqlForQuery(query),
      (reader: RdbResultSetReader) => this.mapResultSet(reader),
      'listByQuery'
    )
  }

  async countByQuery(query?: PeripheralTraceQuery): Promise<number> {
    return this.countByQueryBuilt(
      query,
      (nextQuery?: PeripheralTraceQuery) => this.buildCountSqlForQuery(nextQuery),
      'countByQuery'
    )
  }

  async deleteExpired(cutoffTimestamp: number): Promise<boolean> {
    return this.deleteExpiredByColumn('occur_at', cutoffTimestamp)
  }

  async trimToMaxEntries(maxEntries: number): Promise<boolean> {
    return this.trimToMaxEntriesByOrder('occur_at DESC, id DESC', maxEntries)
  }

  async clearAll(): Promise<boolean> {
    return this.clearAllRows()
  }

  async getStatistics(query?: PeripheralTraceQuery): Promise<PeripheralTraceStats> {
    let actionCounts = await this.groupCountByAction(query)
    return {
      total: await this.countByQuery(query),
      connects: actionCounts.get('connect') ?? 0,
      disconnects: actionCounts.get('disconnect') ?? 0,
      policyChanges: actionCounts.get('discover') ?? 0
    }
  }

  private async groupCountByAction(query?: PeripheralTraceQuery): Promise<Map<string, number>> {
    return this.queryGroupCounts('action', this.buildWhereClause(query), 'groupCountByAction')
  }

  private buildSelectSqlForQuery(query?: PeripheralTraceQuery): SqlBundle {
    return this.buildSelectSql(
      `record_id, occur_at, collect_at, device_name, device_type, device_id,
       action, decision, result, source, summary, detail, process_name, raw_payload, extra_json`,
      this.buildWhereClause(query),
      'occur_at DESC, id DESC'
    )
  }

  private buildCountSqlForQuery(query?: PeripheralTraceQuery): SqlBundle {
    return this.buildCountSql(this.buildWhereClause(query))
  }

  private buildWhereClause(query?: PeripheralTraceQuery): SqlBundle {
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
      args.push(normalizeDeviceId(query.deviceId))
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
      query.results.forEach((result: SecurityEventResult) => args.push(this.serializeResult(result)))
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

  private serializeResult(result: SecurityEventResult): string {
    return result.toString()
  }

  private buildExtraJson(record: PeripheralTraceRecord): string | null {
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

  private mapResultSet(reader: RdbResultSetReader): PeripheralTraceRecord[] {
    let records: PeripheralTraceRecord[] = []
    if (!reader.moveToFirst()) {
      return records
    }
    let recordIdIndex = reader.getColumnIndex('record_id')
    let occurAtIndex = reader.getColumnIndex('occur_at')
    let collectAtIndex = reader.getColumnIndex('collect_at')
    let deviceNameIndex = reader.getColumnIndex('device_name')
    let deviceTypeIndex = reader.getColumnIndex('device_type')
    let deviceIdIndex = reader.getColumnIndex('device_id')
    let actionIndex = reader.getColumnIndex('action')
    let decisionIndex = reader.getColumnIndex('decision')
    let resultIndex = reader.getColumnIndex('result')
    let sourceIndex = reader.getColumnIndex('source')
    let summaryIndex = reader.getColumnIndex('summary')
    let detailIndex = reader.getColumnIndex('detail')
    let processNameIndex = reader.getColumnIndex('process_name')
    let rawPayloadIndex = reader.getColumnIndex('raw_payload')
    let extraJsonIndex = reader.getColumnIndex('extra_json')
    do {
      let extra = this.parseExtraJson(reader.getOptionalString(extraJsonIndex))
      records.push({
        recordId: reader.getRequiredString(recordIdIndex),
        occurAt: reader.getRequiredNumber(occurAtIndex),
        collectAt: reader.getRequiredNumber(collectAtIndex),
        deviceName: reader.getRequiredString(deviceNameIndex),
        deviceType: this.parseDeviceType(reader.getRequiredString(deviceTypeIndex)),
        deviceId: reader.getRequiredString(deviceIdIndex),
        action: this.parseAction(reader.getRequiredString(actionIndex)),
        decision: this.parseDecision(reader.getRequiredString(decisionIndex)),
        result: this.parseResult(reader.getRequiredString(resultIndex)),
        source: this.parseSource(reader.getRequiredString(sourceIndex)),
        summary: reader.getRequiredString(summaryIndex),
        detail: reader.getOptionalString(detailIndex),
        processName: reader.getOptionalString(processNameIndex),
        rawPayload: reader.getOptionalString(rawPayloadIndex),
        correlationId: extra.correlationId,
        policyVersion: extra.policyVersion,
        rawEventId: extra.rawEventId,
        rawEventName: extra.rawEventName,
        rawOutcome: extra.rawOutcome,
        rawAction: extra.rawAction,
        usbPolicy: this.parseUsbPolicy(extra.usbPolicy),
        effectivePolicyLabel: extra.effectivePolicyLabel,
        matchedPolicyKind: this.parseMatchedPolicyKind(extra.matchedPolicyKind)
      })
    } while (reader.moveToNext())
    return records
  }

  private parseExtraJson(rawValue: string | undefined): PeripheralTraceExtraData {
    return this.parseJsonObject<PeripheralTraceExtraData>(rawValue, 'parseExtraJson') ?? {}
  }

  private parseResult(rawValue: string): SecurityEventResult {
    return parseSecurityEventResult(rawValue, SecurityEventResult.FAILED)
  }

  private parseAction(rawValue: string): PeripheralRecordAction {
    return normalizePeripheralAction(rawValue)
  }

  private parseDecision(rawValue: string): PeripheralRecordPolicyHit {
    return normalizePeripheralDecision(rawValue)
  }

  private parseSource(rawValue: string): PeripheralRecordSource {
    return normalizePeripheralSource(rawValue)
  }

  private parseDeviceType(rawValue: string): PeripheralType {
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

  private parseUsbPolicy(value?: number): UsbStoragePolicy | undefined {
    if (value === UsbStoragePolicy.READ_WRITE || value === UsbStoragePolicy.READ_ONLY || value === UsbStoragePolicy.DISABLED) {
      return value as UsbStoragePolicy
    }
    return undefined
  }

  private parseMatchedPolicyKind(value?: string): PeripheralMatchedPolicyKind | undefined {
    switch (value) {
      case 'usb_disabled':
      case 'usb_storage_disabled':
      case 'usb_storage_read_only':
      case 'device_deny':
      case 'bluetooth_disabled':
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
}

export const PeripheralTraceEntryRepository = new PeripheralTraceEntryRdbRepository()

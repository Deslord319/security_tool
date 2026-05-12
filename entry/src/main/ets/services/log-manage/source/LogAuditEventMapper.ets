import { securityAudit } from '@kit.DeviceSecurityKit'
import { LogPathUtils } from '../../../utils/LogPathUtils'
import { LogManageAuditStrings } from '../../../constants/modules/LogManageStrings'
import { LogUtils } from '../../../utils/LogUtils'
import {
  generateLogEntryId,
  LogDetailTableRow,
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../../models/LogModels'
import { resolveLogEventResultLabel } from '../../../constants/modules/LogManageStrings'
import { formatStandardDateTime } from '../../../utils/DateTimeFormatUtils'
import { LooseRecord, LooseValue } from '../../../types/LooseValueTypes'
import {
  pickNumberFromRecords as pickNumber,
  pickStringFromRecords as pickString
} from '../../../utils/ValuePicker'
import { resolveAuditSourceTimestamp } from './LogTimestampResolver'
import { AUDIT_EVENT_TYPES_BY_ID } from './LogAuditEventIds'

const TAG = 'LogAuditEventMapper'

interface ParsedAuditPayload {
  detail: string
  result: LogEventResult
  detailRows: LogDetailTableRow[]
  processName?: string
  pid?: number
  rawFilePath?: string
  filePath?: string
  remoteAddr?: string
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
}

export function parseAuditEventToLogEntry(
  event: securityAudit.AuditEvent,
  nowProvider: () => number = () => Date.now()
): LogEntry | undefined {
  const mappedType = AUDIT_EVENT_TYPES_BY_ID.get(event.eventId)
  if (mappedType === undefined) {
    return undefined
  }

  const timestamp = resolveAuditSourceTimestamp(event.timestamp || '', nowProvider)
  const parsed = parseAuditPayload(event.content || '', event.metadata, mappedType, event, timestamp)
  LogUtils.info(
    TAG,
    `AUDIT_MAPPED_RESULT eventId=${event.eventId}, eventType=${mappedType}, rawEventName=${parsed.rawEventName || '-'}, rawAction=${parsed.rawAction || '-'}, rawOutcome=${parsed.rawOutcome || '-'}, mappedResult=${parsed.result}, processName=${parsed.processName || '-'}, filePath=${parsed.filePath || '-'}, detail=${parsed.detail}`
  )
  return {
    id: generateLogEntryId(),
    timestamp,
    eventType: mappedType,
    detail: parsed.detail,
    processName: parsed.processName,
    pid: parsed.pid,
    uid: event.userId,
    filePath: parsed.filePath,
    remoteAddr: parsed.remoteAddr,
    sourceEventId: event.eventId,
    rawEventName: parsed.rawEventName,
    rawOutcome: parsed.rawOutcome,
    rawAction: parsed.rawAction,
    result: parsed.result,
    detailRows: parsed.detailRows
  } as LogEntry
}

function parseAuditPayload(
  content: string,
  metadata: string | undefined,
  eventType: LogEventType,
  event: securityAudit.AuditEvent,
  timestamp: number
): ParsedAuditPayload {
  const contentJson = safeParseJson(content)
  const metadataJson = safeParseJson(metadata)
  const sources = collectJsonSources(contentJson, metadataJson)
  const rawOutcome = resolveRawOutcome(sources)
  const rawFilePath = resolveAuditRawFilePath(content, metadata, sources)
  const normalizedFilePath = LogPathUtils.normalizePathCandidate(rawFilePath)

  return {
    detail: pickString(sources, ['description', 'message', 'detail', 'msg', 'event_desc', 'summary']) ||
      content || metadata || LogManageAuditStrings.FALLBACK_DETAIL,
    result: mapResult(rawOutcome),
    detailRows: buildDetailRows(eventType, event, timestamp, contentJson, metadataJson, sources),
    processName: pickString(sources, [
      'processName', 'procName', 'proc_name', 'cmdline', 'process', 'process_name', 'bundleName', 'bundle_name',
      'CALLER_NAME', 'CALLER_PNAMEID', 'PNAMEID'
    ]),
    pid: pickNumber(sources, ['pid', 'processId', 'process_id']),
    rawFilePath: rawFilePath,
    filePath: normalizedFilePath,
    remoteAddr: pickString(sources, ['remoteAddress', 'remoteAddr', 'remote_addr', 'remoteIp', 'remote_ip', 'dstAddr', 'dst_addr', 'dstIp', 'dst_ip', 'peerAddr', 'peer_addr']),
    rawEventName: pickString(sources, ['event_name', 'eventName', 'name', 'name_', 'EVENT_NAME']),
    rawOutcome: rawOutcome,
    rawAction: pickString(sources, ['action', 'eventAction', 'event_action', 'operation', 'op', 'state', 'OPERATION_TYPE', 'AUTH_TYPE']) ||
      pickNumberOrFirstArrayNumber(sources, ['OPERATION_TYPE', 'AUTH_TYPE'])
  }
}

function buildDetailRows(
  eventType: LogEventType,
  event: securityAudit.AuditEvent,
  timestamp: number,
  contentJson?: LooseRecord,
  metadataJson?: LooseRecord,
  sources: LooseRecord[] = []
): LogDetailTableRow[] {
  let rows: LogDetailTableRow[] = []
  switch (eventType) {
    case LogEventType.ACCOUNT: {
      const caller = findNestedJson([contentJson, metadataJson], 'caller')
      const callerSources = compactSources(caller, contentJson, metadataJson, ...sources)
      appendTextRow(rows, 'account.userName', '用户名', pickString(callerSources, ['userName', 'user_name']))
      appendNumberRow(rows, 'account.userId', '用户 ID', pickNumber(callerSources, ['userId', 'user_id']))
      appendTextRow(rows, 'account.callerName', 'CALLER_NAME', pickString(callerSources, ['CALLER_NAME', 'CALLER_PNAMEID', 'PNAMEID']))
      appendNumberRow(rows, 'account.authType', 'AUTH_TYPE', pickNumber(callerSources, ['AUTH_TYPE']))
      appendTextRow(rows, 'account.authResultRaw', 'AUTH_RESULT', resolveAuthRawOutcome(callerSources))
      appendNumberRow(rows, 'account.authTimeSpan', 'AUTH_TIME_SPAN', pickNumber(callerSources, ['AUTH_TIME_SPAN']))
      appendTextRow(rows, 'account.operationTime', 'OPERATION_TIME', pickString(callerSources, ['OPERATION_TIME', 'HAPPEN_TIME']))
      appendTextRow(rows, 'account.result', '结果', resolveLogEventResultLabel(mapResult(resolveRawOutcome(sources))))
      appendTextRow(rows, 'account.timestamp', '事件时间', formatStandardDateTime(timestamp))
      appendNumberRow(rows, 'account.eventId', '事件 ID', event.eventId)
      break
    }
    case LogEventType.PERMISSION: {
      const extra = findNestedJson([contentJson, metadataJson], 'extra')
      const extraSources = compactSources(extra, contentJson, metadataJson, ...sources)
      const newPermission = findNestedJson([extra, contentJson, metadataJson], 'newPermission')
      const newPermissionSources = compactSources(newPermission, extra, contentJson, metadataJson, ...sources)
      appendTextRow(rows, 'permission.bundleName', '应用包名', pickString(extraSources, ['bundleName', 'bundle_name']))
      appendNumberRow(rows, 'permission.pid', 'PID', pickNumber(extraSources, ['pid', 'processId', 'process_id']))
      appendNumberRow(rows, 'permission.uid', 'UID', pickNumber(extraSources, ['uid', 'userId', 'user_id']))
      appendTextRow(rows, 'permission.newPermissionName', '新权限名称', pickString(newPermissionSources, ['PermissionName', 'permissionName', 'name']))
      appendTextRow(rows, 'permission.newPermissionState', '新权限状态', pickString(newPermissionSources, ['PermissionState', 'permissionState', 'state']))
      appendTextRow(rows, 'permission.timestamp', '事件时间', formatStandardDateTime(timestamp))
      appendNumberRow(rows, 'permission.eventId', '事件 ID', event.eventId)
      break
    }
    case LogEventType.FILE: {
      appendTextRow(rows, 'file.operation', '操作类型', pickString(sources, ['event_name', 'eventName', 'name']) || pickString(sources, ['action', 'eventAction', 'event_action', 'operation', 'op', 'state']))
      appendTextRow(rows, 'file.filePath', '文件路径', pickString(sources, ['filePath', 'file_path', 'path', 'srcPath', 'src_path']) || rawFilePathFallback(contentJson, metadataJson, sources))
      appendTextRow(rows, 'file.processName', '进程名', pickString(sources, ['processName', 'procName', 'proc_name', 'cmdline', 'process', 'process_name', 'bundleName', 'bundle_name']))
      appendNumberRow(rows, 'file.pid', 'PID', pickNumber(sources, ['pid', 'processId', 'process_id']))
      appendNumberRow(rows, 'file.uid', 'UID', pickNumber(sources, ['uid', 'userId', 'user_id']))
      appendTextRow(rows, 'file.result', '结果', resolveLogEventResultLabel(mapResult(pickString(sources, ['outcome', 'result', 'status', 'decision', 'actionResult', 'action_result']))))
      appendTextRow(rows, 'file.timestamp', '事件时间', formatStandardDateTime(timestamp))
      appendNumberRow(rows, 'file.eventId', '事件 ID', event.eventId)
      break
    }
    default:
      break
  }
  return rows
}

function rawFilePathFallback(contentJson?: LooseRecord, metadataJson?: LooseRecord, sources: LooseRecord[] = []): string | undefined {
  const rawSources = compactSources(contentJson, metadataJson, ...sources)
  return pickString(rawSources, [
    'path',
    'filePath',
    'file_path',
    'srcPath',
    'src_path',
    'targetPath',
    'target_path',
    'dstPath',
    'dst_path',
    'uri',
    'fileUri',
    'file_uri'
  ])
}

function appendTextRow(rows: LogDetailTableRow[], key: string, label: string, value?: string): void {
  const normalized = (value || '').trim()
  if (normalized.length === 0) {
    return
  }
  rows.push({ key, label, value: normalized } as LogDetailTableRow)
}

function appendNumberRow(rows: LogDetailTableRow[], key: string, label: string, value?: number): void {
  if (value === undefined) {
    return
  }
  rows.push({ key, label, value: `${value}` } as LogDetailTableRow)
}

function compactSources(...sources: Array<LooseRecord | undefined>): LooseRecord[] {
  let result: LooseRecord[] = []
  for (let source of sources) {
    if (source) {
      result.push(source)
    }
  }
  return result
}

function findNestedJson(sources: Array<LooseRecord | undefined>, key: string): LooseRecord | undefined {
  for (let source of sources) {
    if (!source) {
      continue
    }
    const nested = extractNestedJson(source, key)
    if (nested) {
      return nested
    }
  }
  return undefined
}

function resolveAuditRawFilePath(content: string, metadata: string | undefined, sources: LooseRecord[]): string | undefined {
  const structured = pickString(sources, [
    'targetPath', 'target_path', 'dstPath', 'dst_path', 'uri', 'fileUri', 'file_uri',
    'filePath', 'file_path', 'path', 'srcPath', 'src_path'
  ])
  return LogPathUtils.extractRawAuditPath(structured, [content, metadata])
}

function resolveRawOutcome(sources: LooseRecord[]): string | undefined {
  const direct = pickString(sources, [
    'outcome', 'result', 'status', 'decision', 'actionResult', 'action_result',
    'AUTH_RESULT', 'RESULT', 'RESULT_CODE', 'AUTH_RESULT_CODE'
  ])
  if (direct) {
    return direct
  }
  return pickNumberOrFirstArrayNumber(sources, [
    'AUTH_RESULT', 'RESULT', 'RESULT_CODE', 'AUTH_RESULT_CODE', 'RESULT_CODE_LIST'
  ])
}

function resolveAuthRawOutcome(sources: LooseRecord[]): string | undefined {
  const direct = pickString(sources, ['AUTH_RESULT', 'RESULT', 'RESULT_CODE', 'AUTH_RESULT_CODE'])
  if (direct) {
    return direct
  }
  return pickNumberOrFirstArrayNumber(sources, [
    'AUTH_RESULT', 'RESULT', 'RESULT_CODE', 'AUTH_RESULT_CODE', 'RESULT_CODE_LIST'
  ])
}

function pickNumberOrFirstArrayNumber(sources: LooseRecord[], keys: string[]): string | undefined {
  for (const source of sources) {
    for (const key of keys) {
      const raw = source[key]
      if (typeof raw === 'number' && Number.isFinite(raw)) {
        return `${raw}`
      }
      if (isLooseValueArray(raw)) {
        const rawItems = raw as LooseValue[]
        for (const item of rawItems) {
          if (typeof item === 'number' && Number.isFinite(item)) {
            return `${item}`
          }
          if (typeof item === 'string' && item.trim().length > 0) {
            return item.trim()
          }
        }
      }
    }
  }
  return undefined
}

function isLooseValueArray(value: LooseValue): boolean {
  return Array.isArray(value)
}

function mapResult(rawOutcome?: string): LogEventResult {
  if (!rawOutcome) {
    LogUtils.info(TAG, 'AUDIT_RESULT_MAPPING rawOutcome=-, mappedResult=0')
    return LogEventResult.SUCCESS
  }
  const normalized = rawOutcome.trim().toLowerCase()
  const numeric = Number(normalized)
  if (Number.isFinite(numeric)) {
    const mappedResult = numeric === 0 ? LogEventResult.SUCCESS : LogEventResult.FAILED
    LogUtils.info(TAG, `AUDIT_RESULT_MAPPING rawOutcome=${rawOutcome}, mappedResult=${mappedResult}`)
    return mappedResult
  }
  if (normalized.includes('blocked') || normalized.includes('deny') || normalized.includes('intercept')) {
    LogUtils.info(TAG, `AUDIT_RESULT_MAPPING rawOutcome=${rawOutcome}, mappedResult=1`)
    return LogEventResult.BLOCKED
  }
  if (normalized.includes('fail') || normalized.includes('error') || normalized.includes('reject')) {
    LogUtils.info(TAG, `AUDIT_RESULT_MAPPING rawOutcome=${rawOutcome}, mappedResult=2`)
    return LogEventResult.FAILED
  }
  LogUtils.info(TAG, `AUDIT_RESULT_MAPPING rawOutcome=${rawOutcome}, mappedResult=0`)
  return LogEventResult.SUCCESS
}

function collectJsonSources(contentJson?: LooseRecord, metadataJson?: LooseRecord): LooseRecord[] {
  const result: LooseRecord[] = []
  const append = (candidate?: LooseRecord): void => {
    if (!candidate) {
      return
    }
    result.push(candidate)
    const extra = extractNestedJson(candidate, 'extra')
    if (extra) {
      result.push(extra)
    }
    const metadata = extractNestedJson(candidate, 'metadata')
    if (metadata) {
      result.push(metadata)
    }
  }
  append(contentJson)
  append(metadataJson)
  return result
}

function safeParseJson(value: string | undefined): LooseRecord | undefined {
  if (!value) {
    return undefined
  }
  try {
    const parsed = JSON.parse(value) as Object
    return toJsonMap(parsed)
  } catch {
    return undefined
  }
}

function extractNestedJson(source: LooseRecord, key: string): LooseRecord | undefined {
  const candidate = source[key]
  if (typeof candidate === 'string') {
    return safeParseJson(candidate)
  }
  if (candidate && typeof candidate === 'object') {
    return toJsonMap(candidate)
  }
  return undefined
}

function toJsonMap(candidate: Object | undefined): LooseRecord | undefined {
  if (!candidate || Array.isArray(candidate)) {
    return undefined
  }
  return candidate as LooseRecord
}

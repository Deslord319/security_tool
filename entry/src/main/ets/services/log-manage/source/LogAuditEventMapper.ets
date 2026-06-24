import { securityAudit } from '@kit.DeviceSecurityKit'
import { LogPathUtils } from '../../../utils/LogPathUtils'
import { LogManageAuditStrings } from '../../../constants/modules/LogManageStrings'
import { LogUtils } from '../../../utils/LogUtils'
import {
  generateLogEntryId,
  LogDetailTableRow,
  LogEntry,
  LogEventType
} from '../../../models/LogModels'
import { formatStandardDateTime } from '../../../utils/DateTimeFormatUtils'
import { LooseRecord, LooseValue } from '../../../types/LooseValueTypes'
import {
  pickNumberFromRecords as pickNumber,
  pickStringFromRecords as pickString
} from '../../../utils/ValuePicker'
import { resolveAuditSourceTimestamp } from './LogTimestampResolver'
import { AUDIT_EVENT_DESCRIPTIONS_BY_ID, AUDIT_EVENT_TYPES_BY_ID } from './LogAuditEventIds'

const TAG = 'LogAuditEventMapper'

interface ParsedAuditPayload {
  detail: string
  detailRows: LogDetailTableRow[]
  processName?: string
  pid?: number
  filePath?: string
  remoteAddr?: string
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
}

interface FileAuditPathInfo {
  primaryPath?: string
  oldPath?: string
  newPath?: string
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
    `AUDIT_MAPPED eventId=${event.eventId}, eventType=${mappedType}, rawEventName=${parsed.rawEventName || '-'}, rawAction=${parsed.rawAction || '-'}, rawOutcome=${parsed.rawOutcome || '-'}, processName=${parsed.processName || '-'}, filePath=${parsed.filePath || '-'}, detail=${parsed.detail}`
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
  const fileAuditPathInfo = resolveFileAuditPathInfo(content, metadata, sources)

  return {
    detail: pickString(sources, ['description', 'message', 'detail', 'msg', 'event_desc', 'summary']) ||
      content || metadata || LogManageAuditStrings.FALLBACK_DETAIL,
    detailRows: buildDetailRows(eventType, event, timestamp, contentJson, metadataJson, sources, fileAuditPathInfo),
    processName: pickString(sources, [
      'processName', 'procName', 'proc_name', 'cmdline', 'process', 'process_name', 'bundleName', 'bundle_name',
      'CALLER_NAME', 'CALLER_PNAMEID', 'PNAMEID'
    ]),
    pid: pickNumber(sources, ['pid', 'processId', 'process_id']),
    filePath: fileAuditPathInfo.primaryPath,
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
  sources: LooseRecord[] = [],
  fileAuditPathInfo: FileAuditPathInfo = {}
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
      appendTextRow(rows, 'file.filePath', '文件路径', fileAuditPathInfo.primaryPath)
      appendTextRow(rows, 'file.oldPath', '原文件路径', fileAuditPathInfo.oldPath)
      appendTextRow(rows, 'file.newPath', '新文件路径', fileAuditPathInfo.newPath)
      appendTextRow(rows, 'file.processName', '进程名', pickString(sources, ['processName', 'procName', 'proc_name', 'cmdline', 'process', 'process_name', 'bundleName', 'bundle_name']))
      appendNumberRow(rows, 'file.pid', 'PID', pickNumber(sources, ['pid', 'processId', 'process_id']))
      appendNumberRow(rows, 'file.uid', 'UID', pickNumber(sources, ['uid', 'userId', 'user_id']))
      appendTextRow(rows, 'file.timestamp', '事件时间', formatStandardDateTime(timestamp))
      appendNumberRow(rows, 'file.eventId', '事件 ID', event.eventId)
      break
    }
    case LogEventType.CRASH: {
      appendTextRow(rows, 'crash.eventName', '事件名称', pickString(sources, ['event_name', 'eventName', 'name', 'name_', 'EVENT_NAME']))
      appendTextRow(rows, 'crash.processName', '进程名称', pickString(sources, [
        'processName', 'procName', 'proc_name', 'process', 'process_name', 'bundleName', 'bundle_name',
        'CALLER_NAME', 'CALLER_PNAMEID', 'PNAMEID'
      ]))
      appendNumberRow(rows, 'crash.pid', 'PID', pickNumber(sources, ['pid', 'processId', 'process_id']))
      appendNumberRow(rows, 'crash.uid', 'UID', pickNumber(sources, ['uid', 'userId', 'user_id']))
      appendTextRow(rows, 'crash.timestamp', '事件时间', formatStandardDateTime(timestamp))
      appendNumberRow(rows, 'crash.eventId', '事件 ID', event.eventId)
      break
    }
    case LogEventType.AUDIT: {
      appendTextRow(rows, 'audit.description', LogManageAuditStrings.DESCRIPTION_LABEL, resolveAuditEventDescription(event.eventId))
      appendTextRow(rows, 'audit.rawJson', LogManageAuditStrings.RAW_JSON_LABEL, buildRawAuditJson(event))
      break
    }
    default:
      break
  }
  return rows
}

function resolveAuditEventDescription(eventId: number): string {
  return AUDIT_EVENT_DESCRIPTIONS_BY_ID.get(eventId) || `事件 ID: ${eventId}`
}

function buildRawAuditJson(event: securityAudit.AuditEvent): string {
  return JSON.stringify({
    eventId: event.eventId,
    timestamp: event.timestamp || '',
    userId: event.userId,
    content: event.content || '',
    metadata: event.metadata || ''
  })
}

function resolveFileAuditPathInfo(
  content: string,
  metadata: string | undefined,
  sources: LooseRecord[]
): FileAuditPathInfo {
  const newPathCandidate = pickString(sources, [
    'file_newpath',
    'file_new_path',
    'newPath',
    'new_path',
    'targetPath',
    'target_path',
    'dstPath',
    'dst_path'
  ])
  const directPathCandidate = pickString(sources, [
    'filePath',
    'file_path',
    'path',
    'uri',
    'fileUri',
    'file_uri'
  ])
  const oldPathCandidate = pickString(sources, [
    'file_oldpath',
    'file_old_path',
    'oldPath',
    'old_path',
    'srcPath',
    'src_path'
  ])
  const primaryCandidate = newPathCandidate || directPathCandidate || oldPathCandidate
  const scannedPrimary = LogPathUtils.extractRawAuditPath(primaryCandidate, [content, metadata])
  return {
    primaryPath: LogPathUtils.normalizePathCandidate(scannedPrimary, true),
    oldPath: LogPathUtils.normalizePathCandidate(oldPathCandidate, true),
    newPath: LogPathUtils.normalizePathCandidate(newPathCandidate, true)
  }
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

const OUTCOME_NUMBER_KEYS: string[] = [
  'AUTH_RESULT', 'RESULT', 'RESULT_CODE', 'AUTH_RESULT_CODE', 'RESULT_CODE_LIST'
]

function resolveOutcome(sources: LooseRecord[], stringKeys: string[]): string | undefined {
  const direct = pickString(sources, stringKeys)
  if (direct) {
    return direct
  }
  return pickNumberOrFirstArrayNumber(sources, OUTCOME_NUMBER_KEYS)
}

function resolveRawOutcome(sources: LooseRecord[]): string | undefined {
  return resolveOutcome(sources, [
    'outcome', 'result', 'status', 'decision', 'actionResult', 'action_result',
    'AUTH_RESULT', 'RESULT', 'RESULT_CODE', 'AUTH_RESULT_CODE'
  ])
}

function resolveAuthRawOutcome(sources: LooseRecord[]): string | undefined {
  return resolveOutcome(sources, ['AUTH_RESULT', 'RESULT', 'RESULT_CODE', 'AUTH_RESULT_CODE'])
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

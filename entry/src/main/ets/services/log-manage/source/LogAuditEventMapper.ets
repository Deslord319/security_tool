import { securityAudit } from '@kit.DeviceSecurityKit'
import { LogPathUtils } from '../../../utils/LogPathUtils'
import { LogManageAuditStrings } from '../../../constants/modules/LogManageStrings'
import {
  generateLogEntryId,
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../../models/DataModels'
import { pickNumber, pickString } from '../common/LogValuePicker'
import { resolveAuditSourceTimestamp } from './LogTimestampResolver'

type JsonField = string | number | boolean | Object | undefined
type JsonMap = Record<string, JsonField>

interface ParsedAuditPayload {
  detail: string
  result: LogEventResult
  processName?: string
  pid?: number
  rawFilePath?: string
  filePath?: string
  remoteAddr?: string
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
}

const EVENT_TYPE_BY_ID: Map<number, LogEventType> = new Map<number, LogEventType>([
  [securityAudit.NotifyEvent.FILE, LogEventType.FILE],
  [securityAudit.NotifyEvent.FILE_INTERCEPTED, LogEventType.FILE],
  [securityAudit.NotifyEvent.KIA_CREATE, LogEventType.FILE],
  [securityAudit.NotifyEvent.KIA_READ, LogEventType.FILE],
  [securityAudit.NotifyEvent.KIA_VARIANT, LogEventType.FILE],
  [securityAudit.NotifyEvent.KIA_INTERCEPT, LogEventType.FILE],
  [securityAudit.NotifyEvent.ACCOUNT, LogEventType.ACCOUNT],
  [securityAudit.NotifyEvent.PERMISSION, LogEventType.PERMISSION]
])

export function parseAuditEventToLogEntry(
  event: securityAudit.AuditEvent,
  nowProvider: () => number = () => Date.now()
): LogEntry | undefined {
  const mappedType = EVENT_TYPE_BY_ID.get(event.eventId)
  if (mappedType === undefined) {
    return undefined
  }

  const parsed = parseAuditPayload(event.content || '', event.metadata)
  return {
    id: generateLogEntryId(),
    timestamp: resolveAuditSourceTimestamp(event.timestamp || '', nowProvider),
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
    result: parsed.result
  }
}

function parseAuditPayload(content: string, metadata?: string): ParsedAuditPayload {
  const contentJson = safeParseJson(content)
  const metadataJson = safeParseJson(metadata)
  const sources = collectJsonSources(contentJson, metadataJson)
  const rawOutcome = pickString(sources, ['outcome', 'result', 'status', 'decision', 'actionResult', 'action_result'])
  const rawFilePath = resolveAuditRawFilePath(content, metadata, sources)
  const normalizedFilePath = LogPathUtils.normalizePathCandidate(rawFilePath)

  return {
    detail: pickString(sources, ['description', 'message', 'detail', 'msg', 'event_desc', 'summary']) ||
      content || metadata || LogManageAuditStrings.FALLBACK_DETAIL,
    result: mapResult(rawOutcome),
    processName: pickString(sources, ['processName', 'procName', 'proc_name', 'cmdline', 'process', 'process_name', 'bundleName', 'bundle_name']),
    pid: pickNumber(sources, ['pid', 'processId', 'process_id']),
    rawFilePath: rawFilePath,
    filePath: normalizedFilePath,
    remoteAddr: pickString(sources, ['remoteAddress', 'remoteAddr', 'remote_addr', 'remoteIp', 'remote_ip', 'dstAddr', 'dst_addr', 'dstIp', 'dst_ip', 'peerAddr', 'peer_addr']),
    rawEventName: pickString(sources, ['event_name', 'eventName', 'name']),
    rawOutcome: rawOutcome,
    rawAction: pickString(sources, ['action', 'eventAction', 'event_action', 'operation', 'op', 'state'])
  }
}

function resolveAuditRawFilePath(content: string, metadata: string | undefined, sources: JsonMap[]): string | undefined {
  const structured = pickString(sources, [
    'targetPath', 'target_path', 'dstPath', 'dst_path', 'uri', 'fileUri', 'file_uri',
    'filePath', 'file_path', 'path', 'srcPath', 'src_path'
  ])
  return LogPathUtils.extractRawAuditPath(structured, [content, metadata])
}

function mapResult(rawOutcome?: string): LogEventResult {
  if (!rawOutcome) {
    return LogEventResult.SUCCESS
  }
  const normalized = rawOutcome.toLowerCase()
  if (normalized.includes('blocked') || normalized.includes('deny') || normalized.includes('intercept')) {
    return LogEventResult.BLOCKED
  }
  if (normalized.includes('failed') || normalized.includes('error') || normalized.includes('reject')) {
    return LogEventResult.FAILED
  }
  return LogEventResult.SUCCESS
}

function collectJsonSources(contentJson?: JsonMap, metadataJson?: JsonMap): JsonMap[] {
  const result: JsonMap[] = []
  const append = (candidate?: JsonMap): void => {
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

function safeParseJson(value: string | undefined): JsonMap | undefined {
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

function extractNestedJson(source: JsonMap, key: string): JsonMap | undefined {
  const candidate = source[key]
  if (typeof candidate === 'string') {
    return safeParseJson(candidate)
  }
  if (candidate && typeof candidate === 'object') {
    return toJsonMap(candidate)
  }
  return undefined
}

function toJsonMap(candidate: Object | undefined): JsonMap | undefined {
  if (!candidate || Array.isArray(candidate)) {
    return undefined
  }
  return candidate as JsonMap
}

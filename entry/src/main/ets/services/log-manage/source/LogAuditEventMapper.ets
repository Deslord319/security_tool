import { securityAudit } from '@kit.DeviceSecurityKit'
import { LogPathUtils } from '../../../utils/LogPathUtils'
import { LogManageStrings } from '../../../constants/modules/LogManageStrings'
import {
  generateLogEntryId,
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../../models/DataModels'

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

const FILE_EVENT_IDS: number[] = [
  securityAudit.NotifyEvent.FILE,
  securityAudit.NotifyEvent.FILE_INTERCEPTED,
  securityAudit.NotifyEvent.KIA_CREATE,
  securityAudit.NotifyEvent.KIA_READ,
  securityAudit.NotifyEvent.KIA_VARIANT,
  securityAudit.NotifyEvent.KIA_INTERCEPT
]

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
    timestamp: parseTimestamp(event.timestamp || '', nowProvider),
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
  const rawOutcome = pickFirstString(sources, ['outcome', 'result', 'status', 'decision', 'actionResult', 'action_result'])
  const rawFilePath = resolveAuditRawFilePath(content, metadata, sources)
  const normalizedFilePath = LogPathUtils.normalizePathCandidate(rawFilePath)

  return {
    detail: pickFirstString(sources, ['description', 'message', 'detail', 'msg', 'event_desc', 'summary']) ||
      content || metadata || LogManageStrings.auditEventFallbackDetail,
    result: mapResult(rawOutcome),
    processName: pickFirstString(sources, ['processName', 'procName', 'proc_name', 'cmdline', 'process', 'process_name', 'bundleName', 'bundle_name']),
    pid: pickFirstNumber(sources, ['pid', 'processId', 'process_id']),
    rawFilePath: rawFilePath,
    filePath: normalizedFilePath,
    remoteAddr: pickFirstString(sources, ['remoteAddress', 'remoteAddr', 'remote_addr', 'remoteIp', 'remote_ip', 'dstAddr', 'dst_addr', 'dstIp', 'dst_ip', 'peerAddr', 'peer_addr']),
    rawEventName: pickFirstString(sources, ['event_name', 'eventName', 'name']),
    rawOutcome: rawOutcome,
    rawAction: pickFirstString(sources, ['action', 'eventAction', 'event_action', 'operation', 'op', 'state'])
  }
}

function resolveAuditRawFilePath(content: string, metadata: string | undefined, sources: JsonMap[]): string | undefined {
  const structured = pickFirstString(sources, [
    'targetPath', 'target_path', 'dstPath', 'dst_path', 'uri', 'fileUri', 'file_uri',
    'filePath', 'file_path', 'path', 'srcPath', 'src_path'
  ])
  return LogPathUtils.extractRawAuditPath(structured, [content, metadata])
}

function parseTimestamp(ts: string, nowProvider: () => number): number {
  if (ts.length < 14) {
    return nowProvider()
  }
  return new Date(
    parseInt(ts.substring(0, 4)),
    parseInt(ts.substring(4, 6)) - 1,
    parseInt(ts.substring(6, 8)),
    parseInt(ts.substring(8, 10)),
    parseInt(ts.substring(10, 12)),
    parseInt(ts.substring(12, 14))
  ).getTime()
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

function pickFirstString(sources: JsonMap[], keys: string[]): string | undefined {
  for (const source of sources) {
    for (const key of keys) {
      const raw = source[key]
      if (typeof raw === 'string' && raw.trim().length > 0) {
        return raw.trim()
      }
    }
  }
  return undefined
}

function pickFirstNumber(sources: JsonMap[], keys: string[]): number | undefined {
  for (const source of sources) {
    for (const key of keys) {
      const raw = source[key]
      if (typeof raw === 'number' && Number.isFinite(raw)) {
        return raw
      }
      if (typeof raw === 'string') {
        const parsed = Number(raw)
        if (Number.isFinite(parsed)) {
          return parsed
        }
      }
    }
  }
  return undefined
}

function toJsonMap(candidate: Object | undefined): JsonMap | undefined {
  if (!candidate || Array.isArray(candidate)) {
    return undefined
  }
  return candidate as JsonMap
}

import { securityAudit } from '@kit.DeviceSecurityKit'
import { LogEntry, LogEventType, LogField, LogFieldValue } from '../../../models/LogModels'
import { LooseRecord, LooseValue } from '../../../types/LooseValueTypes'
import { LogPathUtils } from '../../../utils/LogPathUtils'
import {
  pickNumberFromRecords as pickNumber,
  pickStringFromRecords as pickString
} from '../../../utils/ValuePicker'
import { generateLogEntryId } from '../../../models/LogModels'
import { resolveAuditSourceTimestamp } from './LogTimestampResolver'
import { AuditEventDefinition, findAuditEventDefinition } from './LogAuditEventRegistry'
import {
  DEVICE_POWER_OFF_AUDIT_EVENT_ID,
  DEVICE_POWER_ON_AUDIT_EVENT_ID
} from '../../../constants/modules/LogAuditEventConstants'

interface ParsedAuditEvent {
  eventKey: string
  fields: LogField[]
  processName?: string
  pid?: number
  filePath?: string
  remoteAddr?: string
  rawEventName?: string
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
  const definition = findAuditEventDefinition(event.eventId)
  if (!definition) {
    return undefined
  }
  const contentJson = safeParseJson(event.content)
  const metadataJson = safeParseJson(event.metadata)
  const sources = collectSources(contentJson, metadataJson)
  const timestamp = resolveTimestamp(event, definition.eventType, contentJson, nowProvider)
  const parsed = parseByKind(definition, event, sources, contentJson, metadataJson)
  return {
    id: generateLogEntryId(),
    timestamp,
    eventType: definition.eventType,
    eventKey: parsed.eventKey,
    detail: buildSearchDetail(parsed.eventKey, parsed.fields, parsed.processName, parsed.filePath),
    processName: parsed.processName,
    pid: parsed.pid,
    uid: event.userId,
    filePath: parsed.filePath,
    remoteAddr: parsed.remoteAddr,
    sourceEventId: event.eventId,
    rawEventName: parsed.rawEventName,
    fields: parsed.fields,
    rawPayload: (event.content || event.metadata) ? {
      content: event.content || undefined,
      metadata: event.metadata || undefined,
      truncated: false
    } : undefined
  }
}

function parseByKind(
  definition: AuditEventDefinition,
  event: securityAudit.AuditEvent,
  sources: LooseRecord[],
  contentJson?: LooseRecord,
  metadataJson?: LooseRecord
): ParsedAuditEvent {
  switch (definition.parserKind) {
    case 'file': return parseFile(definition, sources, event.content || '', event.metadata)
    case 'account': return parseAccount(definition, sources, contentJson, metadataJson)
    case 'permission': return parsePermission(definition, sources, contentJson, metadataJson)
    case 'power': return parsePower(definition, event)
    case 'crash': return parseCrash(definition, sources)
    default: return parseGenericAudit(definition, event, sources)
  }
}

function parseFile(
  definition: AuditEventDefinition,
  sources: LooseRecord[],
  content: string,
  metadata?: string
): ParsedAuditEvent {
  const pathInfo = resolveFileAuditPathInfo(content, metadata, sources)
  const fields: LogField[] = []
  appendField(fields, 'event.action', pickString(sources, ['event_name', 'eventName', 'name', 'action', 'operation']))
  appendField(fields, 'object.file_path', pathInfo.primaryPath)
  appendField(fields, 'change.old_path', pathInfo.oldPath)
  appendField(fields, 'change.new_path', pathInfo.newPath)
  appendField(fields, 'object.file_size', pickNumber(sources, ['file_size', 'size']))
  appendField(fields, 'object.file_mode', pickNumber(sources, ['file_mode']))
  appendField(fields, 'change.new_mode', pickNumber(sources, ['file_newmode']))
  appendField(fields, 'change.owner_uid', pickNumber(sources, ['file_owneruid']))
  appendField(fields, 'change.owner_gid', pickNumber(sources, ['file_ownergid']))
  appendField(fields, 'change.new_owner_uid', pickNumber(sources, ['file_newuid']))
  appendField(fields, 'change.new_owner_gid', pickNumber(sources, ['file_newgid']))
  appendField(fields, 'change.xattr_name', pickString(sources, ['file_xattrname']))
  appendActorFields(fields, sources)
  appendOutcomeFields(fields, sources)
  return buildParsed(definition.defaultEventKey, fields, sources, pathInfo.primaryPath)
}

function parseAccount(
  definition: AuditEventDefinition,
  sources: LooseRecord[],
  contentJson?: LooseRecord,
  metadataJson?: LooseRecord
): ParsedAuditEvent {
  const caller = findNestedRecord([contentJson, metadataJson], 'caller')
  const accountSources = compactSources(caller, ...sources)
  const fields: LogField[] = []
  appendField(fields, 'object.user_name', pickString(accountSources, ['userName', 'user_name']))
  appendField(fields, 'object.user_id', pickNumber(accountSources, ['userId', 'user_id']))
  appendField(fields, 'actor.process_name', pickString(accountSources, ['CALLER_NAME', 'CALLER_PNAMEID', 'PNAMEID']))
  appendField(fields, 'event.auth_type', firstValue(accountSources, ['AUTH_TYPE']))
  appendField(fields, 'event.outcome', firstValue(accountSources, ['AUTH_RESULT', 'RESULT', 'RESULT_CODE']))
  appendField(fields, 'event.duration', pickNumber(accountSources, ['AUTH_TIME_SPAN']))
  return buildParsed(definition.defaultEventKey, fields, accountSources)
}

function parsePermission(
  definition: AuditEventDefinition,
  sources: LooseRecord[],
  contentJson?: LooseRecord,
  metadataJson?: LooseRecord
): ParsedAuditEvent {
  const extra = findNestedRecord([contentJson, metadataJson], 'extra')
  const permission = findNestedRecord([extra, contentJson, metadataJson], 'newPermission')
  const permissionSources = compactSources(permission, extra, ...sources)
  const fields: LogField[] = []
  appendField(fields, 'object.bundle_name', pickString(permissionSources, ['bundleName', 'bundle_name']))
  appendField(fields, 'change.permission_name', pickString(permissionSources, ['PermissionName', 'permissionName', 'name']))
  appendField(fields, 'change.permission_state', firstValue(permissionSources, ['PermissionState', 'permissionState', 'state']))
  appendActorFields(fields, permissionSources)
  appendOutcomeFields(fields, permissionSources)
  return buildParsed(definition.defaultEventKey, fields, permissionSources)
}

function parsePower(definition: AuditEventDefinition, event: securityAudit.AuditEvent): ParsedAuditEvent {
  return {
    eventKey: definition.defaultEventKey,
    fields: [],
    rawEventName: event.eventId === DEVICE_POWER_ON_AUDIT_EVENT_ID ? 'DEVICE_POWER_ON' :
      (event.eventId === DEVICE_POWER_OFF_AUDIT_EVENT_ID ? 'DEVICE_POWER_OFF' : undefined)
  }
}

function parseCrash(definition: AuditEventDefinition, sources: LooseRecord[]): ParsedAuditEvent {
  const fields: LogField[] = []
  appendField(fields, 'event.reason', pickString(sources, ['reason', 'message', 'exception', 'summary']))
  appendField(fields, 'event.error_name', pickString(sources, ['errorName', 'error_name']))
  appendField(fields, 'event.error_message', pickString(sources, ['errorMessage', 'error_message']))
  appendField(fields, 'event.top_stack', pickString(sources, ['topStack', 'top_stack', 'stackTrace', 'stack_trace', 'stack']))
  appendActorFields(fields, sources)
  return buildParsed(definition.defaultEventKey, fields, sources)
}

function parseGenericAudit(
  definition: AuditEventDefinition,
  event: securityAudit.AuditEvent,
  sources: LooseRecord[]
): ParsedAuditEvent {
  let eventKey = definition.defaultEventKey
  const objectInfo = pickString(sources, ['objectInfo'])
  const subType = pickNumber(sources, ['subType', 'sub_type'])
  if (event.eventId === securityAudit.NotifyEvent.APP) {
    eventKey = subType === 0 ? 'app.start' : (subType === 1 ? 'app.exit' : eventKey)
  } else if (event.eventId === securityAudit.NotifyEvent.PROCESS) {
    eventKey = subType === 2 ? 'process.create' : (subType === -1 ? 'process.exit' : eventKey)
  } else if (event.eventId === securityAudit.NotifyEvent.EDM) {
    const operationType = pickNumber(sources, ['type'])
    eventKey = operationType === 0 ? 'edm.policy_read' : (operationType === 1 ? 'edm.policy_change' : eventKey)
  }
  const fields: LogField[] = []
  appendField(fields, 'event.action', pickString(sources, ['action', 'eventAction', 'event_action', 'operation', 'op', 'state']))
  appendOutcomeFields(fields, sources)
  appendField(fields, 'event.risk_level', firstValue(sources, ['riskLevel', 'risk_level', 'RISK_LEVEL']))
  appendField(fields, 'object.application', pickString(sources, ['appName', 'applicationName', 'application_name']) ||
    (event.eventId === securityAudit.NotifyEvent.APP ? objectInfo : undefined))
  appendField(fields, 'object.bundle_name', pickString(sources, ['bundleName', 'bundle_name']))
  appendField(fields, 'object.process_name', pickString(sources, ['procName', 'proc_name', 'processName', 'process_name', 'cmdline']) ||
    (event.eventId === securityAudit.NotifyEvent.PROCESS ? objectInfo : undefined))
  appendField(fields, 'object.domain', pickString(sources, ['domain', 'host', 'hostname', 'dnsName', 'dns_name']))
  appendField(fields, 'object.device', pickString(sources, ['deviceName', 'device_name', 'deviceType', 'device_type']))
  appendField(fields, 'object.policy', event.eventId === securityAudit.NotifyEvent.EDM ? objectInfo : undefined)
  appendField(fields, 'object.file_path', pickString(sources, ['filePath', 'file_path', 'exePath', 'exe_path', 'path']))
  if (event.eventId === securityAudit.NotifyEvent.EDM) {
    appendField(fields, 'edm.operation_type', pickNumber(sources, ['type']))
  }
  appendField(fields, 'change.permission_name', pickString(sources, ['permissionName', 'permission_name']))
  appendActorFields(fields, sources)
  return buildParsed(eventKey, fields, sources)
}

function buildParsed(eventKey: string, fields: LogField[], sources: LooseRecord[], filePath?: string): ParsedAuditEvent {
  return {
    eventKey,
    fields,
    processName: pickString(sources, [
      'processName', 'procName', 'proc_name', 'process', 'process_name', 'cmdline', 'bundleName', 'bundle_name',
      'CALLER_NAME', 'CALLER_PNAMEID', 'PNAMEID'
    ]),
    pid: pickNumber(sources, ['pid', 'processId', 'process_id']),
    filePath,
    remoteAddr: pickString(sources, [
      'remoteAddress', 'remoteAddr', 'remote_addr', 'remoteIp', 'remote_ip', 'dstAddr', 'dst_addr', 'dstIp', 'dst_ip'
    ]),
    rawEventName: pickString(sources, ['event_name', 'eventName', 'name', 'name_', 'EVENT_NAME'])
  }
}

function appendActorFields(fields: LogField[], sources: LooseRecord[]): void {
  appendField(fields, 'actor.application', pickString(sources, ['callerName', 'caller_name', 'CALLER_NAME']))
  appendField(fields, 'actor.bundle_name', pickString(sources, ['callerBundleName', 'caller_bundle_name']))
  appendField(fields, 'actor.process_name', pickString(sources, ['processName', 'procName', 'proc_name', 'process_name', 'cmdline']))
}

function appendOutcomeFields(fields: LogField[], sources: LooseRecord[]): void {
  appendField(fields, 'event.outcome', firstValue(sources, [
    'outcome', 'result', 'status', 'decision', 'actionResult', 'action_result', 'AUTH_RESULT', 'RESULT', 'RESULT_CODE'
  ]))
}

function appendField(fields: LogField[], key: string, value?: LogFieldValue): void {
  if (value === undefined || (typeof value === 'string' && value.trim().length === 0) ||
    (typeof value === 'number' && !Number.isFinite(value)) || fields.some((field: LogField): boolean => field.key === key)) {
    return
  }
  fields.push({ key, value: typeof value === 'string' ? value.trim() : value })
}

function firstValue(sources: LooseRecord[], keys: string[]): LogFieldValue | undefined {
  for (const source of sources) {
    for (const key of keys) {
      const value = source[key]
      if (typeof value === 'string' && value.trim().length > 0) return value.trim()
      if (typeof value === 'number' && Number.isFinite(value)) return value
      if (typeof value === 'boolean') return value
      if (Array.isArray(value)) {
        const first = (value as LooseValue[]).find((item: LooseValue): boolean =>
          typeof item === 'string' || typeof item === 'number' || typeof item === 'boolean')
        if (typeof first === 'string' || typeof first === 'number' || typeof first === 'boolean') return first
      }
    }
  }
  return undefined
}

function buildSearchDetail(eventKey: string, fields: LogField[], processName?: string, filePath?: string): string {
  const parts: string[] = [eventKey]
  appendSearchPart(parts, filePath)
  const preferredKeys = [
    'object.application', 'object.bundle_name', 'object.process_name', 'object.user_name', 'object.domain',
    'object.device', 'object.policy', 'change.permission_name', 'event.action'
  ]
  for (const key of preferredKeys) {
    const field = fields.find((item: LogField): boolean => item.key === key)
    if (field) appendSearchPart(parts, `${field.value}`)
  }
  appendSearchPart(parts, processName)
  return parts.filter((value: string, index: number): boolean => parts.indexOf(value) === index).join(' | ')
}

function appendSearchPart(parts: string[], value?: string): void {
  const normalized = (value || '').trim()
  if (normalized.length > 0) parts.push(normalized)
}

function resolveTimestamp(
  event: securityAudit.AuditEvent,
  eventType: LogEventType,
  contentJson: LooseRecord | undefined,
  nowProvider: () => number
): number {
  if (eventType === LogEventType.POWER && contentJson) {
    const happenTime = pickNumber([contentJson], ['happenTime', 'happen_time'])
    if (happenTime !== undefined && happenTime > 0) return happenTime
  }
  return resolveAuditSourceTimestamp(event.timestamp || '', nowProvider)
}

function resolveFileAuditPathInfo(content: string, metadata: string | undefined, sources: LooseRecord[]): FileAuditPathInfo {
  const newPath = pickString(sources, ['file_newpath', 'file_new_path', 'newPath', 'new_path', 'targetPath', 'target_path', 'dstPath', 'dst_path'])
  const directPath = pickString(sources, ['filePath', 'file_path', 'path', 'uri', 'fileUri', 'file_uri'])
  const oldPath = pickString(sources, ['file_oldpath', 'file_old_path', 'oldPath', 'old_path', 'srcPath', 'src_path'])
  const scanned = LogPathUtils.extractRawAuditPath(newPath || directPath || oldPath, [content, metadata])
  return {
    primaryPath: LogPathUtils.normalizePathCandidate(scanned, true),
    oldPath: LogPathUtils.normalizePathCandidate(oldPath, true),
    newPath: LogPathUtils.normalizePathCandidate(newPath, true)
  }
}

function collectSources(content?: LooseRecord, metadata?: LooseRecord): LooseRecord[] {
  const result: LooseRecord[] = []
  const append = (source?: LooseRecord): void => {
    if (!source) return
    result.push(source)
    const extra = findNestedRecord([source], 'extra')
    if (extra) result.push(extra)
    const nestedMetadata = findNestedRecord([source], 'metadata')
    if (nestedMetadata) result.push(nestedMetadata)
    const objectInfo = findNestedRecord([source], 'objectInfo')
    if (objectInfo) result.push(objectInfo)
    const caller = findNestedRecord([source], 'caller')
    if (caller) result.push(caller)
  }
  append(content)
  append(metadata)
  return result
}

function compactSources(...sources: Array<LooseRecord | undefined>): LooseRecord[] {
  return sources.filter((source: LooseRecord | undefined): boolean => source !== undefined) as LooseRecord[]
}

function findNestedRecord(sources: Array<LooseRecord | undefined>, key: string): LooseRecord | undefined {
  for (const source of sources) {
    if (!source) continue
    const value = source[key]
    if (typeof value === 'string') {
      const parsed = safeParseJson(value)
      if (parsed) return parsed
    } else if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as LooseRecord
    }
  }
  return undefined
}

function safeParseJson(value?: string): LooseRecord | undefined {
  if (!value) return undefined
  try {
    const parsed = JSON.parse(value) as Object
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as LooseRecord : undefined
  } catch {
    return undefined
  }
}

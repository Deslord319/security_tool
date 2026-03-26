import { securityAudit } from '@kit.DeviceSecurityKit'
import { Environment } from '@kit.CoreFileKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { LogPathUtils } from '../utils/LogPathUtils'
import {
  LogEntry,
  LogEventType,
  LogEventResult,
  LogAuditDiagnostics,
  LogEventTypeDiag,
  AuditSubscribeMode,
  AuditFallbackReason,
  ALL_LOG_EVENT_TYPES,
  generateLogEntryId
} from '../models/DataModels'

const TAG = 'LogAuditService'
const DOMAIN = 0x0006
const FILE_FILTER_UNSUPPORTED_CODE = 1012000005
const FILE_EVENT_IDS: number[] = [
  securityAudit.NotifyEvent.FILE,
  securityAudit.NotifyEvent.FILE_INTERCEPTED,
  securityAudit.NotifyEvent.KIA_CREATE,
  securityAudit.NotifyEvent.KIA_READ,
  securityAudit.NotifyEvent.KIA_VARIANT,
  securityAudit.NotifyEvent.KIA_INTERCEPT
]

export type LogEntryCallback = (entry: LogEntry) => void

type JsonField = string | number | boolean | Object | undefined
type JsonMap = Record<string, JsonField>

interface AuditClientCompat {
  subscribe(eventIds: number[]): void
  unsubscribe(eventIds: number[]): void
  addFilter?(eventId: number, filter: securityAudit.Filter): void
}

interface SubscribePathResult {
  successCount: number
  failedEventIds: number[]
  shouldFallback: boolean
  fallbackReason: AuditFallbackReason
}

interface ClientCreateResult {
  client: AuditClientCompat | null
  fallbackReason: AuditFallbackReason
}

interface ParsedAuditPayload {
  detail: string
  result: LogEventResult
  processName?: string
  pid?: number
  filePath?: string
  remoteAddr?: string
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
}

export class LogAuditService {
  private static isSubscribed: boolean = false
  private static callback: LogEntryCallback | null = null
  private static subscribedCallbacks: Map<number, (event: securityAudit.AuditEvent) => void> = new Map()
  private static client: AuditClientCompat | null = null
  private static clientSubscribedEventIds: number[] = []
  private static lastSubscribeErrorCode: number | undefined = undefined
  private static lastSubscribeFailedEventIds: number[] = []
  private static subscribeMode: AuditSubscribeMode = 'none'
  private static fallbackReason: AuditFallbackReason = 'none'
  private static lastModeSwitchAt: number | undefined = undefined
  private static nowProvider: () => number = () => Date.now()
  private static diagnosticsByType: Map<LogEventType, LogEventTypeDiag> = LogAuditService.createDiagnosticsMap()
  private static unknownEventIds: number[] = []
  private static diagnosticsUpdatedAt: number = LogAuditService.nowProvider()

  private static readonly EVENT_IDS_BY_TYPE: Map<LogEventType, number[]> = new Map<LogEventType, number[]>([
    [LogEventType.FILE, FILE_EVENT_IDS],
    [LogEventType.ACCOUNT, [securityAudit.NotifyEvent.ACCOUNT]],
    [LogEventType.PERMISSION, [securityAudit.NotifyEvent.PERMISSION]]
  ])
  private static readonly EVENT_TYPE_BY_ID: Map<number, LogEventType> = LogAuditService.buildEventTypeById()
  private static readonly FILE_FILTER_PREFIXES: string[] = LogAuditService.buildFileFilterPrefixes()

  static subscribe(onLogEntry: LogEntryCallback, eventTypes?: LogEventType[]): boolean {
    if (LogAuditService.isSubscribed) {
      LogAuditService.callback = onLogEntry
      hilog.warn(DOMAIN, TAG, 'Already subscribed to audit events')
      return true
    }

    try {
      LogAuditService.callback = onLogEntry
      LogAuditService.lastSubscribeErrorCode = undefined
      LogAuditService.lastSubscribeFailedEventIds = []
      LogAuditService.fallbackReason = 'none'

      let auditTypes = LogAuditService.normalizeAuditTypes(eventTypes)
      let eventIds = LogAuditService.mapTypesToIds(auditTypes)
      LogAuditService.resetSubscriptionDiagnostics(auditTypes)
      if (eventIds.length === 0) {
        LogAuditService.callback = null
        LogAuditService.lastSubscribeErrorCode = 401
        LogAuditService.setSubscribeMode('none', 'none')
        return false
      }

      let clientResult = LogAuditService.subscribeWithClient(eventIds)
      if (clientResult.shouldFallback) {
        LogAuditService.resetSubscriptionDiagnostics(auditTypes)
        let legacyResult = LogAuditService.subscribeWithLegacyOnOff(eventIds)
        LogAuditService.lastSubscribeFailedEventIds = legacyResult.failedEventIds
        LogAuditService.isSubscribed = legacyResult.successCount > 0
        LogAuditService.setSubscribeMode(LogAuditService.isSubscribed ? 'legacy' : 'none', clientResult.fallbackReason)
        if (!LogAuditService.isSubscribed) {
          LogAuditService.callback = null
          return false
        }
        return true
      }

      LogAuditService.lastSubscribeFailedEventIds = clientResult.failedEventIds
      LogAuditService.isSubscribed = clientResult.successCount > 0
      LogAuditService.setSubscribeMode(LogAuditService.isSubscribed ? 'client' : 'none', 'none')
      if (!LogAuditService.isSubscribed) {
        LogAuditService.callback = null
        return false
      }
      return true
    } catch (err) {
      LogAuditService.lastSubscribeErrorCode = LogAuditService.extractErrorCode(err as Object)
      LogAuditService.unsubscribeInternal()
      LogAuditService.callback = null
      LogAuditService.setSubscribeMode('none', 'none')
      hilog.error(DOMAIN, TAG, `subscribe failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static unsubscribe(): boolean {
    if (!LogAuditService.isSubscribed) {
      return true
    }
    try {
      let ok = LogAuditService.unsubscribeInternal()
      LogAuditService.callback = null
      LogAuditService.lastSubscribeErrorCode = undefined
      LogAuditService.lastSubscribeFailedEventIds = []
      LogAuditService.markAllUnsubscribed()
      LogAuditService.setSubscribeMode('none', 'none')
      return ok
    } catch (err) {
      hilog.error(DOMAIN, TAG, `unsubscribe failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static getSubscriptionStatus(): boolean {
    return LogAuditService.isSubscribed
  }

  static getLastSubscribeErrorCode(): number | undefined {
    return LogAuditService.lastSubscribeErrorCode
  }

  static getLastSubscribeFailedEventIds(): number[] {
    return [...LogAuditService.lastSubscribeFailedEventIds]
  }

  static getSubscribeMode(): AuditSubscribeMode {
    return LogAuditService.subscribeMode
  }

  static getFallbackReason(): AuditFallbackReason {
    return LogAuditService.fallbackReason
  }

  static getDiagnostics(): LogAuditDiagnostics {
    let byType = new Map<LogEventType, LogEventTypeDiag>()
    for (let type of ALL_LOG_EVENT_TYPES) {
      let diag = LogAuditService.ensureDiag(type)
      byType.set(type, {
        type: diag.type,
        subscribed: diag.subscribed,
        failedEventIds: [...diag.failedEventIds],
        lastSeenAt: diag.lastSeenAt,
        seenCount: diag.seenCount,
        lastErrorCode: diag.lastErrorCode,
        preFilterUnsupportedEventIds: [...(diag.preFilterUnsupportedEventIds || [])],
        preFilterFailedEventIds: [...(diag.preFilterFailedEventIds || [])],
        preFilterLastErrorCode: diag.preFilterLastErrorCode,
        droppedNoPathCount: diag.droppedNoPathCount,
        droppedPrefixMismatchCount: diag.droppedPrefixMismatchCount,
        lastDropReason: diag.lastDropReason
      })
    }

    return {
      byType: byType,
      unknownEventIds: [...LogAuditService.unknownEventIds],
      subscribeMode: LogAuditService.subscribeMode,
      fallbackReason: LogAuditService.fallbackReason,
      lastModeSwitchAt: LogAuditService.lastModeSwitchAt,
      lastUpdatedAt: LogAuditService.diagnosticsUpdatedAt
    }
  }

  static resetDiagnostics(): void {
    LogAuditService.diagnosticsByType = LogAuditService.createDiagnosticsMap()
    LogAuditService.unknownEventIds = []
    LogAuditService.touchDiagnostics()
  }

  private static subscribeWithClient(eventIds: number[]): SubscribePathResult {
    let createResult = LogAuditService.tryCreateClient(LogAuditService.createAuditEventCallback())
    if (!createResult.client) {
      return { successCount: 0, failedEventIds: [], shouldFallback: true, fallbackReason: createResult.fallbackReason }
    }

    let successCount = 0
    let failedEventIds: number[] = []
    let subscribedIds: number[] = []
    for (let eventId of eventIds) {
      try {
        createResult.client.subscribe([eventId])
        subscribedIds.push(eventId)
        successCount += 1
        LogAuditService.markSubscribeSuccess(eventId)
        LogAuditService.tryAttachFilePrefixFilter(createResult.client, eventId)
      } catch (err) {
        let code = LogAuditService.extractErrorCode(err as Object)
        if (LogAuditService.lastSubscribeErrorCode === undefined) {
          LogAuditService.lastSubscribeErrorCode = code
        }
        if (LogAuditService.isApiUnavailableError(err as Object)) {
          LogAuditService.releaseClient(createResult.client, subscribedIds)
          return { successCount: 0, failedEventIds: [], shouldFallback: true, fallbackReason: 'new_api_unavailable' }
        }
        failedEventIds.push(eventId)
        LogAuditService.markSubscribeFailure(eventId, code)
      }
    }

    if (successCount <= 0) {
      LogAuditService.releaseClient(createResult.client, subscribedIds)
      return { successCount: 0, failedEventIds, shouldFallback: false, fallbackReason: 'none' }
    }

    LogAuditService.client = createResult.client
    LogAuditService.clientSubscribedEventIds = subscribedIds
    return { successCount, failedEventIds, shouldFallback: false, fallbackReason: 'none' }
  }

  private static subscribeWithLegacyOnOff(eventIds: number[]): SubscribePathResult {
    let successCount = 0
    let failedEventIds: number[] = []
    for (let eventId of eventIds) {
      let auditInfo: securityAudit.AuditEventInfo = { eventId: eventId }
      let eventCallback = LogAuditService.createAuditEventCallback()
      try {
        securityAudit.on('auditEventOccur', auditInfo, eventCallback)
        LogAuditService.subscribedCallbacks.set(eventId, eventCallback)
        successCount += 1
        LogAuditService.markSubscribeSuccess(eventId)
      } catch (err) {
        let code = LogAuditService.extractErrorCode(err as Object)
        if (LogAuditService.lastSubscribeErrorCode === undefined) {
          LogAuditService.lastSubscribeErrorCode = code
        }
        failedEventIds.push(eventId)
        LogAuditService.markSubscribeFailure(eventId, code)
      }
    }
    return { successCount, failedEventIds, shouldFallback: false, fallbackReason: 'none' }
  }

  private static createAuditEventCallback(): (event: securityAudit.AuditEvent) => void {
    return (event: securityAudit.AuditEvent) => {
      let entry = LogAuditService.parseAuditEvent(event)
      if (entry && LogAuditService.callback) {
        LogAuditService.callback(entry)
      }
    }
  }

  private static tryCreateClient(eventCallback: (event: securityAudit.AuditEvent) => void): ClientCreateResult {
    try {
      let clientValue = securityAudit.newClient(eventCallback) as AuditClientCompat
      if (!clientValue || typeof clientValue.subscribe !== 'function' || typeof clientValue.unsubscribe !== 'function') {
        return { client: null, fallbackReason: 'new_api_unavailable' }
      }
      return { client: clientValue, fallbackReason: 'none' }
    } catch (err) {
      return {
        client: null,
        fallbackReason: LogAuditService.isApiUnavailableError(err as Object) ? 'new_api_unavailable' : 'new_api_init_failed'
      }
    }
  }

  private static parseAuditEvent(event: securityAudit.AuditEvent): LogEntry | undefined {
    let mappedType = LogAuditService.EVENT_TYPE_BY_ID.get(event.eventId)
    if (mappedType === undefined) {
      LogAuditService.recordUnknownEventId(event.eventId)
      return undefined
    }

    let parsed = LogAuditService.parseAuditPayload(event.content || '', event.metadata)
    if (mappedType === LogEventType.FILE && !LogAuditService.isAllowedUserFileEvent(parsed.filePath)) {
      return undefined
    }

    LogAuditService.markEventSeen(mappedType)
    return {
      id: generateLogEntryId(),
      timestamp: LogAuditService.parseTimestamp(event.timestamp || ''),
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

  private static parseAuditPayload(content: string, metadata?: string): ParsedAuditPayload {
    let contentJson = LogAuditService.safeParseJson(content)
    let metadataJson = LogAuditService.safeParseJson(metadata)
    let sources = LogAuditService.collectJsonSources(contentJson, metadataJson)
    let rawOutcome = LogAuditService.pickFirstString(sources, ['outcome', 'result', 'status', 'decision', 'actionResult', 'action_result'])

    return {
      detail: LogAuditService.pickFirstString(sources, ['description', 'message', 'detail', 'msg', 'event_desc', 'summary']) ||
        content || metadata || '安全审计事件',
      result: LogAuditService.mapResult(rawOutcome),
      processName: LogAuditService.pickFirstString(sources, ['processName', 'procName', 'proc_name', 'cmdline', 'process', 'process_name', 'bundleName', 'bundle_name']),
      pid: LogAuditService.pickFirstNumber(sources, ['pid', 'processId', 'process_id']),
      filePath: LogAuditService.resolveAuditFilePath(content, metadata, sources),
      remoteAddr: LogAuditService.pickFirstString(sources, ['remoteAddress', 'remoteAddr', 'remote_addr', 'remoteIp', 'remote_ip', 'dstAddr', 'dst_addr', 'dstIp', 'dst_ip', 'peerAddr', 'peer_addr']),
      rawEventName: LogAuditService.pickFirstString(sources, ['event_name', 'eventName', 'name']),
      rawOutcome: rawOutcome,
      rawAction: LogAuditService.pickFirstString(sources, ['action', 'eventAction', 'event_action', 'operation', 'op', 'state'])
    }
  }

  private static resolveAuditFilePath(content: string, metadata: string | undefined, sources: JsonMap[]): string | undefined {
    let structured = LogAuditService.pickFirstString(sources, [
      'targetPath', 'target_path', 'dstPath', 'dst_path', 'uri', 'fileUri', 'file_uri',
      'filePath', 'file_path', 'path', 'srcPath', 'src_path'
    ])
    return LogPathUtils.resolveAuditFilePath(structured, [content, metadata])
  }

  private static tryAttachFilePrefixFilter(client: AuditClientCompat, eventId: number): void {
    if (!FILE_EVENT_IDS.includes(eventId)) {
      return
    }
    if (typeof client.addFilter !== 'function') {
      LogAuditService.markPreFilterUnsupported(eventId)
      return
    }

    let filter: securityAudit.Filter = {
      isInclude: true,
      type: securityAudit.FilterType.FILE_PATH_PREFIX,
      values: [...LogAuditService.FILE_FILTER_PREFIXES]
    }
    try {
      client.addFilter(eventId, filter)
    } catch (err) {
      let code = LogAuditService.extractErrorCode(err as Object)
      if (code === FILE_FILTER_UNSUPPORTED_CODE) {
        LogAuditService.markPreFilterUnsupported(eventId)
        return
      }
      LogAuditService.markPreFilterFailure(eventId, code)
    }
  }

  private static isAllowedUserFileEvent(candidatePath?: string): boolean {
    if (!candidatePath) {
      LogAuditService.recordFileDrop('no_path', '未提取到用户文件路径')
      return false
    }
    let normalized = LogPathUtils.normalizePathCandidate(candidatePath)
    if (!normalized) {
      LogAuditService.recordFileDrop('no_path', '文件路径归一化失败')
      return false
    }
    if (LogPathUtils.hasAllowedPrefix(normalized, LogAuditService.FILE_FILTER_PREFIXES)) {
      return true
    }
    LogAuditService.recordFileDrop('prefix_mismatch', `非用户文件路径: ${normalized}`)
    return false
  }

  private static buildFileFilterPrefixes(): string[] {
    return LogPathUtils.buildFileFilterPrefixes([
      'file://docs/storage/Users/currentUser/',
      'file://media/',
      '/storage/Users/currentUser/'
    ], [
      Environment.getUserDownloadDir(),
      Environment.getUserDocumentDir(),
      Environment.getUserDesktopDir()
    ])
  }


  private static parseTimestamp(ts: string): number {
    if (ts.length < 14) {
      return LogAuditService.nowProvider()
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

  private static mapResult(rawOutcome?: string): LogEventResult {
    if (!rawOutcome) {
      return LogEventResult.SUCCESS
    }
    let normalized = rawOutcome.toLowerCase()
    if (normalized.includes('blocked') || normalized.includes('deny') || normalized.includes('intercept')) {
      return LogEventResult.BLOCKED
    }
    if (normalized.includes('failed') || normalized.includes('error') || normalized.includes('reject')) {
      return LogEventResult.FAILED
    }
    return LogEventResult.SUCCESS
  }

  private static normalizeAuditTypes(eventTypes?: LogEventType[]): LogEventType[] {
    let source = eventTypes && eventTypes.length > 0 ? eventTypes : ALL_LOG_EVENT_TYPES
    let result: LogEventType[] = []
    for (let type of source) {
      if (LogAuditService.EVENT_IDS_BY_TYPE.has(type) && !result.includes(type)) {
        result.push(type)
      }
    }
    return result
  }

  private static mapTypesToIds(eventTypes?: LogEventType[]): number[] {
    let ids: number[] = []
    for (let type of LogAuditService.normalizeAuditTypes(eventTypes)) {
      let mappedIds = LogAuditService.EVENT_IDS_BY_TYPE.get(type) || []
      for (let eventId of mappedIds) {
        if (!ids.includes(eventId)) {
          ids.push(eventId)
        }
      }
    }
    return ids
  }

  private static buildEventTypeById(): Map<number, LogEventType> {
    let mapping: Map<number, LogEventType> = new Map()
    LogAuditService.EVENT_IDS_BY_TYPE.forEach((ids: number[], type: LogEventType) => {
      ids.forEach((eventId: number) => mapping.set(eventId, type))
    })
    return mapping
  }

  private static createDiagnosticsMap(): Map<LogEventType, LogEventTypeDiag> {
    let map = new Map<LogEventType, LogEventTypeDiag>()
    for (let type of ALL_LOG_EVENT_TYPES) {
      map.set(type, {
        type,
        subscribed: false,
        failedEventIds: [],
        seenCount: 0,
        preFilterUnsupportedEventIds: [],
        preFilterFailedEventIds: [],
        droppedNoPathCount: 0,
        droppedPrefixMismatchCount: 0
      })
    }
    return map
  }

  private static ensureDiag(type: LogEventType): LogEventTypeDiag {
    let existing = LogAuditService.diagnosticsByType.get(type)
    if (existing) {
      return existing
    }
    let created: LogEventTypeDiag = {
      type,
      subscribed: false,
      failedEventIds: [],
      seenCount: 0,
      preFilterUnsupportedEventIds: [],
      preFilterFailedEventIds: [],
      droppedNoPathCount: 0,
      droppedPrefixMismatchCount: 0
    }
    LogAuditService.diagnosticsByType.set(type, created)
    return created
  }

  private static resetSubscriptionDiagnostics(targetTypes: LogEventType[]): void {
    for (let type of ALL_LOG_EVENT_TYPES) {
      let diag = LogAuditService.ensureDiag(type)
      diag.subscribed = targetTypes.includes(type)
      diag.failedEventIds = []
      diag.lastErrorCode = undefined
      if (type === LogEventType.FILE) {
        diag.preFilterUnsupportedEventIds = []
        diag.preFilterFailedEventIds = []
        diag.preFilterLastErrorCode = undefined
        diag.droppedNoPathCount = 0
        diag.droppedPrefixMismatchCount = 0
        diag.lastDropReason = undefined
      }
    }
    LogAuditService.touchDiagnostics()
  }

  private static markSubscribeSuccess(eventId: number): void {
    let type = LogAuditService.EVENT_TYPE_BY_ID.get(eventId)
    if (type !== undefined) {
      LogAuditService.ensureDiag(type).subscribed = true
      LogAuditService.touchDiagnostics()
    }
  }

  private static markSubscribeFailure(eventId: number, code: number | undefined): void {
    let type = LogAuditService.EVENT_TYPE_BY_ID.get(eventId)
    if (type === undefined) {
      return
    }
    let diag = LogAuditService.ensureDiag(type)
    if (!diag.failedEventIds.includes(eventId)) {
      diag.failedEventIds.push(eventId)
    }
    diag.lastErrorCode = code
    LogAuditService.touchDiagnostics()
  }

  private static markPreFilterUnsupported(eventId: number): void {
    let diag = LogAuditService.ensureDiag(LogEventType.FILE)
    if (!(diag.preFilterUnsupportedEventIds || []).includes(eventId)) {
      diag.preFilterUnsupportedEventIds = [...(diag.preFilterUnsupportedEventIds || []), eventId]
    }
    LogAuditService.touchDiagnostics()
  }

  private static markPreFilterFailure(eventId: number, code: number | undefined): void {
    let diag = LogAuditService.ensureDiag(LogEventType.FILE)
    if (!(diag.preFilterFailedEventIds || []).includes(eventId)) {
      diag.preFilterFailedEventIds = [...(diag.preFilterFailedEventIds || []), eventId]
    }
    diag.preFilterLastErrorCode = code
    LogAuditService.touchDiagnostics()
  }

  private static recordFileDrop(kind: 'no_path' | 'prefix_mismatch', reason: string): void {
    let diag = LogAuditService.ensureDiag(LogEventType.FILE)
    if (kind === 'no_path') {
      diag.droppedNoPathCount = (diag.droppedNoPathCount || 0) + 1
    } else {
      diag.droppedPrefixMismatchCount = (diag.droppedPrefixMismatchCount || 0) + 1
    }
    diag.lastDropReason = reason
    LogAuditService.touchDiagnostics()
  }

  private static markEventSeen(type: LogEventType): void {
    let diag = LogAuditService.ensureDiag(type)
    diag.seenCount += 1
    diag.lastSeenAt = LogAuditService.nowProvider()
    LogAuditService.touchDiagnostics()
  }

  private static recordUnknownEventId(eventId: number): void {
    if (!LogAuditService.unknownEventIds.includes(eventId)) {
      LogAuditService.unknownEventIds.push(eventId)
      LogAuditService.touchDiagnostics()
    }
  }

  private static markAllUnsubscribed(): void {
    for (let type of ALL_LOG_EVENT_TYPES) {
      LogAuditService.ensureDiag(type).subscribed = false
    }
    LogAuditService.touchDiagnostics()
  }

  private static touchDiagnostics(): void {
    LogAuditService.diagnosticsUpdatedAt = LogAuditService.nowProvider()
  }

  private static collectJsonSources(contentJson?: JsonMap, metadataJson?: JsonMap): JsonMap[] {
    let result: JsonMap[] = []
    let append = (candidate?: JsonMap): void => {
      if (!candidate) {
        return
      }
      result.push(candidate)
      let extra = LogAuditService.extractNestedJson(candidate, 'extra')
      if (extra) {
        result.push(extra)
      }
      let metadata = LogAuditService.extractNestedJson(candidate, 'metadata')
      if (metadata) {
        result.push(metadata)
      }
    }
    append(contentJson)
    append(metadataJson)
    return result
  }

  private static safeParseJson(value: string | undefined): JsonMap | undefined {
    if (!value) {
      return undefined
    }
    try {
      let parsed = JSON.parse(value) as Object
      let record = LogAuditService.toJsonMap(parsed)
      if (record) {
        return record
      }
      return undefined
    } catch {
      return undefined
    }
  }

  private static extractNestedJson(source: JsonMap, key: string): JsonMap | undefined {
    let candidate = source[key]
    if (typeof candidate === 'string') {
      return LogAuditService.safeParseJson(candidate)
    }
    if (candidate && typeof candidate === 'object') {
      return LogAuditService.toJsonMap(candidate)
    }
    return undefined
  }

  private static pickFirstString(sources: JsonMap[], keys: string[]): string | undefined {
    for (let source of sources) {
      for (let key of keys) {
        let raw = source[key]
        if (typeof raw === 'string' && raw.trim().length > 0) {
          return raw.trim()
        }
      }
    }
    return undefined
  }

  private static pickFirstNumber(sources: JsonMap[], keys: string[]): number | undefined {
    for (let source of sources) {
      for (let key of keys) {
        let raw = source[key]
        if (typeof raw === 'number' && Number.isFinite(raw)) {
          return raw
        }
        if (typeof raw === 'string') {
          let parsed = Number(raw)
          if (Number.isFinite(parsed)) {
            return parsed
          }
        }
      }
    }
    return undefined
  }

  private static toJsonMap(candidate: Object | undefined): JsonMap | undefined {
    if (!candidate || Array.isArray(candidate)) {
      return undefined
    }
    return candidate as JsonMap
  }

  private static extractErrorCode(err: Object): number | undefined {
    let codeValue = (err as Record<string, Object>)['code']
    if (typeof codeValue === 'number') {
      return codeValue
    }
    if (typeof codeValue === 'string') {
      let parsed = Number(codeValue)
      return Number.isNaN(parsed) ? undefined : parsed
    }
    return undefined
  }

  private static extractErrorText(err: Object): string {
    let message = (err as Record<string, Object>)['message']
    if (typeof message === 'string' && message.trim().length > 0) {
      return message.toLowerCase()
    }
    return JSON.stringify(err).toLowerCase()
  }

  private static isApiUnavailableError(err: Object): boolean {
    let code = LogAuditService.extractErrorCode(err)
    if (code === 201 || code === 401) {
      return false
    }
    let text = LogAuditService.extractErrorText(err)
    return text.includes('is not a function') ||
      text.includes('not support') ||
      text.includes('not supported') ||
      text.includes('unsupported') ||
      text.includes('api not found') ||
      text.includes('method not found') ||
      (text.includes('undefined') && text.includes('newclient'))
  }

  private static releaseClient(client: AuditClientCompat | null, subscribedEventIds: number[]): void {
    if (!client) {
      return
    }
    try {
      if (subscribedEventIds.length > 0) {
        client.unsubscribe(subscribedEventIds)
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `unsubscribe failed: ${JSON.stringify(err)}`)
    }
    try {
      let deleteClient = securityAudit.deleteClient as (target: AuditClientCompat) => void
      deleteClient(client)
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `deleteClient failed: ${JSON.stringify(err)}`)
    }
  }

  private static setSubscribeMode(mode: AuditSubscribeMode, reason: AuditFallbackReason): void {
    if (LogAuditService.subscribeMode !== mode || LogAuditService.fallbackReason !== reason) {
      LogAuditService.lastModeSwitchAt = LogAuditService.nowProvider()
    }
    LogAuditService.subscribeMode = mode
    LogAuditService.fallbackReason = reason
    LogAuditService.touchDiagnostics()
  }

  private static unsubscribeInternal(): boolean {
    let ok = LogAuditService.unsubscribeClientInternal()
    if (!LogAuditService.unsubscribeLegacyInternal()) {
      ok = false
    }
    LogAuditService.client = null
    LogAuditService.clientSubscribedEventIds = []
    LogAuditService.subscribedCallbacks.clear()
    LogAuditService.isSubscribed = false
    return ok
  }

  private static unsubscribeClientInternal(): boolean {
    if (!LogAuditService.client) {
      return true
    }
    let ok = true
    try {
      if (LogAuditService.clientSubscribedEventIds.length > 0) {
        LogAuditService.client.unsubscribe(LogAuditService.clientSubscribedEventIds)
      }
    } catch (err) {
      ok = false
      hilog.warn(DOMAIN, TAG, `client unsubscribe failed: ${JSON.stringify(err)}`)
    }
    try {
      let deleteClient = securityAudit.deleteClient as (target: AuditClientCompat) => void
      deleteClient(LogAuditService.client)
    } catch (err) {
      ok = false
      hilog.warn(DOMAIN, TAG, `deleteClient failed: ${JSON.stringify(err)}`)
    }
    return ok
  }

  private static unsubscribeLegacyInternal(): boolean {
    let ok = true
    LogAuditService.subscribedCallbacks.forEach((callback, eventId) => {
      try {
        securityAudit.off('auditEventOccur', { eventId }, callback)
      } catch (err) {
        ok = false
        hilog.warn(DOMAIN, TAG, `legacy off failed eventId=${eventId}: ${JSON.stringify(err)}`)
      }
    })
    return ok
  }
}

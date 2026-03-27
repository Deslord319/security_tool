import { securityAudit } from '@kit.DeviceSecurityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import osAccount from '@ohos.account.osAccount'
import { LogPathUtils } from '../utils/LogPathUtils'
import {
  LogEntry,
  LogEventType,
  LogEventResult,
  ALL_LOG_EVENT_TYPES,
  generateLogEntryId
} from '../models/DataModels'

const TAG = 'LogAuditService'
const DOMAIN = 0x0006
const FILE_FILTER_UNSUPPORTED_CODE = 1012000005
const DEFAULT_FOREGROUND_USER_ID = 100
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
type AuditFallbackReason = 'new_api_unavailable' | 'new_api_init_failed' | 'none'

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
  rawFilePath?: string
  filePath?: string
  remoteAddr?: string
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
}

interface FileFilterContext {
  foregroundUserId: number
  prefix: string
}

export class LogAuditService {
  private static isSubscribed: boolean = false
  private static callback: LogEntryCallback | null = null
  private static subscribedCallbacks: Map<number, (event: securityAudit.AuditEvent) => void> = new Map()
  private static client: AuditClientCompat | null = null
  private static clientSubscribedEventIds: number[] = []
  private static lastSubscribeErrorCode: number | undefined = undefined
  private static lastSubscribeFailedEventIds: number[] = []
  private static nowProvider: () => number = () => Date.now()

  private static readonly EVENT_IDS_BY_TYPE: Map<LogEventType, number[]> = new Map<LogEventType, number[]>([
    [LogEventType.FILE, FILE_EVENT_IDS],
    [LogEventType.ACCOUNT, [securityAudit.NotifyEvent.ACCOUNT]],
    [LogEventType.PERMISSION, [securityAudit.NotifyEvent.PERMISSION]]
  ])
  private static readonly EVENT_TYPE_BY_ID: Map<number, LogEventType> = LogAuditService.buildEventTypeById()
  static async subscribe(onLogEntry: LogEntryCallback, eventTypes?: LogEventType[]): Promise<boolean> {
    if (LogAuditService.isSubscribed) {
      LogAuditService.callback = onLogEntry
      hilog.warn(DOMAIN, TAG, 'Already subscribed to audit events')
      return true
    }

    try {
      LogAuditService.callback = onLogEntry
      LogAuditService.lastSubscribeErrorCode = undefined
      LogAuditService.lastSubscribeFailedEventIds = []

      let eventIds = LogAuditService.mapTypesToIds(LogAuditService.normalizeAuditTypes(eventTypes))
      if (eventIds.length === 0) {
        LogAuditService.callback = null
        LogAuditService.lastSubscribeErrorCode = 401
        return false
      }

      let clientResult = await LogAuditService.subscribeWithClient(eventIds)
      if (clientResult.shouldFallback) {
        let legacyEventIds = eventIds.filter((eventId: number) => !FILE_EVENT_IDS.includes(eventId))
        let legacyResult = LogAuditService.subscribeWithLegacyOnOff(legacyEventIds)
        LogAuditService.lastSubscribeFailedEventIds = Array.from(new Set([
          ...clientResult.failedEventIds,
          ...legacyResult.failedEventIds
        ]))
        LogAuditService.isSubscribed = legacyResult.successCount > 0
        if (!LogAuditService.isSubscribed) {
          LogAuditService.callback = null
          return false
        }
        return true
      }

      LogAuditService.lastSubscribeFailedEventIds = clientResult.failedEventIds
      LogAuditService.isSubscribed = clientResult.successCount > 0
      if (!LogAuditService.isSubscribed) {
        LogAuditService.callback = null
        return false
      }
      return true
    } catch (err) {
      LogAuditService.lastSubscribeErrorCode = LogAuditService.extractErrorCode(err as Object)
      LogAuditService.unsubscribeInternal()
      LogAuditService.callback = null
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

  private static async subscribeWithClient(eventIds: number[]): Promise<SubscribePathResult> {
    let createResult = LogAuditService.tryCreateClient(LogAuditService.createAuditEventCallback())
    if (!createResult.client) {
      let failedEventIds = eventIds.filter((eventId: number) => FILE_EVENT_IDS.includes(eventId))
      return { successCount: 0, failedEventIds, shouldFallback: true, fallbackReason: createResult.fallbackReason }
    }

    let fileFilterContext = await LogAuditService.prepareFileFilterContext(eventIds)
    let successCount = 0
    let failedEventIds: number[] = []
    let subscribedIds: number[] = []
    for (let eventId of eventIds) {
      try {
        createResult.client.subscribe([eventId])
        let filterAttached = LogAuditService.tryAttachFilePrefixFilter(createResult.client, eventId, fileFilterContext)
        if (!filterAttached) {
          LogAuditService.unsubscribeClientEvent(createResult.client, eventId)
          failedEventIds.push(eventId)
          continue
        }
        subscribedIds.push(eventId)
        successCount += 1
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
      } catch (err) {
        let code = LogAuditService.extractErrorCode(err as Object)
        if (LogAuditService.lastSubscribeErrorCode === undefined) {
          LogAuditService.lastSubscribeErrorCode = code
        }
        failedEventIds.push(eventId)
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
      return undefined
    }

    let parsed = LogAuditService.parseAuditPayload(event.content || '', event.metadata)
    if (mappedType === LogEventType.FILE) {
      hilog.info(
        DOMAIN,
        TAG,
        `FILE event accepted: eventId=${event.eventId}, eventName=${parsed.rawEventName || '-'}, action=${parsed.rawAction || '-'}, result=${parsed.result}, rawPath=${parsed.rawFilePath || '-'}, normalizedPath=${parsed.filePath || '-'}`
      )
    }

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
    let rawFilePath = LogAuditService.resolveAuditRawFilePath(content, metadata, sources)
    let normalizedFilePath = LogPathUtils.normalizePathCandidate(rawFilePath)

    return {
      detail: LogAuditService.pickFirstString(sources, ['description', 'message', 'detail', 'msg', 'event_desc', 'summary']) ||
        content || metadata || '安全审计事件',
      result: LogAuditService.mapResult(rawOutcome),
      processName: LogAuditService.pickFirstString(sources, ['processName', 'procName', 'proc_name', 'cmdline', 'process', 'process_name', 'bundleName', 'bundle_name']),
      pid: LogAuditService.pickFirstNumber(sources, ['pid', 'processId', 'process_id']),
      rawFilePath: rawFilePath,
      filePath: normalizedFilePath,
      remoteAddr: LogAuditService.pickFirstString(sources, ['remoteAddress', 'remoteAddr', 'remote_addr', 'remoteIp', 'remote_ip', 'dstAddr', 'dst_addr', 'dstIp', 'dst_ip', 'peerAddr', 'peer_addr']),
      rawEventName: LogAuditService.pickFirstString(sources, ['event_name', 'eventName', 'name']),
      rawOutcome: rawOutcome,
      rawAction: LogAuditService.pickFirstString(sources, ['action', 'eventAction', 'event_action', 'operation', 'op', 'state'])
    }
  }

  private static resolveAuditRawFilePath(content: string, metadata: string | undefined, sources: JsonMap[]): string | undefined {
    let structured = LogAuditService.pickFirstString(sources, [
      'targetPath', 'target_path', 'dstPath', 'dst_path', 'uri', 'fileUri', 'file_uri',
      'filePath', 'file_path', 'path', 'srcPath', 'src_path'
    ])
    return LogPathUtils.extractRawAuditPath(structured, [content, metadata])
  }

  private static tryAttachFilePrefixFilter(
    client: AuditClientCompat,
    eventId: number,
    fileFilterContext?: FileFilterContext
  ): boolean {
    if (!FILE_EVENT_IDS.includes(eventId)) {
      return true
    }
    if (!fileFilterContext) {
      hilog.warn(DOMAIN, TAG, `skip FILE prefilter: eventId=${eventId}, reason=file_filter_context_unavailable`)
      return false
    }
    if (typeof client.addFilter !== 'function') {
      hilog.warn(DOMAIN, TAG, `skip FILE prefilter: eventId=${eventId}, reason=addFilter_unavailable`)
      return false
    }

    let filter: securityAudit.Filter = {
      isInclude: true,
      type: securityAudit.FilterType.FILE_PATH_PREFIX,
      values: [fileFilterContext.prefix]
    }
    try {
      client.addFilter(eventId, filter)
      hilog.info(
        DOMAIN,
        TAG,
        `FILE prefilter attached: eventId=${eventId}, foregroundUserId=${fileFilterContext.foregroundUserId}, prefix=${fileFilterContext.prefix}`
      )
      return true
    } catch (err) {
      let code = LogAuditService.extractErrorCode(err as Object)
      if (LogAuditService.lastSubscribeErrorCode === undefined) {
        LogAuditService.lastSubscribeErrorCode = code
      }
      hilog.warn(
        DOMAIN,
        TAG,
        `FILE prefilter attach failed: eventId=${eventId}, foregroundUserId=${fileFilterContext.foregroundUserId}, prefix=${fileFilterContext.prefix}, code=${code}, err=${JSON.stringify(err)}`
      )
      if (code === FILE_FILTER_UNSUPPORTED_CODE) {
        return false
      }
      return false
    }
  }

  private static async prepareFileFilterContext(eventIds: number[]): Promise<FileFilterContext | undefined> {
    if (!eventIds.some((eventId: number) => FILE_EVENT_IDS.includes(eventId))) {
      return undefined
    }

    let foregroundUserId = await LogAuditService.resolveForegroundUserId()
    let prefix = LogPathUtils.buildHmdfsAccountFilesPrefix(foregroundUserId)
    hilog.info(DOMAIN, TAG, `prepare FILE prefilter: foregroundUserId=${foregroundUserId}, prefix=${prefix}`)
    return { foregroundUserId, prefix }
  }

  private static async resolveForegroundUserId(): Promise<number> {
    try {
      let accountManager = osAccount.getAccountManager()
      let foregroundUserId = await accountManager.getForegroundOsAccountLocalId()
      hilog.info(DOMAIN, TAG, `resolved foreground userId=${foregroundUserId}`)
      return foregroundUserId
    } catch (err) {
      hilog.warn(
        DOMAIN,
        TAG,
        `resolve foreground userId failed, fallback=${DEFAULT_FOREGROUND_USER_ID}, err=${JSON.stringify(err)}`
      )
      return DEFAULT_FOREGROUND_USER_ID
    }
  }

  private static unsubscribeClientEvent(client: AuditClientCompat, eventId: number): void {
    try {
      client.unsubscribe([eventId])
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `unsubscribe event failed: eventId=${eventId}, err=${JSON.stringify(err)}`)
    }
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

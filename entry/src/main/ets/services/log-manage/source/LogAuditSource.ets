import { securityAudit } from '@kit.DeviceSecurityKit'
import osAccount from '@ohos.account.osAccount'
import { LogUtils } from '../../../utils/LogUtils'
import { LogPathUtils } from '../../../utils/LogPathUtils'
import { LogManageStrings } from '../../../constants/modules/LogManageStrings'
import {
  ALL_LOG_EVENT_TYPES,
  generateLogEntryId,
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../../models/DataModels'
import { AuditSubscribeResult, SourceStatus } from '../common/LogManagePorts'

const TAG = 'LogAuditSource'
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

type JsonField = string | number | boolean | Object | undefined
type JsonMap = Record<string, JsonField>
type LogEntryCallback = (entry: LogEntry) => void

interface AuditClientCompat {
  subscribe(eventIds: number[]): void
  unsubscribe(eventIds: number[]): void
  addFilter?(eventId: number, filter: securityAudit.Filter): void
}

interface ClientSubscribeResult {
  successCount: number
  failedEventIds: number[]
  unsupported: boolean
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

export class LogAuditSource {
  private static isSubscribed: boolean = false
  private static callback: LogEntryCallback | null = null
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
  private static readonly EVENT_TYPE_BY_ID: Map<number, LogEventType> = LogAuditSource.buildEventTypeById()

  static async subscribe(onEntry: (entry: LogEntry) => void, eventTypes?: LogEventType[]): Promise<AuditSubscribeResult> {
    if (LogAuditSource.isSubscribed) {
      LogAuditSource.callback = onEntry
      return LogAuditSource.buildSubscribeResult(true, [], 'ok', [...LogAuditSource.clientSubscribedEventIds])
    }

    try {
      LogAuditSource.callback = onEntry
      LogAuditSource.lastSubscribeErrorCode = undefined
      LogAuditSource.lastSubscribeFailedEventIds = []

      const eventIds = LogAuditSource.mapTypesToIds(LogAuditSource.normalizeAuditTypes(eventTypes))
      if (eventIds.length === 0) {
        LogAuditSource.callback = null
        LogAuditSource.lastSubscribeErrorCode = 401
        return LogAuditSource.buildSubscribeResult(false, [], 'permission_denied', [])
      }

      const clientResult = await LogAuditSource.subscribeWithClient(eventIds)
      LogAuditSource.lastSubscribeFailedEventIds = clientResult.failedEventIds
      LogAuditSource.isSubscribed = clientResult.successCount > 0
      if (!LogAuditSource.isSubscribed) {
        LogAuditSource.callback = null
        return LogAuditSource.buildSubscribeResult(
          false,
          clientResult.failedEventIds,
          clientResult.unsupported ? 'unsupported' : 'permission_denied',
          []
        )
      }
      return LogAuditSource.buildSubscribeResult(
        true,
        clientResult.failedEventIds,
        clientResult.failedEventIds.length > 0 ? 'partial' : 'ok',
        eventIds.filter((eventId: number) => !clientResult.failedEventIds.includes(eventId))
      )
    } catch (err) {
      LogAuditSource.lastSubscribeErrorCode = LogAuditSource.extractErrorCode(err as Object)
      LogAuditSource.unsubscribeInternal()
      LogAuditSource.callback = null
      LogUtils.error(TAG, `subscribe failed: ${JSON.stringify(err)}`)
      return LogAuditSource.buildSubscribeResult(false, [], 'permission_denied', [])
    }
  }

  static unsubscribe(): boolean {
    if (!LogAuditSource.isSubscribed) {
      return true
    }
    try {
      const ok = LogAuditSource.unsubscribeInternal()
      LogAuditSource.callback = null
      LogAuditSource.lastSubscribeErrorCode = undefined
      LogAuditSource.lastSubscribeFailedEventIds = []
      return ok
    } catch (err) {
      LogUtils.error(TAG, `unsubscribe failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  static getStatus(): SourceStatus {
    return {
      subscribed: LogAuditSource.isSubscribed,
      errorCode: LogAuditSource.lastSubscribeErrorCode
    }
  }

  private static buildSubscribeResult(
    success: boolean,
    failedEventIds: number[],
    code: 'ok' | 'unsupported' | 'permission_denied' | 'partial',
    subscribedEventIds: number[]
  ): AuditSubscribeResult {
    return {
      success,
      code,
      subscribedEventIds: subscribedEventIds,
      failedEventIds
    }
  }

  private static async subscribeWithClient(eventIds: number[]): Promise<ClientSubscribeResult> {
    const client = LogAuditSource.createClient(LogAuditSource.createAuditEventCallback())
    if (!client) {
      const result: ClientSubscribeResult = {
        successCount: 0,
        failedEventIds: [...eventIds],
        unsupported: true
      }
      return result
    }

    const fileFilterContext = await LogAuditSource.prepareFileFilterContext(eventIds)
    let successCount = 0
    const failedEventIds: number[] = []
    const subscribedIds: number[] = []
    for (const eventId of eventIds) {
      try {
        client.subscribe([eventId])
        const filterAttached = LogAuditSource.tryAttachFilePrefixFilter(client, eventId, fileFilterContext)
        if (!filterAttached) {
          LogAuditSource.unsubscribeClientEvent(client, eventId)
          failedEventIds.push(eventId)
          continue
        }
        subscribedIds.push(eventId)
        successCount += 1
      } catch (err) {
        const code = LogAuditSource.extractErrorCode(err as Object)
        if (LogAuditSource.lastSubscribeErrorCode === undefined) {
          LogAuditSource.lastSubscribeErrorCode = code
        }
        failedEventIds.push(eventId)
      }
    }

    if (successCount <= 0) {
      LogAuditSource.releaseClient(client, subscribedIds)
      const result: ClientSubscribeResult = {
        successCount: 0,
        failedEventIds,
        unsupported: false
      }
      return result
    }

    LogAuditSource.client = client
    LogAuditSource.clientSubscribedEventIds = subscribedIds
    const result: ClientSubscribeResult = {
      successCount,
      failedEventIds,
      unsupported: false
    }
    return result
  }

  private static createAuditEventCallback(): (event: securityAudit.AuditEvent) => void {
    return (event: securityAudit.AuditEvent): void => {
      const entry = LogAuditSource.parseAuditEvent(event)
      if (entry && LogAuditSource.callback) {
        LogAuditSource.callback(entry)
      }
    }
  }

  private static createClient(eventCallback: (event: securityAudit.AuditEvent) => void): AuditClientCompat | null {
    try {
      const clientValue = securityAudit.newClient(eventCallback) as AuditClientCompat
      if (!clientValue || typeof clientValue.subscribe !== 'function' || typeof clientValue.unsubscribe !== 'function') {
        LogUtils.warn(TAG, 'securityAudit.newClient is unavailable or returned an invalid client')
        return null
      }
      return clientValue
    } catch (err) {
      LogAuditSource.lastSubscribeErrorCode = LogAuditSource.extractErrorCode(err as Object)
      LogUtils.error(TAG, `createClient failed: ${JSON.stringify(err)}`)
      return null
    }
  }

  private static parseAuditEvent(event: securityAudit.AuditEvent): LogEntry | undefined {
    const mappedType = LogAuditSource.EVENT_TYPE_BY_ID.get(event.eventId)
    if (mappedType === undefined) {
      return undefined
    }

    const parsed = LogAuditSource.parseAuditPayload(event.content || '', event.metadata)
    if (mappedType === LogEventType.FILE) {
      LogUtils.info(TAG,
        `FILE event accepted: eventId=${event.eventId}, eventName=${parsed.rawEventName || '-'}, action=${parsed.rawAction || '-'}, result=${parsed.result}, rawPath=${parsed.rawFilePath || '-'}, normalizedPath=${parsed.filePath || '-'}`
      )
    }

    return {
      id: generateLogEntryId(),
      timestamp: LogAuditSource.parseTimestamp(event.timestamp || ''),
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
    const contentJson = LogAuditSource.safeParseJson(content)
    const metadataJson = LogAuditSource.safeParseJson(metadata)
    const sources = LogAuditSource.collectJsonSources(contentJson, metadataJson)
    const rawOutcome = LogAuditSource.pickFirstString(sources, ['outcome', 'result', 'status', 'decision', 'actionResult', 'action_result'])
    const rawFilePath = LogAuditSource.resolveAuditRawFilePath(content, metadata, sources)
    const normalizedFilePath = LogPathUtils.normalizePathCandidate(rawFilePath)

    return {
      detail: LogAuditSource.pickFirstString(sources, ['description', 'message', 'detail', 'msg', 'event_desc', 'summary']) ||
        content || metadata || LogManageStrings.auditEventFallbackDetail,
      result: LogAuditSource.mapResult(rawOutcome),
      processName: LogAuditSource.pickFirstString(sources, ['processName', 'procName', 'proc_name', 'cmdline', 'process', 'process_name', 'bundleName', 'bundle_name']),
      pid: LogAuditSource.pickFirstNumber(sources, ['pid', 'processId', 'process_id']),
      rawFilePath: rawFilePath,
      filePath: normalizedFilePath,
      remoteAddr: LogAuditSource.pickFirstString(sources, ['remoteAddress', 'remoteAddr', 'remote_addr', 'remoteIp', 'remote_ip', 'dstAddr', 'dst_addr', 'dstIp', 'dst_ip', 'peerAddr', 'peer_addr']),
      rawEventName: LogAuditSource.pickFirstString(sources, ['event_name', 'eventName', 'name']),
      rawOutcome: rawOutcome,
      rawAction: LogAuditSource.pickFirstString(sources, ['action', 'eventAction', 'event_action', 'operation', 'op', 'state'])
    }
  }

  private static resolveAuditRawFilePath(content: string, metadata: string | undefined, sources: JsonMap[]): string | undefined {
    const structured = LogAuditSource.pickFirstString(sources, [
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
      LogUtils.warn(TAG, `skip FILE prefilter: eventId=${eventId}, reason=file_filter_context_unavailable`)
      return false
    }
    if (typeof client.addFilter !== 'function') {
      LogUtils.warn(TAG, `skip FILE prefilter: eventId=${eventId}, reason=addFilter_unavailable`)
      return false
    }

    const filter: securityAudit.Filter = {
      isInclude: true,
      type: securityAudit.FilterType.FILE_PATH_PREFIX,
      values: [fileFilterContext.prefix]
    }
    try {
      client.addFilter(eventId, filter)
      LogUtils.info(TAG,
        `FILE prefilter attached: eventId=${eventId}, foregroundUserId=${fileFilterContext.foregroundUserId}, prefix=${fileFilterContext.prefix}`
      )
      return true
    } catch (err) {
      const code = LogAuditSource.extractErrorCode(err as Object)
      if (LogAuditSource.lastSubscribeErrorCode === undefined) {
        LogAuditSource.lastSubscribeErrorCode = code
      }
      if (code === FILE_FILTER_UNSUPPORTED_CODE) {
        return false
      }
      LogUtils.warn(TAG,
        `FILE prefilter attach failed: eventId=${eventId}, foregroundUserId=${fileFilterContext.foregroundUserId}, prefix=${fileFilterContext.prefix}, code=${code}, err=${JSON.stringify(err)}`
      )
      return false
    }
  }

  private static async prepareFileFilterContext(eventIds: number[]): Promise<FileFilterContext | undefined> {
    if (!eventIds.some((eventId: number) => FILE_EVENT_IDS.includes(eventId))) {
      return undefined
    }
    const foregroundUserId = await LogAuditSource.resolveForegroundUserId()
    const prefix = LogPathUtils.buildHmdfsAccountFilesPrefix(foregroundUserId)
    return { foregroundUserId, prefix }
  }

  private static async resolveForegroundUserId(): Promise<number> {
    try {
      const accountManager = osAccount.getAccountManager()
      return await accountManager.getForegroundOsAccountLocalId()
    } catch (err) {
      LogUtils.warn(TAG, `resolve foreground userId failed, fallback=${DEFAULT_FOREGROUND_USER_ID}, err=${JSON.stringify(err)}`)
      return DEFAULT_FOREGROUND_USER_ID
    }
  }

  private static unsubscribeClientEvent(client: AuditClientCompat, eventId: number): void {
    try {
      client.unsubscribe([eventId])
    } catch (err) {
      LogUtils.warn(TAG, `unsubscribe event failed: eventId=${eventId}, err=${JSON.stringify(err)}`)
    }
  }

  private static parseTimestamp(ts: string): number {
    if (ts.length < 14) {
      return LogAuditSource.nowProvider()
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
    const normalized = rawOutcome.toLowerCase()
    if (normalized.includes('blocked') || normalized.includes('deny') || normalized.includes('intercept')) {
      return LogEventResult.BLOCKED
    }
    if (normalized.includes('failed') || normalized.includes('error') || normalized.includes('reject')) {
      return LogEventResult.FAILED
    }
    return LogEventResult.SUCCESS
  }

  private static normalizeAuditTypes(eventTypes?: LogEventType[]): LogEventType[] {
    const source = eventTypes && eventTypes.length > 0 ? eventTypes : ALL_LOG_EVENT_TYPES
    const result: LogEventType[] = []
    for (const type of source) {
      if (LogAuditSource.EVENT_IDS_BY_TYPE.has(type) && !result.includes(type)) {
        result.push(type)
      }
    }
    return result
  }

  private static mapTypesToIds(eventTypes?: LogEventType[]): number[] {
    const ids: number[] = []
    for (const type of LogAuditSource.normalizeAuditTypes(eventTypes)) {
      const mappedIds = LogAuditSource.EVENT_IDS_BY_TYPE.get(type) || []
      for (const eventId of mappedIds) {
        if (!ids.includes(eventId)) {
          ids.push(eventId)
        }
      }
    }
    return ids
  }

  private static buildEventTypeById(): Map<number, LogEventType> {
    const mapping: Map<number, LogEventType> = new Map()
    LogAuditSource.EVENT_IDS_BY_TYPE.forEach((ids: number[], type: LogEventType) => {
      ids.forEach((eventId: number) => mapping.set(eventId, type))
    })
    return mapping
  }

  private static collectJsonSources(contentJson?: JsonMap, metadataJson?: JsonMap): JsonMap[] {
    const result: JsonMap[] = []
    const append = (candidate?: JsonMap): void => {
      if (!candidate) {
        return
      }
      result.push(candidate)
      const extra = LogAuditSource.extractNestedJson(candidate, 'extra')
      if (extra) {
        result.push(extra)
      }
      const metadata = LogAuditSource.extractNestedJson(candidate, 'metadata')
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
      const parsed = JSON.parse(value) as Object
      return LogAuditSource.toJsonMap(parsed)
    } catch {
      return undefined
    }
  }

  private static extractNestedJson(source: JsonMap, key: string): JsonMap | undefined {
    const candidate = source[key]
    if (typeof candidate === 'string') {
      return LogAuditSource.safeParseJson(candidate)
    }
    if (candidate && typeof candidate === 'object') {
      return LogAuditSource.toJsonMap(candidate)
    }
    return undefined
  }

  private static pickFirstString(sources: JsonMap[], keys: string[]): string | undefined {
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

  private static pickFirstNumber(sources: JsonMap[], keys: string[]): number | undefined {
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

  private static toJsonMap(candidate: Object | undefined): JsonMap | undefined {
    if (!candidate || Array.isArray(candidate)) {
      return undefined
    }
    return candidate as JsonMap
  }

  private static extractErrorCode(err: Object): number | undefined {
    const codeValue = (err as Record<string, Object>)['code']
    if (typeof codeValue === 'number') {
      return codeValue
    }
    if (typeof codeValue === 'string') {
      const parsed = Number(codeValue)
      return Number.isNaN(parsed) ? undefined : parsed
    }
    return undefined
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
      LogUtils.warn(TAG, `unsubscribe failed: ${JSON.stringify(err)}`)
    }
    try {
      const deleteClient = securityAudit.deleteClient as (target: AuditClientCompat) => void
      deleteClient(client)
    } catch (err) {
      LogUtils.warn(TAG, `deleteClient failed: ${JSON.stringify(err)}`)
    }
  }

  private static unsubscribeInternal(): boolean {
    let ok = LogAuditSource.unsubscribeClientInternal()
    LogAuditSource.client = null
    LogAuditSource.clientSubscribedEventIds = []
    LogAuditSource.isSubscribed = false
    return ok
  }

  private static unsubscribeClientInternal(): boolean {
    if (!LogAuditSource.client) {
      return true
    }
    let ok = true
    try {
      if (LogAuditSource.clientSubscribedEventIds.length > 0) {
        LogAuditSource.client.unsubscribe(LogAuditSource.clientSubscribedEventIds)
      }
    } catch (err) {
      ok = false
      LogUtils.warn(TAG, `client unsubscribe failed: ${JSON.stringify(err)}`)
    }
    try {
      const deleteClient = securityAudit.deleteClient as (target: AuditClientCompat) => void
      deleteClient(LogAuditSource.client)
    } catch (err) {
      ok = false
      LogUtils.warn(TAG, `deleteClient failed: ${JSON.stringify(err)}`)
    }
    return ok
  }

  static parseAuditEventForTest(event: securityAudit.AuditEvent): LogEntry | undefined {
    return LogAuditSource.parseAuditEvent(event)
  }

}

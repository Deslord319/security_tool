import { securityAudit } from '@kit.DeviceSecurityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
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

export type LogEntryCallback = (entry: LogEntry) => void

type JsonMap = Record<string, Object>

interface AuditClientCompat {
  subscribe(eventIds: number[]): void
  unsubscribe(eventIds: number[]): void
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
  private static diagnosticsByType: Map<LogEventType, LogEventTypeDiag> =
    LogAuditService.createDiagnosticsMap()
  private static unknownEventIds: number[] = []
  private static diagnosticsUpdatedAt: number = LogAuditService.nowProvider()

  private static readonly EVENT_IDS_BY_TYPE: Map<LogEventType, number[]> = new Map<LogEventType, number[]>([
    [
      LogEventType.FILE,
      [
        securityAudit.NotifyEvent.FILE,
        securityAudit.NotifyEvent.FILE_INTERCEPTED,
        securityAudit.NotifyEvent.KIA_CREATE,
        securityAudit.NotifyEvent.KIA_READ,
        securityAudit.NotifyEvent.KIA_VARIANT,
        securityAudit.NotifyEvent.KIA_INTERCEPT
      ]
    ],
    [LogEventType.NETWORK_CONN, [securityAudit.NotifyEvent.NETWORK_CONN]],
    [LogEventType.NETWORK_TRAFFIC, [securityAudit.NotifyEvent.NETWORK_TRAFFIC]],
    [
      LogEventType.APP,
      [
        securityAudit.NotifyEvent.APP,
        securityAudit.NotifyEvent.APP_INSTALL_INTERCEPTED,
        securityAudit.NotifyEvent.APP_UNINSTALL_INTERCEPTED,
        securityAudit.NotifyEvent.APP_UPDATE_INTERCEPTED,
        securityAudit.NotifyEvent.APP_RECOVER_INTERCEPTED,
        securityAudit.NotifyEvent.APP_START_INTERCEPTED
      ]
    ],
    [LogEventType.ACCOUNT, [securityAudit.NotifyEvent.ACCOUNT]],
    [
      LogEventType.USB_ACCESS,
      [
        securityAudit.NotifyEvent.USB_ACCESS_INTERCEPTED,
        securityAudit.NotifyEvent.VOLUME
      ]
    ],
    [LogEventType.PERMISSION, [securityAudit.NotifyEvent.PERMISSION]],
    [LogEventType.PROCESS, [securityAudit.NotifyEvent.PROCESS]],
    [LogEventType.PRINTER, [securityAudit.NotifyEvent.PRINTER]],
    [LogEventType.CAMERA, [securityAudit.NotifyEvent.CAMERA]],
    [LogEventType.CERT, [securityAudit.NotifyEvent.CERT]],
    [LogEventType.EDM, [securityAudit.NotifyEvent.EDM]],
    [LogEventType.DNS, [securityAudit.NotifyEvent.DNS]]
  ])

  private static readonly EVENT_TYPE_BY_ID: Map<number, LogEventType> = LogAuditService.buildEventTypeById()

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

      let targetTypes = eventTypes && eventTypes.length > 0 ? eventTypes : ALL_LOG_EVENT_TYPES
      let eventIds = LogAuditService.mapTypesToIds(targetTypes)
      LogAuditService.resetSubscriptionDiagnostics(targetTypes)

      if (eventIds.length === 0) {
        LogAuditService.lastSubscribeErrorCode = 401
        hilog.error(DOMAIN, TAG, 'subscribe failed: empty eventIds')
        LogAuditService.callback = null
        LogAuditService.setSubscribeMode('none', 'none')
        return false
      }

      let clientResult = LogAuditService.subscribeWithClient(eventIds)
      if (clientResult.shouldFallback) {
        LogAuditService.resetSubscriptionDiagnostics(targetTypes)
        let legacyResult = LogAuditService.subscribeWithLegacyOnOff(eventIds)
        LogAuditService.lastSubscribeFailedEventIds = legacyResult.failedEventIds
        LogAuditService.isSubscribed = legacyResult.successCount > 0
        LogAuditService.setSubscribeMode(
          LogAuditService.isSubscribed ? 'legacy' : 'none',
          clientResult.fallbackReason
        )

        if (!LogAuditService.isSubscribed) {
          LogAuditService.callback = null
          hilog.error(
            DOMAIN,
            TAG,
            `Legacy subscribe failed after fallback, failed eventIds: ${legacyResult.failedEventIds.join(',')}`
          )
          return false
        }

        LogAuditService.logPartialFailureIfNeeded()
        hilog.warn(DOMAIN, TAG, 'Switched to legacy subscribe mode for compatibility')
        return true
      }

      LogAuditService.lastSubscribeFailedEventIds = clientResult.failedEventIds
      LogAuditService.isSubscribed = clientResult.successCount > 0
      LogAuditService.setSubscribeMode(LogAuditService.isSubscribed ? 'client' : 'none', 'none')

      if (!LogAuditService.isSubscribed) {
        hilog.error(
          DOMAIN,
          TAG,
          `Client subscribe failed, failed eventIds: ${LogAuditService.lastSubscribeFailedEventIds.join(',')}`
        )
        LogAuditService.callback = null
        return false
      }

      LogAuditService.logPartialFailureIfNeeded()
      return true
    } catch (err) {
      LogAuditService.lastSubscribeErrorCode = LogAuditService.extractErrorCode(err as Object)
      hilog.error(DOMAIN, TAG, `subscribe failed: ${JSON.stringify(err)}`)
      LogAuditService.unsubscribeInternal()
      LogAuditService.callback = null
      LogAuditService.isSubscribed = false
      LogAuditService.setSubscribeMode('none', 'none')
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
      if (ok) {
        hilog.info(DOMAIN, TAG, 'Unsubscribed from security audit events')
      }
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

  static getLastSubscribeFailedByType(): Map<LogEventType, number[]> {
    let result: Map<LogEventType, number[]> = new Map()
    for (let type of ALL_LOG_EVENT_TYPES) {
      let diag = LogAuditService.diagnosticsByType.get(type)
      result.set(type, diag ? [...diag.failedEventIds] : [])
    }
    return result
  }

  static getDiagnostics(): LogAuditDiagnostics {
    let byType = new Map<LogEventType, LogEventTypeDiag>()
    for (let type of ALL_LOG_EVENT_TYPES) {
      let diag = LogAuditService.ensureDiag(type)
      byType.set(type, {
        type: type,
        subscribed: diag.subscribed,
        failedEventIds: [...diag.failedEventIds],
        lastSeenAt: diag.lastSeenAt,
        seenCount: diag.seenCount,
        lastErrorCode: diag.lastErrorCode
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
    let eventCallback = LogAuditService.createAuditEventCallback()
    let createResult = LogAuditService.tryCreateClient(eventCallback)
    if (!createResult.client) {
      return {
        successCount: 0,
        failedEventIds: [],
        shouldFallback: true,
        fallbackReason: createResult.fallbackReason
      }
    }

    let client = createResult.client
    let successCount = 0
    let failedEventIds: number[] = []
    let subscribedIds: number[] = []

    for (let eventId of eventIds) {
      try {
        client.subscribe([eventId])
        subscribedIds.push(eventId)
        successCount++
        LogAuditService.markSubscribeSuccess(eventId)
        hilog.info(DOMAIN, TAG, `Client subscribed eventId: ${eventId}`)
      } catch (err) {
        let code = LogAuditService.extractErrorCode(err as Object)
        if (LogAuditService.lastSubscribeErrorCode === undefined) {
          LogAuditService.lastSubscribeErrorCode = code
        }

        if (LogAuditService.isApiUnavailableError(err as Object)) {
          LogAuditService.releaseClient(client, subscribedIds)
          hilog.warn(DOMAIN, TAG, `Client subscribe API unavailable: ${JSON.stringify(err)}`)
          return {
            successCount: 0,
            failedEventIds: [],
            shouldFallback: true,
            fallbackReason: 'new_api_unavailable'
          }
        }

        failedEventIds.push(eventId)
        LogAuditService.markSubscribeFailure(eventId, code)
        hilog.error(DOMAIN, TAG, `Client subscribe eventId ${eventId} failed: ${JSON.stringify(err)}`)
      }
    }

    if (successCount <= 0) {
      LogAuditService.releaseClient(client, subscribedIds)
      return {
        successCount: 0,
        failedEventIds: failedEventIds,
        shouldFallback: false,
        fallbackReason: 'none'
      }
    }

    LogAuditService.client = client
    LogAuditService.clientSubscribedEventIds = subscribedIds
    hilog.info(DOMAIN, TAG, `Client subscribe success=${successCount}, failed=${failedEventIds.length}`)
    return {
      successCount: successCount,
      failedEventIds: failedEventIds,
      shouldFallback: false,
      fallbackReason: 'none'
    }
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
        successCount++
        LogAuditService.markSubscribeSuccess(eventId)
        hilog.info(DOMAIN, TAG, `Legacy subscribed eventId: ${eventId}`)
      } catch (err) {
        let code = LogAuditService.extractErrorCode(err as Object)
        if (LogAuditService.lastSubscribeErrorCode === undefined) {
          LogAuditService.lastSubscribeErrorCode = code
        }
        failedEventIds.push(eventId)
        LogAuditService.markSubscribeFailure(eventId, code)
        hilog.error(DOMAIN, TAG, `Legacy subscribe eventId ${eventId} failed: ${JSON.stringify(err)}`)
      }
    }

    hilog.info(DOMAIN, TAG, `Legacy subscribe success=${successCount}, failed=${failedEventIds.length}`)
    return {
      successCount: successCount,
      failedEventIds: failedEventIds,
      shouldFallback: false,
      fallbackReason: 'none'
    }
  }

  private static createAuditEventCallback(): (event: securityAudit.AuditEvent) => void {
    return (event: securityAudit.AuditEvent) => {
      let entry = LogAuditService.parseAuditEvent(event)
      if (LogAuditService.callback) {
        LogAuditService.callback(entry)
      }
    }
  }

  private static tryCreateClient(
    eventCallback: (event: securityAudit.AuditEvent) => void
  ): ClientCreateResult {
    try {
      let clientValue = securityAudit.newClient(eventCallback) as AuditClientCompat
      if (!clientValue || typeof clientValue.subscribe !== 'function' || typeof clientValue.unsubscribe !== 'function') {
        return {
          client: null,
          fallbackReason: 'new_api_unavailable'
        } as ClientCreateResult
      }
      return {
        client: clientValue,
        fallbackReason: 'none'
      } as ClientCreateResult
    } catch (err) {
      if (LogAuditService.isApiUnavailableError(err as Object)) {
        return {
          client: null,
          fallbackReason: 'new_api_unavailable'
        } as ClientCreateResult
      }
      hilog.error(DOMAIN, TAG, `newClient init failed: ${JSON.stringify(err)}`)
      return {
        client: null,
        fallbackReason: 'new_api_init_failed'
      } as ClientCreateResult
    }
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
      hilog.warn(DOMAIN, TAG, `client unsubscribe failed: ${JSON.stringify(err)}`)
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

  private static logPartialFailureIfNeeded(): void {
    if (LogAuditService.lastSubscribeFailedEventIds.length > 0) {
      hilog.warn(
        DOMAIN,
        TAG,
        `Some audit events failed to subscribe: ${LogAuditService.lastSubscribeFailedEventIds.join(',')}`
      )
    }
  }

  private static parseAuditEvent(event: securityAudit.AuditEvent): LogEntry {
    let mappedType = LogAuditService.mapEventType(event.eventId)
    let parsed = LogAuditService.parseEventContent(event.content || '')
    let sourceSubType = LogAuditService.extractSourceSubType(event as Object)
    let finalType = LogAuditService.inferTypeBySignals(mappedType, parsed, sourceSubType)
    LogAuditService.markEventSeen(finalType)

    return {
      id: generateLogEntryId(),
      timestamp: LogAuditService.parseTimestamp(event.timestamp || ''),
      eventType: finalType,
      detail: parsed.detail,
      processName: parsed.processName,
      pid: parsed.pid,
      uid: event.userId,
      filePath: parsed.filePath,
      remoteAddr: parsed.remoteAddr,
      sourceEventId: event.eventId,
      sourceSubType: sourceSubType,
      rawEventName: parsed.rawEventName,
      rawOutcome: parsed.rawOutcome,
      rawAction: parsed.rawAction,
      result: parsed.result
    }
  }

  private static parseTimestamp(ts: string): number {
    if (ts.length < 14) {
      return LogAuditService.nowProvider()
    }
    let year = parseInt(ts.substring(0, 4))
    let month = parseInt(ts.substring(4, 6)) - 1
    let day = parseInt(ts.substring(6, 8))
    let hour = parseInt(ts.substring(8, 10))
    let min = parseInt(ts.substring(10, 12))
    let sec = parseInt(ts.substring(12, 14))
    let date = new Date(year, month, day, hour, min, sec)
    return date.getTime()
  }

  private static mapEventType(eventId: number): LogEventType {
    let mapped = LogAuditService.EVENT_TYPE_BY_ID.get(eventId)
    if (mapped !== undefined) {
      return mapped
    }

    LogAuditService.recordUnknownEventId(eventId)
    hilog.warn(DOMAIN, TAG, `Unknown audit eventId: ${eventId}, fallback to FILE`)
    return LogEventType.FILE
  }

  private static parseEventContent(content: string): ParsedContent {
    let result: ParsedContent = {
      detail: content,
      result: LogEventResult.SUCCESS
    }

    let top = LogAuditService.safeParseJson(content)
    if (!top) {
      return result
    }

    let extra = LogAuditService.extractExtraJson(top)
    let sources: Array<JsonMap | undefined> = [top, extra]

    result.rawEventName = LogAuditService.pickFirstString(sources, [
      'event_name',
      'eventName',
      'name'
    ])
    result.rawOutcome = LogAuditService.pickFirstString(sources, [
      'outcome',
      'result',
      'status',
      'decision',
      'actionResult',
      'action_result'
    ])
    result.rawAction = LogAuditService.pickFirstString(sources, [
      'action',
      'eventAction',
      'event_action',
      'operation',
      'op',
      'state'
    ])

    let detail = LogAuditService.pickFirstString(sources, [
      'description',
      'message',
      'detail',
      'msg',
      'event_desc'
    ])
    if (detail) {
      result.detail = detail
    }

    result.processName = LogAuditService.pickFirstString(sources, [
      'processName',
      'procName',
      'proc_name',
      'cmdline',
      'process',
      'process_name',
      'package_name',
      'bundleName'
    ])
    result.pid = LogAuditService.pickFirstNumber(sources, ['pid', 'processId', 'process_id'])

    result.filePath = LogAuditService.pickFirstString(sources, [
      'filePath',
      'file_path',
      'path',
      'targetPath',
      'target_path'
    ])
    result.remoteAddr = LogAuditService.pickFirstString(sources, [
      'remoteAddress',
      'remoteAddr',
      'remote_addr',
      'remoteIp',
      'remote_ip',
      'dstAddr',
      'dst_addr',
      'dstIp',
      'dst_ip',
      'peerAddr',
      'peer_addr'
    ])

    result.result = LogAuditService.mapResult(result.rawOutcome)
    return result
  }

  private static inferTypeByRawEventName(defaultType: LogEventType, rawEventName?: string): LogEventType {
    if (!rawEventName) {
      return defaultType
    }

    let name = rawEventName.toLowerCase()
    if (name.startsWith('dns_')) {
      return LogEventType.DNS
    }
    if (name.startsWith('permission_')) {
      return LogEventType.PERMISSION
    }
    if (name.startsWith('network_conn_') || name.startsWith('net_conn_')) {
      return LogEventType.NETWORK_CONN
    }
    if (name.startsWith('network_traffic_') || name.startsWith('traffic_')) {
      return LogEventType.NETWORK_TRAFFIC
    }
    return defaultType
  }

  private static inferTypeBySignals(
    defaultType: LogEventType,
    parsed: ParsedContent,
    sourceSubType?: number
  ): LogEventType {
    let bySubType = LogAuditService.mapSubTypeToType(sourceSubType)
    if (bySubType !== undefined) {
      return bySubType
    }

    let byName = LogAuditService.inferTypeByRawEventName(defaultType, parsed.rawEventName)
    if (byName !== defaultType) {
      return byName
    }

    if (defaultType !== LogEventType.FILE) {
      return defaultType
    }
    return LogAuditService.inferTypeByContentHint(defaultType, parsed)
  }

  private static mapSubTypeToType(sourceSubType?: number): LogEventType | undefined {
    if (sourceSubType === undefined) {
      return undefined
    }
    let maybeType = sourceSubType as LogEventType
    if (ALL_LOG_EVENT_TYPES.includes(maybeType)) {
      return maybeType
    }
    return undefined
  }

  private static inferTypeByContentHint(defaultType: LogEventType, parsed: ParsedContent): LogEventType {
    let combined = `${parsed.rawEventName || ''} ${parsed.detail || ''} ${parsed.processName || ''}`.toLowerCase()

    if (parsed.remoteAddr && parsed.remoteAddr.length > 0) {
      if (
        combined.includes('traffic') ||
        combined.includes('bandwidth') ||
        combined.includes('rx ') ||
        combined.includes('tx ')
      ) {
        return LogEventType.NETWORK_TRAFFIC
      }
      return LogEventType.NETWORK_CONN
    }

    if (
      combined.includes('permission') ||
      combined.includes('grant') ||
      combined.includes('revoke') ||
      combined.includes('authorize')
    ) {
      return LogEventType.PERMISSION
    }
    if (combined.includes('dns')) {
      return LogEventType.DNS
    }
    if (
      combined.includes('network') ||
      combined.includes('socket') ||
      combined.includes('connect') ||
      combined.includes('http://') ||
      combined.includes('https://')
    ) {
      return LogEventType.NETWORK_CONN
    }
    if (
      combined.includes('account') ||
      combined.includes('login') ||
      combined.includes('logout') ||
      combined.includes('credential')
    ) {
      return LogEventType.ACCOUNT
    }
    if (combined.includes('usb')) {
      return LogEventType.USB_ACCESS
    }
    if (
      combined.includes('app_install') ||
      combined.includes('app_uninstall') ||
      combined.includes('bundle')
    ) {
      return LogEventType.APP
    }
    return defaultType
  }

  private static mapResult(rawOutcome?: string): LogEventResult {
    if (!rawOutcome || rawOutcome.length === 0) {
      return LogEventResult.SUCCESS
    }

    let normalized = rawOutcome.toLowerCase()
    if (
      normalized.includes('blocked') ||
      normalized.includes('deny') ||
      normalized.includes('intercept')
    ) {
      return LogEventResult.BLOCKED
    }
    if (
      normalized.includes('failed') ||
      normalized.includes('error') ||
      normalized.includes('reject')
    ) {
      return LogEventResult.FAILED
    }
    return LogEventResult.SUCCESS
  }

  private static mapTypesToIds(eventTypes?: LogEventType[]): number[] {
    let types = eventTypes && eventTypes.length > 0 ? eventTypes : ALL_LOG_EVENT_TYPES
    let ids: number[] = []

    for (let type of types) {
      let mappedIds = LogAuditService.EVENT_IDS_BY_TYPE.get(type)
      if (!mappedIds) {
        continue
      }
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
      for (let eventId of ids) {
        mapping.set(eventId, type)
      }
    })
    return mapping
  }

  private static createDiagnosticsMap(): Map<LogEventType, LogEventTypeDiag> {
    let map = new Map<LogEventType, LogEventTypeDiag>()
    for (let type of ALL_LOG_EVENT_TYPES) {
      map.set(type, {
        type: type,
        subscribed: false,
        failedEventIds: [],
        seenCount: 0
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
      type: type,
      subscribed: false,
      failedEventIds: [],
      seenCount: 0
    }
    LogAuditService.diagnosticsByType.set(type, created)
    return created
  }

  private static resetSubscriptionDiagnostics(targetTypes: LogEventType[]): void {
    for (let type of ALL_LOG_EVENT_TYPES) {
      let diag = LogAuditService.ensureDiag(type)
      diag.subscribed = false
      diag.failedEventIds = []
      diag.lastErrorCode = undefined
      if (!targetTypes.includes(type)) {
        diag.subscribed = false
      }
    }
    LogAuditService.touchDiagnostics()
  }

  private static markSubscribeSuccess(eventId: number): void {
    let type = LogAuditService.EVENT_TYPE_BY_ID.get(eventId)
    if (type === undefined) {
      return
    }
    let diag = LogAuditService.ensureDiag(type)
    diag.subscribed = true
    LogAuditService.touchDiagnostics()
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
    if (code !== undefined) {
      diag.lastErrorCode = code
    }
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
      let diag = LogAuditService.ensureDiag(type)
      diag.subscribed = false
    }
    LogAuditService.touchDiagnostics()
  }

  private static touchDiagnostics(): void {
    LogAuditService.diagnosticsUpdatedAt = LogAuditService.nowProvider()
  }

  private static safeParseJson(value: string): JsonMap | undefined {
    try {
      let parsed = JSON.parse(value) as Object
      if (parsed && typeof parsed === 'object') {
        return parsed as JsonMap
      }
      return undefined
    } catch {
      return undefined
    }
  }

  private static extractExtraJson(top: JsonMap): JsonMap | undefined {
    let extraValue = top['extra']
    if (extraValue === undefined) {
      return undefined
    }

    if (typeof extraValue === 'string') {
      return LogAuditService.safeParseJson(extraValue)
    }
    if (typeof extraValue === 'object' && extraValue !== null) {
      return extraValue as JsonMap
    }
    return undefined
  }

  private static pickFirstString(sources: Array<JsonMap | undefined>, keys: string[]): string | undefined {
    for (let source of sources) {
      if (!source) {
        continue
      }
      for (let key of keys) {
        let raw = source[key]
        if (typeof raw === 'string') {
          let trimmed = raw.trim()
          if (trimmed.length > 0) {
            return trimmed
          }
        }
      }
    }
    return undefined
  }

  private static pickFirstNumber(sources: Array<JsonMap | undefined>, keys: string[]): number | undefined {
    for (let source of sources) {
      if (!source) {
        continue
      }
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

  private static extractSourceSubType(event: Object): number | undefined {
    let record = event as Record<string, Object>
    let subType = record['subType']
    if (typeof subType === 'number') {
      return subType
    }
    if (typeof subType === 'string') {
      let parsed = Number(subType)
      return Number.isNaN(parsed) ? undefined : parsed
    }

    let rawType = record['eventType']
    if (typeof rawType === 'number') {
      return rawType
    }
    if (typeof rawType === 'string') {
      let parsed = Number(rawType)
      return Number.isNaN(parsed) ? undefined : parsed
    }
    return undefined
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
    if (text.includes('is not a function')) {
      return true
    }
    if (text.includes('not support') || text.includes('not supported') || text.includes('unsupported')) {
      return true
    }
    if (text.includes('api not found') || text.includes('method not found')) {
      return true
    }
    if (text.includes('undefined') && text.includes('newclient')) {
      return true
    }
    return false
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
      hilog.error(DOMAIN, TAG, `client unsubscribe failed: ${JSON.stringify(err)}`)
    }

    try {
      let deleteClient = securityAudit.deleteClient as (client: AuditClientCompat) => void
      deleteClient(LogAuditService.client)
    } catch (err) {
      ok = false
      hilog.error(DOMAIN, TAG, `deleteClient failed: ${JSON.stringify(err)}`)
    }

    return ok
  }

  private static unsubscribeLegacyInternal(): boolean {
    let ok = true
    LogAuditService.subscribedCallbacks.forEach(
      (eventCallback: (event: securityAudit.AuditEvent) => void, eventId: number) => {
        try {
          let auditInfo: securityAudit.AuditEventInfo = { eventId: eventId }
          securityAudit.off('auditEventOccur', auditInfo, eventCallback)
        } catch (err) {
          ok = false
          hilog.error(DOMAIN, TAG, `off eventId ${eventId} failed: ${JSON.stringify(err)}`)
        }
      }
    )
    return ok
  }
}

interface ParsedContent {
  detail: string
  processName?: string
  pid?: number
  uid?: number
  filePath?: string
  remoteAddr?: string
  rawEventName?: string
  rawOutcome?: string
  rawAction?: string
  result: LogEventResult
}

import { securityAudit } from '@kit.DeviceSecurityKit'
import osAccount from '@ohos.account.osAccount'
import { LogUtils } from '../../../utils/LogUtils'
import { LogPathUtils } from '../../../utils/LogPathUtils'
import { CommonErrorUtils } from '../../../utils/CommonErrorUtils'
import { AuditErrorCodes, CommonSystemErrorCodes } from '../../../constants/SystemErrorCodes'
import {
  ALL_LOG_EVENT_TYPES,
  LogEntry,
  LogEventType
} from '../../../models/LogModels'
import { AuditSubscribeResult, SourceStatus } from '../common/LogManagePorts'
import { parseAuditEventToLogEntry } from './LogAuditEventMapper'
import { ErrorLike } from '../../../types/LooseValueTypes'
import { AUTH_AUDIT_EVENT_IDS, FILE_AUDIT_EVENT_IDS } from './LogAuditEventIds'

const TAG = 'LogAuditSource'
const DEFAULT_FOREGROUND_USER_ID = 100

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
    [LogEventType.FILE, FILE_AUDIT_EVENT_IDS],
    [LogEventType.ACCOUNT, AUTH_AUDIT_EVENT_IDS],
    [LogEventType.PERMISSION, [securityAudit.NotifyEvent.PERMISSION]]
  ])

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
        LogAuditSource.lastSubscribeErrorCode = CommonSystemErrorCodes.INVALID_PARAMS
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
      LogAuditSource.lastSubscribeErrorCode = CommonErrorUtils.extractErrorCode(err as ErrorLike)
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
        const code = CommonErrorUtils.extractErrorCode(err as ErrorLike)
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
      LogUtils.info(
        TAG,
        `AUDIT_RAW_INPUT eventId=${event.eventId}, timestamp=${event.timestamp || '-'}, userId=${event.userId}, content=${event.content || '-'}, metadata=${event.metadata || '-'}`
      )
      const entry = LogAuditSource.parseAuditEvent(event)
      if (entry && LogAuditSource.callback) {
        LogUtils.info(
          TAG,
          `AUDIT_RAW_INPUT_ACCEPTED eventId=${event.eventId}, recordId=${entry.id}, result=${entry.result}, rawOutcome=${entry.rawOutcome || '-'}`
        )
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
      LogAuditSource.lastSubscribeErrorCode = CommonErrorUtils.extractErrorCode(err as ErrorLike)
      LogUtils.error(TAG, `createClient failed: ${JSON.stringify(err)}`)
      return null
    }
  }

  private static parseAuditEvent(event: securityAudit.AuditEvent): LogEntry | undefined {
    const entry = parseAuditEventToLogEntry(event, LogAuditSource.nowProvider)
    if (!entry) {
      return undefined
    }
    if (entry.eventType === LogEventType.FILE) {
      LogUtils.info(TAG,
        `FILE event accepted: eventId=${event.eventId}, eventName=${entry.rawEventName || '-'}, action=${entry.rawAction || '-'}, result=${entry.result}, normalizedPath=${entry.filePath || '-'}`
      )
    }
    return entry
  }

  private static tryAttachFilePrefixFilter(
    client: AuditClientCompat,
    eventId: number,
    fileFilterContext?: FileFilterContext
  ): boolean {
    if (!FILE_AUDIT_EVENT_IDS.includes(eventId)) {
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
      const code = CommonErrorUtils.extractErrorCode(err as ErrorLike)
      if (LogAuditSource.lastSubscribeErrorCode === undefined) {
        LogAuditSource.lastSubscribeErrorCode = code
      }
      if (code === AuditErrorCodes.FILE_FILTER_UNSUPPORTED) {
        return false
      }
      LogUtils.warn(TAG,
        `FILE prefilter attach failed: eventId=${eventId}, foregroundUserId=${fileFilterContext.foregroundUserId}, prefix=${fileFilterContext.prefix}, code=${code}, err=${JSON.stringify(err)}`
      )
      return false
    }
  }

  private static async prepareFileFilterContext(eventIds: number[]): Promise<FileFilterContext | undefined> {
    if (!eventIds.some((eventId: number) => FILE_AUDIT_EVENT_IDS.includes(eventId))) {
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

}

import { securityAudit } from '@kit.DeviceSecurityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  LogEntry,
  LogEventType,
  LogEventResult,
  ALL_LOG_EVENT_TYPES,
  generateLogEntryId
} from '../models/DataModels'

const TAG = 'LogAuditService'
const DOMAIN = 0x0006

// 订阅回调类型
export type LogEntryCallback = (entry: LogEntry) => void

// 安全审计服务 - 负责订阅和解析系统安全审计事件
export class LogAuditService {

  private static isSubscribed: boolean = false
  private static callback: LogEntryCallback | null = null
  private static subscribedCallbacks: Map<number, (event: securityAudit.AuditEvent) => void> = new Map()
  private static lastSubscribeErrorCode: number | undefined = undefined
  private static lastSubscribeFailedEventIds: number[] = []

  // 需求清单事件类型 -> 官方 NotifyEvent 映射
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
    [LogEventType.USB_ACCESS, [securityAudit.NotifyEvent.USB_ACCESS_INTERCEPTED]],
    [LogEventType.PERMISSION, [securityAudit.NotifyEvent.PERMISSION]],
    [LogEventType.PROCESS, [securityAudit.NotifyEvent.PROCESS]],
    [LogEventType.PRINTER, [securityAudit.NotifyEvent.PRINTER]],
    [LogEventType.CAMERA, [securityAudit.NotifyEvent.CAMERA]],
    [LogEventType.CERT, [securityAudit.NotifyEvent.CERT]],
    [LogEventType.EDM, [securityAudit.NotifyEvent.EDM]],
    [LogEventType.DNS, [securityAudit.NotifyEvent.DNS]]
  ])

  // 官方事件 ID -> 业务事件类型映射
  private static readonly EVENT_TYPE_BY_ID: Map<number, LogEventType> = LogAuditService.buildEventTypeById()

  // 订阅安全审计事件
  static subscribe(onLogEntry: LogEntryCallback, eventTypes?: LogEventType[]): boolean {
    if (LogAuditService.isSubscribed) {
      hilog.warn(DOMAIN, TAG, 'Already subscribed to audit events')
      return true
    }

    try {
      LogAuditService.callback = onLogEntry
      LogAuditService.lastSubscribeErrorCode = undefined
      LogAuditService.lastSubscribeFailedEventIds = []
      let eventIds = LogAuditService.mapTypesToIds(eventTypes)

      if (eventIds.length === 0) {
        LogAuditService.lastSubscribeErrorCode = 401
        hilog.error(DOMAIN, TAG, 'subscribe failed: empty eventIds')
        LogAuditService.callback = null
        return false
      }

      for (let eventId of eventIds) {
        let auditInfo: securityAudit.AuditEventInfo = { eventId: eventId }
        let eventCallback = (event: securityAudit.AuditEvent) => {
          let entry = LogAuditService.parseAuditEvent(event)
          if (LogAuditService.callback) {
            LogAuditService.callback(entry)
          }
        }

        try {
          securityAudit.on('auditEventOccur', auditInfo, eventCallback)
          LogAuditService.subscribedCallbacks.set(eventId, eventCallback)
          hilog.info(DOMAIN, TAG, `Subscribed eventId: ${eventId}`)
        } catch (err) {
          if (LogAuditService.lastSubscribeErrorCode === undefined) {
            LogAuditService.lastSubscribeErrorCode = LogAuditService.extractErrorCode(err as Object)
          }
          LogAuditService.lastSubscribeFailedEventIds.push(eventId)
          hilog.error(
            DOMAIN,
            TAG,
            `Subscribe eventId ${eventId} failed: ${JSON.stringify(err)}`
          )
        }
      }

      LogAuditService.isSubscribed = LogAuditService.subscribedCallbacks.size > 0
      if (!LogAuditService.isSubscribed) {
        hilog.error(
          DOMAIN,
          TAG,
          `Failed to subscribe any audit event, failed eventIds: ${LogAuditService.lastSubscribeFailedEventIds.join(',')}`
        )
        LogAuditService.callback = null
        return false
      }

      hilog.info(
        DOMAIN,
        TAG,
        `Subscribed audit events success=${LogAuditService.subscribedCallbacks.size}, failed=${LogAuditService.lastSubscribeFailedEventIds.length}`
      )
      if (LogAuditService.lastSubscribeFailedEventIds.length > 0) {
        hilog.warn(
          DOMAIN,
          TAG,
          `Some audit events are unsupported or rejected: ${LogAuditService.lastSubscribeFailedEventIds.join(',')}`
        )
      }
      return true
    } catch (err) {
      LogAuditService.lastSubscribeErrorCode = LogAuditService.extractErrorCode(err as Object)
      hilog.error(DOMAIN, TAG, `subscribe failed: ${JSON.stringify(err)}`)
      LogAuditService.unsubscribeInternal()
      LogAuditService.callback = null
      LogAuditService.isSubscribed = false
      return false
    }
  }

  // 取消订阅
  static unsubscribe(): boolean {
    if (!LogAuditService.isSubscribed) {
      return true
    }

    try {
      let ok = LogAuditService.unsubscribeInternal()
      LogAuditService.callback = null
      LogAuditService.lastSubscribeErrorCode = undefined
      LogAuditService.lastSubscribeFailedEventIds = []
      if (ok) {
        hilog.info(DOMAIN, TAG, 'Unsubscribed from security audit events')
      }
      return ok
    } catch (err) {
      hilog.error(DOMAIN, TAG, `unsubscribe failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取订阅状态
  static getSubscriptionStatus(): boolean {
    return LogAuditService.isSubscribed
  }

  // 获取最近一次订阅失败错误码（如 201 权限失败，401 参数错误）
  static getLastSubscribeErrorCode(): number | undefined {
    return LogAuditService.lastSubscribeErrorCode
  }

  // 获取最近一次订阅失败的事件 ID 列表
  static getLastSubscribeFailedEventIds(): number[] {
    return [...LogAuditService.lastSubscribeFailedEventIds]
  }

  // 解析系统 AuditEvent 为内部 LogEntry 格式
  private static parseAuditEvent(event: securityAudit.AuditEvent): LogEntry {
    let eventType = LogAuditService.mapEventType(event.eventId)
    let parsed = LogAuditService.parseEventContent(event.content || '', eventType)

    return {
      id: generateLogEntryId(),
      timestamp: LogAuditService.parseTimestamp(event.timestamp || ''),
      eventType: eventType,
      detail: parsed.detail,
      processName: parsed.processName,
      pid: parsed.pid,
      uid: event.userId,
      filePath: parsed.filePath,
      remoteAddr: parsed.remoteAddr,
      result: parsed.result
    }
  }

  // 解析 AuditEvent 时间戳字符串（YYYYMMDDHHMMSS）为毫秒数
  private static parseTimestamp(ts: string): number {
    if (ts.length < 14) {
      return Date.now()
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

  // 将系统 eventId 映射到内部 LogEventType
  private static mapEventType(eventId: number): LogEventType {
    let mapped = LogAuditService.EVENT_TYPE_BY_ID.get(eventId)
    if (mapped !== undefined) {
      return mapped
    }
    hilog.warn(DOMAIN, TAG, `Unknown audit eventId: ${eventId}, fallback to FILE`)
    return LogEventType.FILE
  }

  // 解析事件内容字符串
  private static parseEventContent(content: string, eventType: LogEventType): ParsedContent {
    let result: ParsedContent = {
      detail: content,
      result: LogEventResult.SUCCESS
    }

    try {
      // 尝试 JSON 解析
      let json = JSON.parse(content) as Record<string, Object>

      result.detail = (json['description'] as string) || (json['message'] as string) || content
      result.processName = json['processName'] as string
      result.pid = json['pid'] as number

      // 根据事件类型解析特定字段
      if (eventType === LogEventType.FILE) {
        result.filePath = (json['filePath'] as string) ||
          (json['path'] as string) ||
          (json['targetPath'] as string)
      } else if (eventType === LogEventType.NETWORK_CONN || eventType === LogEventType.NETWORK_TRAFFIC) {
        result.remoteAddr = (json['remoteAddress'] as string) || (json['remoteAddr'] as string)
      }

      // 解析结果状态
      let status = json['result'] as string
      if (status === 'blocked' || status === 'denied') {
        result.result = LogEventResult.BLOCKED
      } else if (status === 'failed' || status === 'error') {
        result.result = LogEventResult.FAILED
      }
    } catch {
      // 非 JSON 格式，保持原始内容
    }

    return result
  }

  // 类型映射到事件 ID 列表
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

  // 构建反向映射表
  private static buildEventTypeById(): Map<number, LogEventType> {
    let mapping: Map<number, LogEventType> = new Map()
    LogAuditService.EVENT_IDS_BY_TYPE.forEach((ids: number[], type: LogEventType) => {
      for (let eventId of ids) {
        mapping.set(eventId, type)
      }
    })
    return mapping
  }

  // 提取业务错误码
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

  // 内部取消订阅（按 eventId + callback 精确解绑）
  private static unsubscribeInternal(): boolean {
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
    })

    LogAuditService.subscribedCallbacks.clear()
    LogAuditService.isSubscribed = false
    return ok
  }
}

// 解析内容结果接口
interface ParsedContent {
  detail: string
  processName?: string
  pid?: number
  uid?: number
  filePath?: string
  remoteAddr?: string
  result: LogEventResult
}

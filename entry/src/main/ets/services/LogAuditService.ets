import { securityAudit } from '@kit.DeviceSecurityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  LogEntry,
  LogEventType,
  LogEventResult,
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

  // 订阅安全审计事件
  static subscribe(onLogEntry: LogEntryCallback): boolean {
    if (LogAuditService.isSubscribed) {
      hilog.warn(DOMAIN, TAG, 'Already subscribed to audit events')
      return true
    }

    try {
      LogAuditService.callback = onLogEntry

      // 订阅所有审计事件（eventId=0 表示全部）
      let auditInfo: securityAudit.AuditEventInfo = { eventId: 0 }

      securityAudit.on('auditEventOccur', auditInfo, (event: securityAudit.AuditEvent) => {
        hilog.debug(DOMAIN, TAG, `Received audit event: ${event.eventId}`)
        let entry = LogAuditService.parseAuditEvent(event)
        if (LogAuditService.callback) {
          LogAuditService.callback(entry)
        }
      })

      LogAuditService.isSubscribed = true
      hilog.info(DOMAIN, TAG, 'Subscribed to security audit events')
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `subscribe failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 取消订阅
  static unsubscribe(): boolean {
    if (!LogAuditService.isSubscribed) {
      return true
    }

    try {
      let auditInfo: securityAudit.AuditEventInfo = { eventId: 0 }
      securityAudit.off('auditEventOccur', auditInfo)
      LogAuditService.isSubscribed = false
      LogAuditService.callback = null
      hilog.info(DOMAIN, TAG, 'Unsubscribed from security audit events')
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `unsubscribe failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取订阅状态
  static getSubscriptionStatus(): boolean {
    return LogAuditService.isSubscribed
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
    // 系统事件 ID 范围映射（基于 HarmonyOS 安全审计 API 文档）
    // 实际映射需要根据官方文档调整
    if (eventId >= 1000 && eventId < 2000) {
      return LogEventType.FILE
    } else if (eventId >= 2000 && eventId < 3000) {
      return LogEventType.NETWORK_CONN
    } else if (eventId >= 3000 && eventId < 4000) {
      return LogEventType.NETWORK_TRAFFIC
    } else if (eventId >= 4000 && eventId < 5000) {
      return LogEventType.APP
    } else if (eventId >= 5000 && eventId < 6000) {
      return LogEventType.ACCOUNT
    } else if (eventId >= 6000 && eventId < 7000) {
      return LogEventType.USB_ACCESS
    } else if (eventId >= 7000 && eventId < 8000) {
      return LogEventType.PERMISSION
    } else if (eventId >= 8000 && eventId < 9000) {
      return LogEventType.PROCESS
    } else if (eventId >= 9000 && eventId < 10000) {
      return LogEventType.PRINTER
    } else if (eventId >= 10000 && eventId < 11000) {
      return LogEventType.CAMERA
    } else if (eventId >= 11000 && eventId < 12000) {
      return LogEventType.CERT
    } else if (eventId >= 12000 && eventId < 13000) {
      return LogEventType.EDM
    } else if (eventId >= 13000 && eventId < 14000) {
      return LogEventType.DNS
    }
    return LogEventType.FILE // 默认
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
        result.filePath = json['filePath'] as string
      } else if (eventType === LogEventType.NETWORK_CONN || eventType === LogEventType.NETWORK_TRAFFIC) {
        result.remoteAddr = json['remoteAddress'] as string
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
      hilog.debug(DOMAIN, TAG, 'Event content is not JSON format')
    }

    return result
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

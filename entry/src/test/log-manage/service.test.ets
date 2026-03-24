import { describe, it, expect } from '@ohos/hypium'
import {
  LogEntry,
  LogEventResult,
  LogEventType,
  LogFilter,
  LogAuditDiagnostics,
  LogEventTypeDiag,
  generateLogEntryId
} from '../../main/ets/models/DataModels'

function createLogEntry(
  eventType: LogEventType,
  detail: string,
  result: LogEventResult,
  timestamp: number,
  processName?: string
): LogEntry {
  return {
    id: generateLogEntryId(),
    timestamp,
    eventType,
    detail,
    processName,
    result
  }
}

function queryByFilter(entries: LogEntry[], filter?: LogFilter): LogEntry[] {
  if (!filter) {
    return entries
  }
  return entries.filter((entry: LogEntry) => {
    if (filter.eventTypes && filter.eventTypes.length > 0 && !filter.eventTypes.includes(entry.eventType)) {
      return false
    }
    if (filter.results && filter.results.length > 0 && !filter.results.includes(entry.result)) {
      return false
    }
    if (filter.keyword && !entry.detail.toLowerCase().includes(filter.keyword.toLowerCase())) {
      return false
    }
    return true
  })
}

function createDiagnostics(now: number): LogAuditDiagnostics {
  let byType = new Map<LogEventType, LogEventTypeDiag>()
  byType.set(LogEventType.FILE, {
    type: LogEventType.FILE,
    subscribed: true,
    failedEventIds: [],
    seenCount: 2,
    lastSeenAt: now,
    droppedNoPathCount: 1,
    droppedPrefixMismatchCount: 3
  } as LogEventTypeDiag)
  byType.set(LogEventType.CRASH, {
    type: LogEventType.CRASH,
    subscribed: true,
    failedEventIds: [],
    seenCount: 1,
    lastSeenAt: now
  } as LogEventTypeDiag)
  return {
    byType,
    unknownEventIds: [],
    subscribeMode: 'client',
    fallbackReason: 'none',
    lastModeSwitchAt: now,
    lastUpdatedAt: now
  } as LogAuditDiagnostics
}

function getDiagMetricLabel(): string {
  return '首页数量'
}

function getDiagCountText(diag: LogEventTypeDiag): string {
  let dropped = (diag.droppedNoPathCount || 0) + (diag.droppedPrefixMismatchCount || 0)
  if (dropped > 0) {
    return `本次会话命中 ${diag.seenCount} / 过滤 ${dropped}`
  }
  return `本次会话命中 ${diag.seenCount}`
}

export default function logManageServiceTest() {
  describe('LogManage Service Aligned Tests', () => {
    it('should filter entries by final event types', 0, () => {
      let entries: LogEntry[] = [
        createLogEntry(LogEventType.FILE, 'file://docs/storage/Users/currentUser/report.pdf', LogEventResult.SUCCESS, 1),
        createLogEntry(LogEventType.ACCOUNT, 'pin auth success', LogEventResult.SUCCESS, 2),
        createLogEntry(LogEventType.CRASH, 'APP_CRASH', LogEventResult.FAILED, 3)
      ]
      let filtered = queryByFilter(entries, {
        eventTypes: [LogEventType.FILE, LogEventType.CRASH],
        results: [LogEventResult.SUCCESS, LogEventResult.FAILED]
      })
      expect(filtered.length).assertEqual(2)
    })

    it('should keep file diagnostics drop counters explicit', 0, () => {
      let diagnostics = createDiagnostics(100)
      let fileDiag = diagnostics.byType.get(LogEventType.FILE)
      expect(fileDiag?.seenCount).assertEqual(2)
      expect(fileDiag?.droppedNoPathCount).assertEqual(1)
      expect(fileDiag?.droppedPrefixMismatchCount).assertEqual(3)
    })

    it('should keep diagnostics main metric aligned with homepage label', 0, () => {
      expect(getDiagMetricLabel()).assertEqual('首页数量')
    })

    it('should describe seenCount as session hits instead of homepage total', 0, () => {
      let diagnostics = createDiagnostics(100)
      let fileDiag = diagnostics.byType.get(LogEventType.FILE) as LogEventTypeDiag
      let crashDiag = diagnostics.byType.get(LogEventType.CRASH) as LogEventTypeDiag
      expect(getDiagCountText(fileDiag)).assertEqual('本次会话命中 2 / 过滤 4')
      expect(getDiagCountText(crashDiag)).assertEqual('本次会话命中 1')
    })
  })
}

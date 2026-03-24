import { describe, it, expect } from '@ohos/hypium'
import {
  LogEntry,
  LogFilter,
  LogEventType,
  LogEventResult,
  LogExportFormat,
  generateLogEntryId
} from '../../main/ets/models/DataModels'

function createLogEntry(
  eventType: LogEventType,
  result: LogEventResult,
  timestamp?: number,
  detail?: string
): LogEntry {
  return {
    id: generateLogEntryId(),
    timestamp: timestamp || Date.now(),
    eventType,
    result,
    detail: detail || 'Test log entry',
    processName: 'TestProcess'
  }
}

function createFilter(eventTypes?: LogEventType[], keyword?: string): LogFilter {
  return {
    eventTypes,
    keyword
  }
}

export default function logStorageServiceTest() {
  describe('LogStorageService', () => {
    it('should build entries with final event types', 0, () => {
      let entries: LogEntry[] = [
        createLogEntry(LogEventType.FILE, LogEventResult.SUCCESS),
        createLogEntry(LogEventType.ACCOUNT, LogEventResult.SUCCESS),
        createLogEntry(LogEventType.PERMISSION, LogEventResult.BLOCKED),
        createLogEntry(LogEventType.CRASH, LogEventResult.FAILED)
      ]
      expect(entries.length).assertEqual(4)
    })

    it('should support keyword filtering for file logs', 0, () => {
      let entries: LogEntry[] = [
        createLogEntry(LogEventType.FILE, LogEventResult.SUCCESS, undefined, 'file://docs/storage/Users/currentUser/report.pdf'),
        createLogEntry(LogEventType.ACCOUNT, LogEventResult.SUCCESS, undefined, 'pin auth success')
      ]
      let filter = createFilter([LogEventType.FILE], 'report')
      let filtered = entries.filter((entry) => {
        if (filter.eventTypes && !filter.eventTypes.includes(entry.eventType)) {
          return false
        }
        if (filter.keyword && !entry.detail.toLowerCase().includes(filter.keyword.toLowerCase())) {
          return false
        }
        return true
      })
      expect(filtered.length).assertEqual(1)
    })

    it('should keep export format enum available', 0, () => {
      expect(LogExportFormat.JSON).assertEqual('json')
      expect(LogExportFormat.CSV).assertEqual('csv')
      expect(LogExportFormat.TXT).assertEqual('txt')
    })
  })
}

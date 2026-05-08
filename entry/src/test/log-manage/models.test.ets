import { describe, it, expect } from '@ohos/hypium'
import {
  LogEventType,
  LogEventResult,
  getLogEventTypeLabel,
  getLogEventResultLabel,
  getLogEventResultColor,
  formatLogTimestamp,
  generateLogEntryId,
  LOG_EVENT_TYPE_OPTIONS,
  ALL_LOG_EVENT_TYPES,
  DEFAULT_LOG_STORAGE_CONFIG
} from '../../main/ets/models/DataModels'

export default function logManageDataModelsTest() {
  describe('LogManage DataModels', () => {
    it('should expose only four final log event types', 0, () => {
      expect(ALL_LOG_EVENT_TYPES.length).assertEqual(5)
      expect(ALL_LOG_EVENT_TYPES[0]).assertEqual(LogEventType.CRASH)
      expect(ALL_LOG_EVENT_TYPES[1]).assertEqual(LogEventType.FILE)
      expect(ALL_LOG_EVENT_TYPES[2]).assertEqual(LogEventType.ACCOUNT)
      expect(ALL_LOG_EVENT_TYPES[3]).assertEqual(LogEventType.PERMISSION)
      expect(ALL_LOG_EVENT_TYPES[4]).assertEqual(LogEventType.POWER)
    })

    it('should return stable labels for final event types', 0, () => {
      expect(getLogEventTypeLabel(LogEventType.CRASH)).assertEqual('崩溃日志')
      expect(getLogEventTypeLabel(LogEventType.FILE)).assertEqual('文件操作日志')
      expect(getLogEventTypeLabel(LogEventType.ACCOUNT)).assertEqual('用户认证日志')
      expect(getLogEventTypeLabel(LogEventType.PERMISSION)).assertEqual('权限变更日志')
      expect(getLogEventTypeLabel(LogEventType.POWER)).assertEqual('开关机日志')
    })

    it('should keep result labels and colors stable', 0, () => {
      expect(getLogEventResultLabel(LogEventResult.SUCCESS)).assertEqual('成功')
      expect(getLogEventResultLabel(LogEventResult.BLOCKED)).assertEqual('已阻止')
      expect(getLogEventResultLabel(LogEventResult.FAILED)).assertEqual('失败')
      expect(getLogEventResultColor(LogEventResult.SUCCESS)).assertEqual('#4CAF50')
      expect(getLogEventResultColor(LogEventResult.BLOCKED)).assertEqual('#FF9800')
      expect(getLogEventResultColor(LogEventResult.FAILED)).assertEqual('#F44336')
    })

    it('should format timestamps and generate unique ids', 0, () => {
      let ts = new Date(2026, 0, 15, 8, 30, 0).getTime()
      expect(formatLogTimestamp(ts)).assertEqual('2026-01-15 08:30:00')
      let id1 = generateLogEntryId()
      let id2 = generateLogEntryId()
      expect(id1.startsWith('log_')).assertTrue()
      expect(id1 === id2).assertFalse()
    })

    it('should keep options aligned with final event types and storage defaults', 0, () => {
      expect(LOG_EVENT_TYPE_OPTIONS.length).assertEqual(5)
      expect(LOG_EVENT_TYPE_OPTIONS.map((item) => item.value).every((item) => ALL_LOG_EVENT_TYPES.includes(item))).assertTrue()
      expect(DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries).assertEqual(5000)
      expect(DEFAULT_LOG_STORAGE_CONFIG.retentionDays).assertEqual(30)
    })
  })
}

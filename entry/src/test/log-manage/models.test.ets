import { describe, it, expect } from '@ohos/hypium'
import {
  LogEventType,
  generateLogEntryId,
  LOG_MAX_ENTRIES_OPTIONS,
  ALL_LOG_EVENT_TYPES,
  DEFAULT_LOG_STORAGE_CONFIG
} from '../../main/ets/models/LogModels'
import {
  formatLogTimestamp,
  getLogEventTypeLabel,
  getLogEventTypeOptions
} from '../../main/ets/presentation/log-manage/LogPresentationMapper'
import { LogEventPresentationStrings } from '../../main/ets/constants/modules/LogManageStrings'

export default function logManageDataModelsTest() {
  describe('LogManage DataModels', () => {
    it('should expose final log event types', 0, () => {
      expect(ALL_LOG_EVENT_TYPES.length).assertEqual(8)
      expect(ALL_LOG_EVENT_TYPES[0]).assertEqual(LogEventType.CRASH)
      expect(ALL_LOG_EVENT_TYPES[1]).assertEqual(LogEventType.FILE)
      expect(ALL_LOG_EVENT_TYPES[2]).assertEqual(LogEventType.ACCOUNT)
      expect(ALL_LOG_EVENT_TYPES[3]).assertEqual(LogEventType.PERMISSION)
      expect(ALL_LOG_EVENT_TYPES[4]).assertEqual(LogEventType.POWER)
      expect(ALL_LOG_EVENT_TYPES[5]).assertEqual(LogEventType.SYSTEM)
      expect(ALL_LOG_EVENT_TYPES[6]).assertEqual(LogEventType.KERNEL)
      expect(ALL_LOG_EVENT_TYPES[7]).assertEqual(LogEventType.AUDIT)
    })

    it('should return stable labels for final event types', 0, () => {
      expect(getLogEventTypeLabel(LogEventType.CRASH)).assertEqual(LogEventPresentationStrings.CRASH)
      expect(getLogEventTypeLabel(LogEventType.FILE)).assertEqual(LogEventPresentationStrings.FILE)
      expect(getLogEventTypeLabel(LogEventType.ACCOUNT)).assertEqual(LogEventPresentationStrings.ACCOUNT)
      expect(getLogEventTypeLabel(LogEventType.PERMISSION)).assertEqual(LogEventPresentationStrings.PERMISSION)
      expect(getLogEventTypeLabel(LogEventType.POWER)).assertEqual(LogEventPresentationStrings.POWER)
      expect(getLogEventTypeLabel(LogEventType.SYSTEM)).assertEqual(LogEventPresentationStrings.SYSTEM)
      expect(getLogEventTypeLabel(LogEventType.KERNEL)).assertEqual(LogEventPresentationStrings.KERNEL)
      expect(getLogEventTypeLabel(LogEventType.AUDIT)).assertEqual(LogEventPresentationStrings.AUDIT)
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
      let eventTypeOptions = getLogEventTypeOptions()
      expect(eventTypeOptions.length).assertEqual(8)
      expect(eventTypeOptions.map((item) => item.value).every((item) => ALL_LOG_EVENT_TYPES.includes(item))).assertTrue()
      expect(DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries).assertEqual(20000)
      expect(DEFAULT_LOG_STORAGE_CONFIG.retentionDays).assertEqual(30)
      expect(LOG_MAX_ENTRIES_OPTIONS.length).assertEqual(5)
      expect(LOG_MAX_ENTRIES_OPTIONS.includes(1000)).assertFalse()
      expect(LOG_MAX_ENTRIES_OPTIONS.includes(100000)).assertTrue()
    })
  })
}

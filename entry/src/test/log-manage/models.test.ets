/**
 * 日志管理模块 - 数据模型测试
 * L1 层：纯函数 / 数据模型的单元测试
 */
import { describe, it, expect } from '@ohos/hypium'
import {
  LogEventType,
  LogEventResult,
  LogExportFormat,
  getLogEventTypeLabel,
  getLogEventResultLabel,
  getLogEventResultColor,
  formatLogTimestamp,
  generateLogEntryId,
  LOG_EVENT_TYPE_OPTIONS,
  LOG_RETENTION_OPTIONS,
  LOG_MAX_ENTRIES_OPTIONS,
  DEFAULT_LOG_STORAGE_CONFIG
} from '../../main/ets/models/DataModels'

export default function logManageModelsTest() {
  describe('LogManage DataModels', () => {

    // ==================== LogEventType 枚举测试 ====================

    describe('LogEventType enum', () => {

      it('should have 13 event types', 0, () => {
        let types: LogEventType[] = [
          LogEventType.FILE,
          LogEventType.NETWORK_CONN,
          LogEventType.NETWORK_TRAFFIC,
          LogEventType.APP,
          LogEventType.ACCOUNT,
          LogEventType.USB_ACCESS,
          LogEventType.PERMISSION,
          LogEventType.PROCESS,
          LogEventType.PRINTER,
          LogEventType.CAMERA,
          LogEventType.CERT,
          LogEventType.EDM,
          LogEventType.DNS
        ]
        expect(types.length).assertEqual(13)
      })

      it('should have sequential numeric values starting from 0', 0, () => {
        expect(LogEventType.FILE).assertEqual(0)
        expect(LogEventType.NETWORK_CONN).assertEqual(1)
        expect(LogEventType.DNS).assertEqual(12)
      })
    })

    // ==================== LogEventResult 枚举测试 ====================

    describe('LogEventResult enum', () => {

      it('should define SUCCESS, BLOCKED, FAILED', 0, () => {
        expect(LogEventResult.SUCCESS).assertEqual(0)
        expect(LogEventResult.BLOCKED).assertEqual(1)
        expect(LogEventResult.FAILED).assertEqual(2)
      })
    })

    // ==================== getLogEventTypeLabel 测试 ====================

    describe('getLogEventTypeLabel', () => {

      it('should return correct label for FILE', 0, () => {
        expect(getLogEventTypeLabel(LogEventType.FILE)).assertEqual('文件操作')
      })

      it('should return correct label for NETWORK_CONN', 0, () => {
        expect(getLogEventTypeLabel(LogEventType.NETWORK_CONN)).assertEqual('网络连接')
      })

      it('should return correct label for USB_ACCESS', 0, () => {
        expect(getLogEventTypeLabel(LogEventType.USB_ACCESS)).assertEqual('USB 访问')
      })

      it('should return correct label for DNS', 0, () => {
        expect(getLogEventTypeLabel(LogEventType.DNS)).assertEqual('DNS 查询')
      })

      it('should return all labels without unknown', 0, () => {
        let types: LogEventType[] = [
          LogEventType.FILE, LogEventType.NETWORK_CONN, LogEventType.NETWORK_TRAFFIC,
          LogEventType.APP, LogEventType.ACCOUNT, LogEventType.USB_ACCESS,
          LogEventType.PERMISSION, LogEventType.PROCESS, LogEventType.PRINTER,
          LogEventType.CAMERA, LogEventType.CERT, LogEventType.EDM, LogEventType.DNS
        ]
        for (let t of types) {
          expect(getLogEventTypeLabel(t)).assertContain('')  // 非空
          expect(getLogEventTypeLabel(t) !== '未知').assertTrue()
        }
      })
    })

    // ==================== getLogEventResultLabel 测试 ====================

    describe('getLogEventResultLabel', () => {

      it('should return 成功 for SUCCESS', 0, () => {
        expect(getLogEventResultLabel(LogEventResult.SUCCESS)).assertEqual('成功')
      })

      it('should return 已阻止 for BLOCKED', 0, () => {
        expect(getLogEventResultLabel(LogEventResult.BLOCKED)).assertEqual('已阻止')
      })

      it('should return 失败 for FAILED', 0, () => {
        expect(getLogEventResultLabel(LogEventResult.FAILED)).assertEqual('失败')
      })
    })

    // ==================== getLogEventResultColor 测试 ====================

    describe('getLogEventResultColor', () => {

      it('should return green for SUCCESS', 0, () => {
        expect(getLogEventResultColor(LogEventResult.SUCCESS)).assertEqual('#4CAF50')
      })

      it('should return orange for BLOCKED', 0, () => {
        expect(getLogEventResultColor(LogEventResult.BLOCKED)).assertEqual('#FF9800')
      })

      it('should return red for FAILED', 0, () => {
        expect(getLogEventResultColor(LogEventResult.FAILED)).assertEqual('#F44336')
      })
    })

    // ==================== formatLogTimestamp 测试 ====================

    describe('formatLogTimestamp', () => {

      it('should format timestamp correctly', 0, () => {
        // 2026-01-15 08:30:00 UTC+8
        let ts = new Date(2026, 0, 15, 8, 30, 0).getTime()
        let result = formatLogTimestamp(ts)
        expect(result).assertEqual('2026-01-15 08:30:00')
      })

      it('should pad single digit month and day', 0, () => {
        let ts = new Date(2026, 0, 5, 3, 5, 9).getTime()
        let result = formatLogTimestamp(ts)
        expect(result).assertContain('01-05')
        expect(result).assertContain('03:05:09')
      })
    })

    // ==================== generateLogEntryId 测试 ====================

    describe('generateLogEntryId', () => {

      it('should start with log_ prefix', 0, () => {
        let id = generateLogEntryId()
        expect(id.startsWith('log_')).assertTrue()
      })

      it('should generate unique ids', 0, () => {
        let id1 = generateLogEntryId()
        let id2 = generateLogEntryId()
        expect(id1 !== id2).assertTrue()
      })

      it('should have reasonable length', 0, () => {
        let id = generateLogEntryId()
        expect(id.length > 10).assertTrue()
        expect(id.length < 50).assertTrue()
      })
    })

    // ==================== LOG_EVENT_TYPE_OPTIONS 测试 ====================

    describe('LOG_EVENT_TYPE_OPTIONS', () => {

      it('should have 13 options', 0, () => {
        expect(LOG_EVENT_TYPE_OPTIONS.length).assertEqual(13)
      })

      it('should have label and value for each option', 0, () => {
        for (let option of LOG_EVENT_TYPE_OPTIONS) {
          expect(option.label.length > 0).assertTrue()
          expect(option.value >= 0).assertTrue()
        }
      })
    })

    // ==================== 默认配置测试 ====================

    describe('DEFAULT_LOG_STORAGE_CONFIG', () => {

      it('should have maxLocalEntries = 10000', 0, () => {
        expect(DEFAULT_LOG_STORAGE_CONFIG.maxLocalEntries).assertEqual(10000)
      })

      it('should have retentionDays = 30', 0, () => {
        expect(DEFAULT_LOG_STORAGE_CONFIG.retentionDays).assertEqual(30)
      })

      it('should have autoExportEnabled = false', 0, () => {
        expect(DEFAULT_LOG_STORAGE_CONFIG.autoExportEnabled).assertFalse()
      })
    })

    // ==================== 选项列表测试 ====================

    describe('Option arrays', () => {

      it('LOG_RETENTION_OPTIONS should have valid values', 0, () => {
        expect(LOG_RETENTION_OPTIONS.length).assertLarger(0)
        for (let opt of LOG_RETENTION_OPTIONS) {
          expect(opt > 0).assertTrue()
        }
      })

      it('LOG_MAX_ENTRIES_OPTIONS should have ascending values', 0, () => {
        for (let i = 1; i < LOG_MAX_ENTRIES_OPTIONS.length; i++) {
          expect(LOG_MAX_ENTRIES_OPTIONS[i] > LOG_MAX_ENTRIES_OPTIONS[i - 1]).assertTrue()
        }
      })
    })

  })
}

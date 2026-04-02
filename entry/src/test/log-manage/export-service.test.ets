import { beforeEach, describe, it, expect } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { picker } from '@kit.CoreFileKit'
import {
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../main/ets/models/DataModels'
import { LogExportService } from '../../main/ets/services/log-manage/export/LogExportService'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'

function createLogEntry(
  id: string,
  eventType: LogEventType,
  result: LogEventResult,
  detail: string,
  timestamp?: number
): LogEntry {
  return {
    id,
    timestamp: timestamp ?? Date.now(),
    eventType,
    result,
    detail,
    processName: 'TestProcess'
  }
}

export default function logExportServiceTest() {
  describe('LogManage storage helpers', () => {
    beforeEach(() => {
      LogExportService.resetForTest()
    })

    it('should normalize storage config with fixed numeric values', 0, () => {
      expect(LogEntryNormalizer.normalizeMaxEntries(9999)).assertEqual(5000)
      expect(LogEntryNormalizer.normalizeMaxEntries(1000)).assertEqual(1000)
      expect(LogEntryNormalizer.normalizeRetentionDays(999)).assertEqual(90)
      expect(LogEntryNormalizer.normalizeRetentionDays(14)).assertEqual(14)
    })

    it('should sanitize entries and keep newest records first', 0, () => {
      let entries: LogEntry[] = [
        createLogEntry('old', LogEventType.FILE, LogEventResult.SUCCESS, 'older', 1000),
        createLogEntry('new', LogEventType.PERMISSION, LogEventResult.BLOCKED, 'newer', 2000)
      ]

      let normalized = LogEntryNormalizer.sanitizeEntries(entries, 10)

      expect(normalized.length).assertEqual(2)
      expect(normalized[0].id).assertEqual('new')
      expect(normalized[1].id).assertEqual('old')
    })

    it('should build csv with expected header and lines', 0, () => {
      let csv = LogExportService.buildCsvContent([
        createLogEntry('1', LogEventType.FILE, LogEventResult.SUCCESS, 'alpha'),
        createLogEntry('2', LogEventType.CRASH, LogEventResult.FAILED, 'beta')
      ])

      expect(csv.indexOf('时间,类型,详情,进程,PID,结果')).assertEqual(0)
      expect(csv.indexOf('alpha') > 0).assertTrue()
      expect(csv.indexOf('beta') > 0).assertTrue()
    })

    it('should return empty when export entries are missing', 0, async (done: Function) => {
      let result = await LogExportService.export(null, [])

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('context_missing')
      done()
    })

    it('should return empty when csv content is blank', 0, async (done: Function) => {
      let result = await LogExportService.saveCsvContent({} as common.UIAbilityContext, '')

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('empty')
      done()
    })

    it('should return user_canceled when picker returns empty directory list', 0, async (done: Function) => {
      LogExportService.setTestDeps({
        pickerFactory: (_context: common.UIAbilityContext) => ({
          save: async (_options: picker.DocumentSaveOptions): Promise<string[]> => []
        }),
        nowProvider: () => new Date(2026, 0, 15, 8, 30, 0).getTime()
      })

      let result = await LogExportService.saveCsvContent({} as common.UIAbilityContext, 'header\r\nrow')

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('user_canceled')
      done()
    })

    it('should return io_failed when write pipeline throws', 0, async (done: Function) => {
      let closeCalled = false
      LogExportService.setTestDeps({
        pickerFactory: (_context: common.UIAbilityContext) => ({
          save: async (_options: picker.DocumentSaveOptions): Promise<string[]> => ['file://docs/storage']
        }),
        buildPathFn: (_directoryUri: string, fileName: string): string => `/mock/${fileName}`,
        openFileFn: (_path: string): { fd: number } => ({ fd: 9 }),
        writeFileFn: (_fd: number, _content: string): void => { throw new Error('write failed') },
        closeFileFn: (_fd: number): void => { closeCalled = true }
      })

      let result = await LogExportService.saveCsvContent({} as common.UIAbilityContext, 'header\r\nrow')

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('io_failed')
      expect(closeCalled).assertTrue()
      done()
    })

    it('should return ok with file metadata when save pipeline succeeds', 0, async (done: Function) => {
      let wroteContent = ''
      LogExportService.setTestDeps({
        nowProvider: () => new Date(2026, 0, 15, 8, 30, 0).getTime(),
        pickerFactory: (_context: common.UIAbilityContext) => ({
          save: async (_options: picker.DocumentSaveOptions): Promise<string[]> => ['file://docs/storage']
        }),
        buildPathFn: (_directoryUri: string, fileName: string): string => `/mock/${fileName}`,
        openFileFn: (_path: string): { fd: number } => ({ fd: 7 }),
        writeFileFn: (_fd: number, content: string): void => {
          wroteContent = content
        },
        closeFileFn: (_fd: number): void => {}
      })

      let result = await LogExportService.saveCsvContent({} as common.UIAbilityContext, 'header\r\nrow')

      expect(result.success).assertTrue()
      expect(result.code).assertEqual('ok')
      expect(result.fileName).assertEqual('security_log_20260115_083000.csv')
      expect(result.fullPath).assertEqual('/mock/security_log_20260115_083000.csv')
      expect(wroteContent).assertEqual('header\r\nrow')
      done()
    })
  })
}

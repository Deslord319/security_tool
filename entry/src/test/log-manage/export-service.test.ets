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

class FakeSavePicker {
  private uris: string[]

  constructor(uris: string[]) {
    this.uris = uris
  }

  async save(_options: picker.DocumentSaveOptions): Promise<string[]> {
    return this.uris.slice()
  }
}

class FakeExportFileHandle {
  fd: number

  constructor(fd: number) {
    this.fd = fd
  }
}

class FakeExportDeps {
  nowProvider?: () => number
  pickerFactory?: (context: common.UIAbilityContext) => FakeSavePicker
  buildPathFn?: (directoryUri: string, fileName: string) => string
  openFileFn?: (path: string) => FakeExportFileHandle
  writeFileFn?: (fd: number, content: string) => void
  closeFileFn?: (fd: number) => void
}

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
      let deps = new FakeExportDeps()
      deps.pickerFactory = (_context: common.UIAbilityContext) => new FakeSavePicker([])
      deps.nowProvider = () => new Date(2026, 0, 15, 8, 30, 0).getTime()
      LogExportService.setTestDeps(deps as Object as never)

      let result = await LogExportService.saveCsvContent({} as common.UIAbilityContext, 'header\r\nrow')

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('user_canceled')
      done()
    })

    it('should return io_failed when write pipeline throws', 0, async (done: Function) => {
      let closeCalled = false
      let deps = new FakeExportDeps()
      deps.pickerFactory = (_context: common.UIAbilityContext) => new FakeSavePicker(['file://docs/storage'])
      deps.buildPathFn = (_directoryUri: string, fileName: string): string => `/mock/${fileName}`
      deps.openFileFn = (_path: string): FakeExportFileHandle => new FakeExportFileHandle(9)
      deps.writeFileFn = (_fd: number, _content: string): void => { throw new Error('write failed') }
      deps.closeFileFn = (_fd: number): void => { closeCalled = true }
      LogExportService.setTestDeps(deps as Object as never)

      let result = await LogExportService.saveCsvContent({} as common.UIAbilityContext, 'header\r\nrow')

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('io_failed')
      expect(closeCalled).assertTrue()
      done()
    })

    it('should return ok with file metadata when save pipeline succeeds', 0, async (done: Function) => {
      let wroteContent = ''
      let deps = new FakeExportDeps()
      deps.nowProvider = () => new Date(2026, 0, 15, 8, 30, 0).getTime()
      deps.pickerFactory = (_context: common.UIAbilityContext) => new FakeSavePicker(['file://docs/storage'])
      deps.buildPathFn = (_directoryUri: string, fileName: string): string => `/mock/${fileName}`
      deps.openFileFn = (_path: string): FakeExportFileHandle => new FakeExportFileHandle(7)
      deps.writeFileFn = (_fd: number, content: string): void => {
        wroteContent = content
      }
      deps.closeFileFn = (_fd: number): void => {}
      LogExportService.setTestDeps(deps as Object as never)

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

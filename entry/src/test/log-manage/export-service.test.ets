import { afterEach, beforeEach, describe, it, expect } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import {
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../main/ets/models/DataModels'
import {
  CsvFileExportResult,
  CsvFileExportService,
  CsvFileWritePort
} from '../../main/ets/services/common/export/CsvFileExportService'
import { LogExportService } from '../../main/ets/services/log-manage/export/LogExportService'
import { LogEntryNormalizer } from '../../main/ets/services/log-manage/mapper/LogEntryNormalizer'
import { LogEntryRepository } from '../../main/ets/services/log-manage/repository/LogEntryRepository'

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

function createExportResult(
  success: boolean,
  code: 'ok' | 'empty' | 'user_canceled' | 'io_failed' | 'context_missing',
  fileName?: string,
  fullPath?: string
): CsvFileExportResult {
  let result: CsvFileExportResult = {
    success,
    code,
    fileName,
    fullPath
  }
  return result
}

class CapturingWritePort implements CsvFileWritePort {
  private readonly captured: string[]

  constructor(captured: string[]) {
    this.captured = captured
  }

  append(content: string): void {
    this.captured.push(content)
  }
}

export default function logExportServiceTest() {
  describe('LogManage storage helpers', () => {
    let mockKit: MockKit

    beforeEach(() => {
      mockKit = new MockKit()
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should normalize storage config with fixed numeric values', 0, () => {
      expect(LogEntryNormalizer.normalizeMaxEntries(9999)).assertEqual(9999)
      expect(LogEntryNormalizer.normalizeMaxEntries(100000)).assertEqual(100000)
      expect(LogEntryNormalizer.normalizeMaxEntries(100001)).assertEqual(100000)
      expect(LogEntryNormalizer.normalizeRetentionDays(999)).assertEqual(999)
      expect(LogEntryNormalizer.normalizeRetentionDays(14)).assertEqual(14)
    })

    it('should normalize export entries and keep list order stable', 0, () => {
      let entries: LogEntry[] = [
        createLogEntry('old', LogEventType.FILE, LogEventResult.SUCCESS, 'older', 1000),
        createLogEntry('new', LogEventType.PERMISSION, LogEventResult.BLOCKED, 'newer', 2000)
      ]

      let normalized = LogEntryNormalizer.normalizeEntriesForAppend(entries)

      expect(normalized.length).assertEqual(2)
      expect(normalized[0].id).assertEqual('old')
      expect(normalized[1].id).assertEqual('new')
    })

    it('should return context_missing when export context is missing', 0, async (done: Function) => {
      let result = await LogExportService.export(null)

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('context_missing')
      done()
    })

    it('should return empty when queried log count is zero', 0, async (done: Function) => {
      let countMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.countByQuery)
      when(countMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(0))

      let result = await LogExportService.export({} as common.UIAbilityContext)

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('empty')
      done()
    })

    it('should propagate downstream export result when writer is canceled', 0, async (done: Function) => {
      let countMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.countByQuery)
      let saveMock = mockKit.mockFunc(CsvFileExportService, CsvFileExportService.saveByWriter)
      when(countMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(1))
      when(saveMock)(ArgumentMatchers.any)
        .afterReturn(Promise.resolve(createExportResult(false, 'user_canceled')))

      let result = await LogExportService.export({} as common.UIAbilityContext)

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('user_canceled')
      done()
    })

    it('should write csv header and row chunks through export writer', 0, async (done: Function) => {
      let countMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.countByQuery)
      let listMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.listByQuery)
      let saveMock = mockKit.mockFunc(CsvFileExportService, CsvFileExportService.saveByWriter)
      let captured: string[] = []
      when(countMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(1))
      when(listMock)(ArgumentMatchers.any).afterReturn(Promise.resolve([
        createLogEntry('1', LogEventType.FILE, LogEventResult.SUCCESS, 'alpha', 1700000000000)
      ]))
      when(saveMock)(ArgumentMatchers.any).afterAction((
        context: common.UIAbilityContext,
        fileNamePrefix: string,
        writer: (port: CsvFileWritePort) => Promise<void>,
        fileExtension: string
      ) => {
        let port = new CapturingWritePort(captured)
        return writer(port).then(() => {
          return Promise.resolve(createExportResult(
            true,
            'ok',
            `${fileNamePrefix}_mock.${fileExtension}`,
            `/mock/${fileNamePrefix}_mock.${fileExtension}`
          ))
        })
      })

      let result = await LogExportService.export({} as common.UIAbilityContext)

      expect(result.success).assertTrue()
      expect(captured.length >= 2).assertTrue()
      expect(captured[0].indexOf('时间,事件类型,详情,进程名,PID,结果')).assertEqual(0)
      expect(captured[1].indexOf('alpha') > -1).assertTrue()
      done()
    })

    it('should return io_failed when export writer throws unexpectedly', 0, async (done: Function) => {
      let countMock = mockKit.mockFunc(LogEntryRepository, LogEntryRepository.countByQuery)
      let saveMock = mockKit.mockFunc(CsvFileExportService, CsvFileExportService.saveByWriter)
      when(countMock)(ArgumentMatchers.any).afterReturn(Promise.resolve(1))
      when(saveMock)(ArgumentMatchers.any).afterAction(() => {
        throw new Error('writer failed')
      })

      let result = await LogExportService.export({} as common.UIAbilityContext)

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('io_failed')
      done()
    })
  })
}

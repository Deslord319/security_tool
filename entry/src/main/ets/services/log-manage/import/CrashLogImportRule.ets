import util from '@ohos.util'
import fileIo from '@ohos.file.fs'
import {
  LogDetailTableRow,
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../../models/DataModels'
import { LogManageImportDetailStrings } from '../../../constants/modules/LogManageStrings'
import { LogUtils } from '../../../utils/LogUtils'
import { LogImportHash } from './LogImportHash'
import {
  ImportedLogFile,
  LogImportRule,
  LogImportRuleResult,
  createEmptyLogImportRuleResult
} from './LogImportRule'

interface ParsedCrashLog {
  crashType: string
  timestamp: number
  processName: string
  pid?: number
  uid?: number
  reason: string
  errorName?: string
  errorMessage?: string
  stringId?: string
  topStack?: string
}

type CrashLogLineReader = (
  file: ImportedLogFile,
  onLine: (line: string, lineNumber: number) => Promise<void>
) => Promise<void>

const TAG = 'CrashLogImportRule'
const READ_CHUNK_SIZE = 64 * 1024
const YIELD_EVERY_LINES = 200
const MAX_FIELD_LENGTH = 240

export class CrashLogImportRule implements LogImportRule {
  readonly name: string = 'crash'
  private static lineReaderForTest: CrashLogLineReader | null = null

  static setLineReaderForTest(reader: CrashLogLineReader): void {
    CrashLogImportRule.lineReaderForTest = reader
  }

  static resetTestPorts(): void {
    CrashLogImportRule.lineReaderForTest = null
  }

  canHandle(file: ImportedLogFile): boolean {
    let fileName = file.fileName.toLowerCase()
    return CrashLogImportRule.isUnderFaultloggerDirectory(file.normalizedPath) &&
      fileName.endsWith('.log') &&
      CrashLogImportRule.parseCrashType(file.fileName) !== undefined
  }

  async parse(file: ImportedLogFile): Promise<LogImportRuleResult> {
    let result = createEmptyLogImportRuleResult()
    let startedAt = Date.now()
    LogUtils.info(TAG, `parse start: file=${file.relativePath}, path=${file.path}`)
    try {
      let parsed = await CrashLogImportRule.parseFile(file)
      if (!parsed) {
        result.droppedCount++
        LogUtils.info(TAG, `parse dropped: file=${file.relativePath}, reason=invalid_faultlogger, elapsedMs=${Date.now() - startedAt}`)
        return result
      }
      let entry = CrashLogImportRule.buildEntry(parsed, file)
      entry.id = LogImportHash.buildId(entry)
      result.entries.push(entry)
      LogUtils.info(TAG, `parse done: file=${file.relativePath}, entries=1, dropped=0, failed=0, elapsedMs=${Date.now() - startedAt}`)
      return result
    } catch (err) {
      result.failedCount++
      LogUtils.warn(TAG, `parse failed: file=${file.relativePath}, err=${JSON.stringify(err)}, elapsedMs=${Date.now() - startedAt}`)
      return result
    }
  }

  private static async parseFile(file: ImportedLogFile): Promise<ParsedCrashLog | null> {
    let crashType = CrashLogImportRule.parseCrashType(file.fileName)
    if (!crashType) {
      return null
    }
    let state = new CrashParseState(crashType, file.fileName)
    await CrashLogImportRule.forEachLine(file, async (line: string, _lineNumber: number): Promise<void> => {
      state.consume(line)
    })
    return state.build()
  }

  private static async forEachLine(
    file: ImportedLogFile,
    onLine: (line: string, lineNumber: number) => Promise<void>
  ): Promise<void> {
    if (CrashLogImportRule.lineReaderForTest) {
      await CrashLogImportRule.lineReaderForTest(file, onLine)
      return
    }
    let fd = fileIo.openSync(file.path, fileIo.OpenMode.READ_ONLY)
    let decoder = util.TextDecoder.create('utf-8')
    let pending = ''
    let lineNumber = 0
    let readOffset = 0
    try {
      while (true) {
        let buffer = new ArrayBuffer(READ_CHUNK_SIZE)
        let readCount = fileIo.readSync(fd.fd, buffer, {
          offset: readOffset,
          length: READ_CHUNK_SIZE
        })
        if (readCount <= 0) {
          break
        }
        readOffset += readCount
        let chunk = decoder.decodeToString(new Uint8Array(buffer, 0, readCount))
        let lines = `${pending}${chunk}`.split(/\r?\n/)
        pending = lines.pop() ?? ''
        for (let line of lines) {
          lineNumber++
          await onLine(line, lineNumber)
          if (lineNumber % YIELD_EVERY_LINES === 0) {
            await CrashLogImportRule.yieldToEventLoop()
          }
        }
      }
      if (pending.length > 0) {
        lineNumber++
        await onLine(pending, lineNumber)
      }
    } finally {
      fileIo.closeSync(fd.fd)
    }
  }

  private static buildEntry(parsed: ParsedCrashLog, file: ImportedLogFile): LogEntry {
    let detail = CrashLogImportRule.buildStableDetail(parsed)
    return {
      id: '',
      timestamp: parsed.timestamp,
      eventType: LogEventType.CRASH,
      detail,
      processName: parsed.processName,
      pid: parsed.pid,
      uid: parsed.uid,
      rawEventName: parsed.crashType,
      rawOutcome: parsed.crashType === 'appfreeze' ? 'freeze' : 'crash',
      rawAction: parsed.reason,
      detailRows: CrashLogImportRule.buildDetailRows(parsed, file),
      result: LogEventResult.FAILED
    }
  }

  private static buildStableDetail(parsed: ParsedCrashLog): string {
    let parts = [
      parsed.crashType,
      parsed.processName,
      `${parsed.timestamp}`,
      parsed.reason,
      parsed.topStack ?? ''
    ].filter((part: string) => part.length > 0)
    return LogImportHash.normalizeText(parts.join(' | '))
  }

  private static buildDetailRows(parsed: ParsedCrashLog, file: ImportedLogFile): LogDetailTableRow[] {
    let rows: LogDetailTableRow[] = [
      { key: 'crash.type', label: '崩溃类型', value: parsed.crashType },
      { key: 'import.sourceFile', label: LogManageImportDetailStrings.SOURCE_FILE, value: file.relativePath },
      { key: 'crash.reason', label: '原因', value: parsed.reason },
      { key: 'crash.timestamp', label: '发生时间', value: `${parsed.timestamp}` }
    ]
    CrashLogImportRule.appendOptionalRow(rows, 'crash.errorName', '错误名称', parsed.errorName)
    CrashLogImportRule.appendOptionalRow(rows, 'crash.errorMessage', '错误消息', parsed.errorMessage)
    CrashLogImportRule.appendOptionalRow(rows, 'crash.stringId', 'STRINGID', parsed.stringId)
    CrashLogImportRule.appendOptionalRow(rows, 'crash.topStack', 'Top stack', parsed.topStack)
    return rows
  }

  private static appendOptionalRow(rows: LogDetailTableRow[], key: string, label: string, value?: string): void {
    if (!value || value.length === 0) {
      return
    }
    rows.push({ key, label, value } as LogDetailTableRow)
  }

  private static parseCrashType(fileName: string): string | undefined {
    let lower = fileName.toLowerCase()
    if (lower.startsWith('appfreeze-')) {
      return 'appfreeze'
    }
    if (lower.startsWith('jscrash-')) {
      return 'jscrash'
    }
    if (lower.startsWith('cppcrash-')) {
      return 'cppcrash'
    }
    return undefined
  }

  static parseFilenameTimestamp(fileName: string): number | undefined {
    let matched = fileName.match(/-(\d{17})\.log$/i)
    if (!matched) {
      return undefined
    }
    return CrashLogImportRule.parseCompactTimestamp(matched[1])
  }

  static parseTimestampValue(value: string): number | undefined {
    let normalized = value.trim()
    if (normalized.length === 0) {
      return undefined
    }
    let compact = normalized.match(/^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(\d{3})?$/)
    if (compact) {
      return CrashLogImportRule.parseCompactTimestamp(compact[0].length === 14 ? `${compact[0]}000` : compact[0])
    }
    let standard = normalized.match(/^(\d{4})[-/](\d{2})[-/](\d{2})[ T-](\d{2}):(\d{2}):(\d{2})(?:[.:](\d{3}))?/)
    if (!standard) {
      return undefined
    }
    return new Date(
      Number(standard[1]),
      Number(standard[2]) - 1,
      Number(standard[3]),
      Number(standard[4]),
      Number(standard[5]),
      Number(standard[6]),
      Number(standard[7] ?? '0')
    ).getTime()
  }

  private static parseCompactTimestamp(value: string): number | undefined {
    if (!/^\d{17}$/.test(value)) {
      return undefined
    }
    return new Date(
      Number(value.substring(0, 4)),
      Number(value.substring(4, 6)) - 1,
      Number(value.substring(6, 8)),
      Number(value.substring(8, 10)),
      Number(value.substring(10, 12)),
      Number(value.substring(12, 14)),
      Number(value.substring(14, 17))
    ).getTime()
  }

  static parseNumber(value: string): number | undefined {
    let parsed = Number(value.trim())
    return Number.isFinite(parsed) ? parsed : undefined
  }

  static truncate(value: string): string {
    let normalized = LogImportHash.normalizeText(value)
    return normalized.length > MAX_FIELD_LENGTH ? normalized.substring(0, MAX_FIELD_LENGTH) : normalized
  }

  private static isUnderFaultloggerDirectory(path: string): boolean {
    let normalized = path.replace(/\\/g, '/').toLowerCase()
    return normalized.includes('/faultlogger/') || normalized.startsWith('faultlogger/')
  }

  private static async yieldToEventLoop(): Promise<void> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), 0)
    })
  }
}

class CrashParseState {
  private crashType: string
  private fileName: string
  private timestamp?: number
  private processName?: string
  private pid?: number
  private uid?: number
  private reason?: string
  private errorName?: string
  private errorMessage?: string
  private stringId?: string
  private topStack?: string

  constructor(crashType: string, fileName: string) {
    this.crashType = crashType
    this.fileName = fileName
  }

  consume(rawLine: string): void {
    let line = rawLine.trim()
    if (line.length === 0) {
      return
    }
    this.consumeKeyValue(line)
    this.consumeStack(line)
  }

  build(): ParsedCrashLog | null {
    let timestamp = this.timestamp ?? CrashLogImportRule.parseFilenameTimestamp(this.fileName)
    let processName = this.processName ?? this.parseProcessNameFromFileName()
    let reason = this.reason ?? this.errorMessage ?? this.errorName
    if (timestamp === undefined || !processName || !reason) {
      return null
    }
    return {
      crashType: this.crashType,
      timestamp,
      processName,
      pid: this.pid,
      uid: this.uid,
      reason,
      errorName: this.errorName,
      errorMessage: this.errorMessage,
      stringId: this.stringId,
      topStack: this.topStack
    }
  }

  private consumeKeyValue(line: string): void {
    let colon = line.indexOf(':')
    let equals = line.indexOf('=')
    let separator = -1
    if (colon >= 0 && equals >= 0) {
      separator = Math.min(colon, equals)
    } else {
      separator = colon >= 0 ? colon : equals
    }
    if (separator < 0) {
      this.consumeInlineTimestamp(line)
      return
    }
    let key = line.substring(0, separator).trim().toLowerCase()
    let value = line.substring(separator + 1).trim()
    if (value.length === 0) {
      return
    }
    switch (key) {
      case 'timestamp':
      case 'fault time':
      case 'time': {
        this.timestamp = this.timestamp ?? CrashLogImportRule.parseTimestampValue(value)
        break
      }
      case 'module name':
      case 'process name':
      case 'process_name':
      case 'package_name': {
        this.processName = this.processName ?? CrashLogImportRule.truncate(value)
        break
      }
      case 'pid': {
        this.pid = this.pid ?? CrashLogImportRule.parseNumber(value)
        break
      }
      case 'uid': {
        this.uid = this.uid ?? CrashLogImportRule.parseNumber(value)
        break
      }
      case 'reason': {
        this.reason = this.reason ?? CrashLogImportRule.truncate(value)
        break
      }
      case 'error name': {
        this.errorName = this.errorName ?? CrashLogImportRule.truncate(value)
        break
      }
      case 'error message': {
        this.errorMessage = this.errorMessage ?? CrashLogImportRule.truncate(value)
        break
      }
      case 'stringid': {
        this.stringId = this.stringId ?? CrashLogImportRule.truncate(value)
        break
      }
      default:
        this.consumeInlineTimestamp(line)
        break
    }
  }

  private consumeInlineTimestamp(line: string): void {
    if (this.timestamp !== undefined) {
      return
    }
    let matched = line.match(/\bat\s+(\d{14})\b/)
    if (matched) {
      this.timestamp = CrashLogImportRule.parseTimestampValue(matched[1])
    }
  }

  private consumeStack(line: string): void {
    if (this.topStack !== undefined) {
      return
    }
    if (line.startsWith('#00 ') || line.startsWith('#01 ') || line.startsWith('at ')) {
      this.topStack = CrashLogImportRule.truncate(line)
    }
  }

  private parseProcessNameFromFileName(): string | undefined {
    let matched = this.fileName.match(/^[^-]+-(.+)-\d+-\d{17}\.log$/i)
    return matched ? matched[1] : undefined
  }
}

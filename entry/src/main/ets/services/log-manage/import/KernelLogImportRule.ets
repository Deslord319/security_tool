import zlib from '@ohos.zlib'
import util from '@ohos.util'
import fileIo from '@ohos.file.fs'
import {
  LogDetailTableRow,
  LogEntry,
  LogEventResult,
  LogEventType
} from '../../../models/LogModels'
import {
  LogManageImportDetailStrings,
  LogManageKernelImportStrings
} from '../../../constants/modules/LogManageStrings'
import { LogUtils } from '../../../utils/LogUtils'
import { LogImportHash } from './LogImportHash'
import {
  ImportedLogFile,
  LogImportRule,
  LogImportRuleResult,
  createEmptyLogImportRuleResult
} from './LogImportRule'

interface KernelRuleDefinition {
  id: string
  category: string
}

interface ParsedKernelLine {
  timestamp: number
  comm: string
  pid?: number
  uid?: number
  path?: string
}

type KernelLogLineReader = (
  file: ImportedLogFile,
  onLine: (line: string, lineNumber: number) => Promise<void>
) => Promise<void>

const KERNEL_RULE_HMSEH_DENIED: KernelRuleDefinition = {
  id: 'kernel_hmseh_denied',
  category: LogManageKernelImportStrings.CATEGORY_SECURITY_DENIED
}
const KERNEL_RULE_BINDER_PERMISSION: KernelRuleDefinition = {
  id: 'kernel_binder_perm_failed',
  category: LogManageKernelImportStrings.CATEGORY_BINDER_PERMISSION
}
const KERNEL_RULE_HMDEC: KernelRuleDefinition = {
  id: 'kernel_hmdec_rule',
  category: LogManageKernelImportStrings.CATEGORY_HMDEC
}
const KERNEL_RULE_FS_DEVFS: KernelRuleDefinition = {
  id: 'kernel_fs_devfs_dec',
  category: LogManageKernelImportStrings.CATEGORY_FS_DEVFS
}
const TAG = 'KernelLogImportRule'
const READ_CHUNK_SIZE = 64 * 1024
const YIELD_EVERY_LINES = 200
const PROGRESS_BYTES = 4 * 1024 * 1024
const PROGRESS_LINES = 50000

export class KernelLogImportRule implements LogImportRule {
  readonly name: string = 'kernel'
  private static lineReaderForTest: KernelLogLineReader | null = null

  static setLineReaderForTest(reader: KernelLogLineReader): void {
    KernelLogImportRule.lineReaderForTest = reader
  }

  static resetTestPorts(): void {
    KernelLogImportRule.lineReaderForTest = null
  }

  canHandle(file: ImportedLogFile): boolean {
    let logicalName = KernelLogImportRule.stripGzipSuffix(file.fileName).toLowerCase()
    return KernelLogImportRule.isUnderHilogDirectory(file.normalizedPath) &&
      logicalName.startsWith('hilog_kmsg')
  }

  async parse(file: ImportedLogFile): Promise<LogImportRuleResult> {
    let startedAt = Date.now()
    let result = createEmptyLogImportRuleResult()
    LogUtils.info(TAG, `parse start: file=${file.relativePath}, path=${file.path}`)
    if (KernelLogImportRule.lineReaderForTest) {
      await KernelLogImportRule.lineReaderForTest(file, async (rawLine: string, lineNumber: number): Promise<void> => {
        KernelLogImportRule.parseLineIntoResult(rawLine, lineNumber, file, result)
      })
      LogUtils.info(TAG, `parse done(test): file=${file.relativePath}, entries=${result.entries.length}, dropped=${result.droppedCount}, failed=${result.failedCount}, elapsedMs=${Date.now() - startedAt}`)
      return result
    }
    let textPath = await KernelLogImportRule.prepareTextFile(file)
    await KernelLogImportRule.forEachLine(textPath, async (rawLine: string, lineNumber: number): Promise<void> => {
      KernelLogImportRule.parseLineIntoResult(rawLine, lineNumber, file, result)
    }, file, result, startedAt)
    LogUtils.info(TAG, `parse done: file=${file.relativePath}, entries=${result.entries.length}, dropped=${result.droppedCount}, failed=${result.failedCount}, elapsedMs=${Date.now() - startedAt}`)
    return result
  }

  static async parseTextForTest(file: ImportedLogFile, path: string): Promise<LogImportRuleResult> {
    let result = createEmptyLogImportRuleResult()
    await KernelLogImportRule.forEachLine(path, async (rawLine: string, lineNumber: number): Promise<void> => {
      KernelLogImportRule.parseLineIntoResult(rawLine, lineNumber, file, result)
    })
    return result
  }

  private static parseLineIntoResult(
    rawLine: string,
    lineNumber: number,
    file: ImportedLogFile,
    result: LogImportRuleResult
  ): void {
    let line = rawLine.trim()
    if (line.length === 0 || !line.includes('comm=')) {
      result.droppedCount++
      return
    }
    let rule = KernelLogImportRule.matchRule(line)
    if (!rule) {
      result.droppedCount++
      return
    }
    let parsed = KernelLogImportRule.parseLine(line)
    if (!parsed) {
      result.droppedCount++
      return
    }
    let entry = KernelLogImportRule.buildEntry(line, parsed, rule, file, lineNumber)
    entry.id = LogImportHash.buildId(entry)
    result.entries.push(entry)
  }

  private static async prepareTextFile(file: ImportedLogFile): Promise<string> {
    if (!file.path.toLowerCase().endsWith('.gz')) {
      return file.path
    }
    return KernelLogImportRule.gunzipToSameDirectory(file.path)
  }

  private static async gunzipToSameDirectory(gzipPath: string): Promise<string> {
    let targetPath = KernelLogImportRule.stripGzipSuffix(gzipPath)
    try {
      if (await fileIo.access(targetPath)) {
        let stat = await fileIo.stat(targetPath)
        LogUtils.info(TAG, `gunzip reuse: gzip=${gzipPath}, target=${targetPath}, targetSize=${stat.size}`)
        return targetPath
      }
    } catch (_) {
    }
    let startedAt = Date.now()
    let gzip = zlib.createGZipSync()
    let output = fileIo.openSync(targetPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
    await gzip.gzopen(gzipPath, 'rb')
    let writeOffset = 0
    let nextProgress = PROGRESS_BYTES
    LogUtils.info(TAG, `gunzip start: gzip=${gzipPath}, target=${targetPath}`)
    try {
      while ((await gzip.gzeof()) === 0) {
        let buffer = new ArrayBuffer(READ_CHUNK_SIZE)
        let readCount = await gzip.gzfread(buffer, 1, READ_CHUNK_SIZE)
        if (readCount <= 0) {
          break
        }
        fileIo.writeSync(output.fd, buffer, { offset: writeOffset, length: readCount })
        writeOffset += readCount
        if (writeOffset >= nextProgress) {
          LogUtils.info(TAG, `gunzip progress: target=${targetPath}, bytes=${writeOffset}, elapsedMs=${Date.now() - startedAt}`)
          nextProgress += PROGRESS_BYTES
        }
      }
    } finally {
      await gzip.gzclose()
      fileIo.closeSync(output.fd)
    }
    LogUtils.info(TAG, `gunzip done: gzip=${gzipPath}, target=${targetPath}, bytes=${writeOffset}, elapsedMs=${Date.now() - startedAt}`)
    return targetPath
  }

  private static async forEachLine(
    path: string,
    onLine: (line: string, lineNumber: number) => Promise<void>,
    sourceFile?: ImportedLogFile,
    result?: LogImportRuleResult,
    startedAt?: number
  ): Promise<void> {
    let file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY)
    let decoder = util.TextDecoder.create('utf-8')
    let pending = ''
    let lineNumber = 0
    let readOffset = 0
    let nextByteProgress = PROGRESS_BYTES
    let nextLineProgress = PROGRESS_LINES
    try {
      while (true) {
        let buffer = new ArrayBuffer(READ_CHUNK_SIZE)
        let readCount = fileIo.readSync(file.fd, buffer, {
          offset: readOffset,
          length: READ_CHUNK_SIZE
        })
        if (readCount <= 0) {
          break
        }
        readOffset += readCount
        if (readOffset >= nextByteProgress) {
          LogUtils.info(TAG, `parse byte progress: file=${sourceFile?.relativePath ?? path}, bytes=${readOffset}, lines=${lineNumber}, entries=${result?.entries.length ?? 0}, dropped=${result?.droppedCount ?? 0}, elapsedMs=${startedAt ? Date.now() - startedAt : 0}`)
          nextByteProgress += PROGRESS_BYTES
        }
        let chunk = decoder.decodeToString(new Uint8Array(buffer, 0, readCount))
        let lines = `${pending}${chunk}`.split(/\r?\n/)
        pending = lines.pop() ?? ''
        for (let line of lines) {
          lineNumber++
          await onLine(line, lineNumber)
          if (lineNumber % YIELD_EVERY_LINES === 0) {
            await KernelLogImportRule.yieldToEventLoop()
          }
          if (lineNumber >= nextLineProgress) {
            LogUtils.info(TAG, `parse line progress: file=${sourceFile?.relativePath ?? path}, bytes=${readOffset}, lines=${lineNumber}, entries=${result?.entries.length ?? 0}, dropped=${result?.droppedCount ?? 0}, elapsedMs=${startedAt ? Date.now() - startedAt : 0}`)
            nextLineProgress += PROGRESS_LINES
          }
        }
      }
      if (pending.length > 0) {
        lineNumber++
        await onLine(pending, lineNumber)
      }
    } finally {
      fileIo.closeSync(file.fd)
    }
    LogUtils.info(TAG, `read done: file=${sourceFile?.relativePath ?? path}, bytes=${readOffset}, lines=${lineNumber}`)
  }

  private static async yieldToEventLoop(): Promise<void> {
    await new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), 0)
    })
  }

  private static buildEntry(
    line: string,
    parsed: ParsedKernelLine,
    rule: KernelRuleDefinition,
    file: ImportedLogFile,
    lineNumber: number
  ): LogEntry {
    return {
      id: '',
      timestamp: parsed.timestamp,
      eventType: LogEventType.KERNEL,
      detail: LogImportHash.normalizeText(line),
      processName: parsed.comm,
      pid: parsed.pid,
      uid: parsed.uid,
      filePath: parsed.path,
      rawEventName: rule.id,
      rawAction: rule.category,
      detailRows: KernelLogImportRule.buildDetailRows(rule, file, lineNumber),
      result: LogEventResult.FAILED
    }
  }

  private static buildDetailRows(
    rule: KernelRuleDefinition,
    file: ImportedLogFile,
    lineNumber: number
  ): LogDetailTableRow[] {
    return [
      {
        key: 'kernel.ruleId',
        label: LogManageImportDetailStrings.RULE_ID,
        value: rule.id
      },
      {
        key: 'kernel.category',
        label: LogManageImportDetailStrings.CATEGORY,
        value: rule.category
      },
      {
        key: 'import.sourceFile',
        label: LogManageImportDetailStrings.SOURCE_FILE,
        value: file.relativePath
      },
      {
        key: 'import.lineNumber',
        label: LogManageImportDetailStrings.LINE_NUMBER,
        value: `${lineNumber}`
      }
    ]
  }

  private static matchRule(line: string): KernelRuleDefinition | null {
    let modulePrefix = KernelLogImportRule.parseModulePrefix(line)
    if (modulePrefix === 'hmseh' &&
      line.includes('avc: denied') &&
      line.includes('permissive=0') &&
      !line.includes('path="/sys/power/last_sr"')) {
      return KERNEL_RULE_HMSEH_DENIED
    }
    if (modulePrefix === 'binderfs_write' &&
      line.includes('translate_binder failed') &&
      line.includes('err=E_HM_PERM')) {
      return KERNEL_RULE_BINDER_PERMISSION
    }
    if (modulePrefix === 'hmdec') {
      return KERNEL_RULE_HMDEC
    }
    if (modulePrefix === 'fs_devfs') {
      return KERNEL_RULE_FS_DEVFS
    }
    return null
  }

  private static parseLine(line: string): ParsedKernelLine | null {
    let comm = KernelLogImportRule.firstMatch(line, /\bcomm=([^\s]+)/)
    if (!comm) {
      return null
    }
    let timestamp = KernelLogImportRule.parseTimestamp(line)
    return {
      timestamp,
      comm,
      pid: KernelLogImportRule.parseNumber(KernelLogImportRule.firstMatch(line, /\bpid=(\d+)/)),
      uid: KernelLogImportRule.parseNumber(KernelLogImportRule.firstMatch(line, /\buid=(\d+)/)),
      path: KernelLogImportRule.firstMatch(line, /\bpath="([^"]+)"/)
    }
  }

  private static parseTimestamp(line: string): number {
    let value = KernelLogImportRule.firstMatch(line, /^(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\.(\d{3})/)
    if (!value) {
      return Date.now()
    }
    let parts = line.match(/^(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\.(\d{3})/)
    if (!parts) {
      return Date.now()
    }
    let year = new Date().getFullYear()
    return new Date(
      year,
      Number(parts[1]) - 1,
      Number(parts[2]),
      Number(parts[3]),
      Number(parts[4]),
      Number(parts[5]),
      Number(parts[6])
    ).getTime()
  }

  private static parseModulePrefix(line: string): string {
    let start = line.indexOf('[')
    while (start >= 0) {
      let end = line.indexOf(']', start + 1)
      if (end < 0) {
        break
      }
      let token = line.substring(start + 1, end)
      let separator = token.indexOf(':')
      let prefix = separator >= 0 ? token.substring(0, separator).trim() : token.trim()
      if (prefix.length > 0 && !KernelLogImportRule.isNumericToken(prefix)) {
        return prefix
      }
      start = line.indexOf('[', end + 1)
    }
    return ''
  }

  private static isNumericToken(value: string): boolean {
    let hasDigit = false
    let hasDot = false
    for (let index = 0; index < value.length; index++) {
      let code = value.charCodeAt(index)
      if (code >= 48 && code <= 57) {
        hasDigit = true
        continue
      }
      if (code === 46 && !hasDot) {
        hasDot = true
        continue
      }
      return false
    }
    return hasDigit
  }

  private static firstMatch(value: string, pattern: RegExp): string | undefined {
    let matches = value.match(pattern)
    return matches && matches.length > 1 ? matches[1] : undefined
  }

  private static parseNumber(value?: string): number | undefined {
    if (!value) {
      return undefined
    }
    let parsed = Number(value)
    return Number.isFinite(parsed) ? parsed : undefined
  }

  private static stripGzipSuffix(fileName: string): string {
    return fileName.toLowerCase().endsWith('.gz') ? fileName.substring(0, fileName.length - 3) : fileName
  }

  private static isUnderHilogDirectory(path: string): boolean {
    let normalized = path.replace(/\\/g, '/').toLowerCase()
    return normalized.includes('/hilog/') || normalized.startsWith('hilog/')
  }
}

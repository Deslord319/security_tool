import zlib from '@ohos.zlib'
import fileIo from '@ohos.file.fs'
import {
  LogDetailTableRow,
  LogEntry,
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
import {
  LogImportLineProgress,
  LogImportLineReader
} from './LogImportLineReader'

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

interface PreparedKernelTextFile {
  path: string
  temporary: boolean
}

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
  private static gunzipTargetSequence: number = 0

  static setLineReaderForTest(reader: KernelLogLineReader): void {
    KernelLogImportRule.lineReaderForTest = reader
  }

  static resetTestPorts(): void {
    KernelLogImportRule.lineReaderForTest = null
  }

  static buildGunzipTargetPathForTest(gzipPath: string): string {
    return KernelLogImportRule.buildGunzipTargetPath(gzipPath)
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
    let textFile = await KernelLogImportRule.prepareTextFile(file)
    try {
      await KernelLogImportRule.forEachLine(textFile.path, async (rawLine: string, lineNumber: number): Promise<void> => {
        KernelLogImportRule.parseLineIntoResult(rawLine, lineNumber, file, result)
      }, file, result, startedAt)
    } finally {
      if (textFile.temporary) {
        KernelLogImportRule.unlinkFileQuietly(textFile.path)
      }
    }
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

  private static async prepareTextFile(file: ImportedLogFile): Promise<PreparedKernelTextFile> {
    if (!file.path.toLowerCase().endsWith('.gz')) {
      return {
        path: file.path,
        temporary: false
      }
    }
    return {
      path: await KernelLogImportRule.gunzipToTemporaryFile(file.path),
      temporary: true
    }
  }

  private static async gunzipToTemporaryFile(gzipPath: string): Promise<string> {
    let targetPath = KernelLogImportRule.buildGunzipTargetPath(gzipPath)
    let startedAt = Date.now()
    let gzip = zlib.createGZipSync()
    let output = KernelLogImportRule.openWritableFile(targetPath)
    try {
      await gzip.gzopen(gzipPath, 'rb')
    } catch (err) {
      KernelLogImportRule.closeFileQuietly(output.fd, targetPath)
      throw KernelLogImportRule.toIoError(`open gzip ${gzipPath}`, err)
    }
    let writeOffset = 0
    let nextProgress = PROGRESS_BYTES
    LogUtils.info(TAG, `gunzip start: gzip=${gzipPath}, target=${targetPath}`)
    try {
      while ((await KernelLogImportRule.isGzipEof(gzip, gzipPath)) === 0) {
        let buffer = new ArrayBuffer(READ_CHUNK_SIZE)
        let readCount = await KernelLogImportRule.readGzip(gzip, gzipPath, buffer)
        if (readCount <= 0) {
          break
        }
        KernelLogImportRule.writeFile(output.fd, buffer, writeOffset, readCount)
        writeOffset += readCount
        if (writeOffset >= nextProgress) {
          LogUtils.info(TAG, `gunzip progress: target=${targetPath}, bytes=${writeOffset}, elapsedMs=${Date.now() - startedAt}`)
          nextProgress += PROGRESS_BYTES
        }
      }
    } finally {
      await KernelLogImportRule.closeGzipQuietly(gzip, gzipPath)
      KernelLogImportRule.closeFileQuietly(output.fd, targetPath)
    }
    LogUtils.info(TAG, `gunzip done: gzip=${gzipPath}, target=${targetPath}, bytes=${writeOffset}, elapsedMs=${Date.now() - startedAt}`)
    return targetPath
  }

  private static buildGunzipTargetPath(gzipPath: string): string {
    KernelLogImportRule.gunzipTargetSequence++
    return `${KernelLogImportRule.stripGzipSuffix(gzipPath)}.import_${Date.now()}_${KernelLogImportRule.gunzipTargetSequence}.txt`
  }

  private static async forEachLine(
    path: string,
    onLine: (line: string, lineNumber: number) => Promise<void>,
    sourceFile?: ImportedLogFile,
    result?: LogImportRuleResult,
    startedAt?: number
  ): Promise<void> {
    let readResult = await LogImportLineReader.forEachUtf8Line(path, onLine, {
      yieldEveryLines: YIELD_EVERY_LINES,
      byteProgressInterval: PROGRESS_BYTES,
      lineProgressInterval: PROGRESS_LINES,
      onByteProgress: (progress: LogImportLineProgress): void => {
        LogUtils.info(TAG, `parse byte progress: file=${sourceFile?.relativePath ?? path}, bytes=${progress.bytesRead}, lines=${progress.linesRead}, entries=${result?.entries.length ?? 0}, dropped=${result?.droppedCount ?? 0}, elapsedMs=${startedAt ? Date.now() - startedAt : 0}`)
      },
      onLineProgress: (progress: LogImportLineProgress): void => {
        LogUtils.info(TAG, `parse line progress: file=${sourceFile?.relativePath ?? path}, bytes=${progress.bytesRead}, lines=${progress.linesRead}, entries=${result?.entries.length ?? 0}, dropped=${result?.droppedCount ?? 0}, elapsedMs=${startedAt ? Date.now() - startedAt : 0}`)
      }
    })
    LogUtils.info(TAG, `read done: file=${sourceFile?.relativePath ?? path}, bytes=${readResult.bytesRead}, lines=${readResult.linesRead}`)
  }

  private static openWritableFile(path: string): fileIo.File {
    try {
      return fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
    } catch (err) {
      throw KernelLogImportRule.toIoError(`open output ${path}`, err)
    }
  }

  private static writeFile(fd: number, buffer: ArrayBuffer, offset: number, length: number): void {
    try {
      fileIo.writeSync(fd, buffer, { offset, length })
    } catch (err) {
      throw KernelLogImportRule.toIoError('write gunzip output', err)
    }
  }

  private static closeFileQuietly(fd: number, path: string): void {
    try {
      fileIo.closeSync(fd)
    } catch (err) {
      LogUtils.warn(TAG, `close file failed: path=${path}, err=${JSON.stringify(err)}`)
    }
  }

  private static unlinkFileQuietly(path: string): void {
    try {
      fileIo.unlinkSync(path)
    } catch (err) {
      LogUtils.warn(TAG, `delete temporary file failed: path=${path}, err=${JSON.stringify(err)}`)
    }
  }

  private static async isGzipEof(gzip: zlib.GZip, path: string): Promise<number> {
    try {
      return await gzip.gzeof()
    } catch (err) {
      throw KernelLogImportRule.toIoError(`check gzip eof ${path}`, err)
    }
  }

  private static async readGzip(gzip: zlib.GZip, path: string, buffer: ArrayBuffer): Promise<number> {
    try {
      return await gzip.gzfread(buffer, 1, READ_CHUNK_SIZE)
    } catch (err) {
      throw KernelLogImportRule.toIoError(`read gzip ${path}`, err)
    }
  }

  private static async closeGzipQuietly(gzip: zlib.GZip, path: string): Promise<void> {
    try {
      await gzip.gzclose()
    } catch (err) {
      LogUtils.warn(TAG, `close gzip failed: path=${path}, err=${JSON.stringify(err)}`)
    }
  }

  private static toIoError(action: string, err: Object): Error {
    return new Error(`${action} failed: ${JSON.stringify(err)}`)
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
      detailRows: KernelLogImportRule.buildDetailRows(rule, file, lineNumber)
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

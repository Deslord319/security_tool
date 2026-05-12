import fileIo from '@ohos.file.fs'
import {
  LogDetailTableRow,
  LogEntry,
  LogEventType
} from '../../../models/LogModels'
import { LogManageImportDetailStrings } from '../../../constants/modules/LogManageStrings'
import { LogUtils } from '../../../utils/LogUtils'
import { LogImportHash } from './LogImportHash'
import {
  ImportedLogFile,
  LogImportRule,
  LogImportRuleResult,
  createEmptyLogImportRuleResult
} from './LogImportRule'
import { LogImportLineReader } from './LogImportLineReader'

type SystemParseStrategy = 'whole_failed' | 'time_blocks' | 'title_blocks' | 'snapshot' | 'memory_leak' | 'key_lines'

type SystemPathMatcher = (path: string) => boolean

class SystemRuleDefinition {
  id: string
  category: string
  strategy: SystemParseStrategy
  matcher: SystemPathMatcher

  constructor(id: string, category: string, strategy: SystemParseStrategy, matcher: SystemPathMatcher) {
    this.id = id
    this.category = category
    this.strategy = strategy
    this.matcher = matcher
  }

  match(path: string): boolean {
    return this.matcher(path)
  }
}

interface SystemParsedEvent {
  rule: SystemRuleDefinition
  timestamp?: number
  processName?: string
  detail: string
  detailRows?: LogDetailTableRow[]
}

type SystemLogLineReader = (
  file: ImportedLogFile,
  onLine: (line: string, lineNumber: number) => Promise<void>
) => Promise<void>

const TAG = 'SystemLogImportRule'
const YIELD_EVERY_LINES = 200
const MAX_DETAIL_LENGTH = 280
const MAX_ROW_VALUE_LENGTH = 360
const EPOCH_MILLIS_THRESHOLD = 100000000000
const FUTURE_SKEW_TOLERANCE_MS = 24 * 60 * 60 * 1000

const SYSTEM_RULES: SystemRuleDefinition[] = [
  new SystemRuleDefinition('system_service_timeout', '服务超时异常', 'whole_failed',
    (path: string): boolean => path.includes('/eventlog/service_timeout_warning-') && path.endsWith('.log')),
  new SystemRuleDefinition('system_window_exception', '窗口异常检测', 'whole_failed',
    (path: string): boolean => path.includes('/eventlog/window_exception_detection-') && path.endsWith('.log')),
  new SystemRuleDefinition('system_hisi_diag', '硬件/SoC 诊断', 'time_blocks',
    (path: string): boolean => path.endsWith('/hisi_logs/hisi_diaginfo.log')),
  new SystemRuleDefinition('system_fsck', '文件系统检查', 'title_blocks',
    (path: string): boolean => path.endsWith('/f2fs-tools/fsck.log')),
  new SystemRuleDefinition('system_resize', '文件系统扩容/维护', 'title_blocks',
    (path: string): boolean => path.endsWith('/f2fs-tools/resize.log')),
  new SystemRuleDefinition('system_meminfo', '内存资源快照', 'snapshot',
    (path: string): boolean => path.includes('/memory/proc_meminfo') && path.endsWith('.txt')),
  new SystemRuleDefinition('system_memview', '内存视图快照', 'snapshot',
    (path: string): boolean => path.includes('/memory/proc_memview') && path.endsWith('.txt')),
  new SystemRuleDefinition('system_memory_leak', '内存泄漏诊断', 'memory_leak',
    (path: string): boolean => path.includes('/memory_leak/') && path.endsWith('.txt')),
  new SystemRuleDefinition('system_updater_log', '系统升级/恢复日志', 'key_lines',
    (path: string): boolean => path.endsWith('/updater/updater_log')),
  new SystemRuleDefinition('system_updater_stage', '系统升级阶段日志', 'key_lines',
    (path: string): boolean => path.endsWith('/updater/updater_stage_log')),
  new SystemRuleDefinition('system_installer', '系统安装/参数更新日志', 'key_lines',
    (path: string): boolean => path.endsWith('/log/sys_installer.log')),
  new SystemRuleDefinition('system_hsld', '系统服务启动/挂载日志', 'key_lines',
    (path: string): boolean => path.endsWith('/log/hsld.log'))
]

export class SystemLogImportRule implements LogImportRule {
  readonly name: string = 'system'
  private static lineReaderForTest: SystemLogLineReader | null = null

  static setLineReaderForTest(reader: SystemLogLineReader): void {
    SystemLogImportRule.lineReaderForTest = reader
  }

  static resetTestPorts(): void {
    SystemLogImportRule.lineReaderForTest = null
  }

  canHandle(file: ImportedLogFile): boolean {
    return SystemLogImportRule.findRule(file) !== undefined
  }

  async parse(file: ImportedLogFile): Promise<LogImportRuleResult> {
    let result = createEmptyLogImportRuleResult()
    let rule = SystemLogImportRule.findRule(file)
    if (!rule) {
      return result
    }
    let startedAt = Date.now()
    LogUtils.info(TAG, `parse start: rule=${rule.id}, file=${file.relativePath}, path=${file.path}`)
    try {
      let fallbackTimestamp = await SystemLogImportRule.resolveFallbackTimestamp(file)
      let events = await SystemLogImportRule.parseByRule(file, rule, fallbackTimestamp)
      for (let event of events) {
        let entry = SystemLogImportRule.buildEntry(event, file, fallbackTimestamp)
        entry.id = LogImportHash.buildId(entry)
        result.entries.push(entry)
      }
      LogUtils.info(TAG, `parse done: rule=${rule.id}, file=${file.relativePath}, entries=${result.entries.length}, dropped=${result.droppedCount}, failed=0, elapsedMs=${Date.now() - startedAt}`)
      return result
    } catch (err) {
      result.failedCount++
      LogUtils.warn(TAG, `parse failed: rule=${rule.id}, file=${file.relativePath}, err=${JSON.stringify(err)}, elapsedMs=${Date.now() - startedAt}`)
      return result
    }
  }

  private static async parseByRule(
    file: ImportedLogFile,
    rule: SystemRuleDefinition,
    fallbackTimestamp: number
  ): Promise<SystemParsedEvent[]> {
    switch (rule.strategy) {
      case 'whole_failed':
        return SystemLogImportRule.parseWholeFile(file, rule, fallbackTimestamp)
      case 'time_blocks':
        return SystemLogImportRule.parseTimeBlocks(file, rule)
      case 'title_blocks':
        return SystemLogImportRule.parseTitleBlocks(file, rule)
      case 'snapshot':
        return SystemLogImportRule.parseSnapshot(file, rule, fallbackTimestamp)
      case 'memory_leak':
        return SystemLogImportRule.parseMemoryLeak(file, rule, fallbackTimestamp)
      case 'key_lines':
        return SystemLogImportRule.parseKeyLines(file, rule, fallbackTimestamp)
      default:
        return []
    }
  }

  private static async parseWholeFile(
    file: ImportedLogFile,
    rule: SystemRuleDefinition,
    fallbackTimestamp: number
  ): Promise<SystemParsedEvent[]> {
    let state = new SummaryState()
    await SystemLogImportRule.forEachLine(file, async (line: string): Promise<void> => {
      state.consume(line)
    })
    if (!state.hasContent()) {
      return []
    }
    return [{
      rule,
      timestamp: state.timestamp ?? fallbackTimestamp,
      processName: state.processName ?? SystemLogImportRule.processNameFromPath(file.relativePath),
      detail: SystemLogImportRule.buildSummary(rule.category, state.summary()),
      detailRows: SystemLogImportRule.buildCommonRows(rule, file, state.summary())
    }]
  }

  private static async parseTimeBlocks(file: ImportedLogFile, rule: SystemRuleDefinition): Promise<SystemParsedEvent[]> {
    let events: SystemParsedEvent[] = []
    let currentTitle = ''
    let current = new SummaryState()
    await SystemLogImportRule.forEachLine(file, async (line: string): Promise<void> => {
      let timestamp = SystemLogImportRule.parseHisiTimeLine(line)
      if (timestamp !== undefined) {
        SystemLogImportRule.pushBlockEvent(events, rule, file, currentTitle, current, timestamp)
        currentTitle = line.trim()
        current = new SummaryState()
        current.timestamp = timestamp
        return
      }
      current.consume(line)
    })
    SystemLogImportRule.pushBlockEvent(events, rule, file, currentTitle, current, current.timestamp)
    return events
  }

  private static async parseTitleBlocks(file: ImportedLogFile, rule: SystemRuleDefinition): Promise<SystemParsedEvent[]> {
    let events: SystemParsedEvent[] = []
    let currentTitle = ''
    let current = new SummaryState()
    await SystemLogImportRule.forEachLine(file, async (line: string): Promise<void> => {
      let timestamp = SystemLogImportRule.parseTitleTimestamp(line)
      if (timestamp !== undefined) {
        SystemLogImportRule.pushBlockEvent(events, rule, file, currentTitle, current, timestamp)
        currentTitle = line.trim()
        current = new SummaryState()
        current.timestamp = timestamp
        return
      }
      current.consume(line)
    })
    SystemLogImportRule.pushBlockEvent(events, rule, file, currentTitle, current, current.timestamp)
    return events
  }

  private static async parseSnapshot(
    file: ImportedLogFile,
    rule: SystemRuleDefinition,
    fallbackTimestamp: number
  ): Promise<SystemParsedEvent[]> {
    let state = new SummaryState()
    await SystemLogImportRule.forEachLine(file, async (line: string): Promise<void> => {
      state.consume(line)
    })
    if (!state.hasContent()) {
      return []
    }
    return [{
      rule,
      timestamp: state.timestamp ?? fallbackTimestamp,
      processName: SystemLogImportRule.processNameFromPath(file.relativePath),
      detail: SystemLogImportRule.buildSummary(rule.category, state.summary()),
      detailRows: SystemLogImportRule.buildCommonRows(rule, file, state.summary())
    }]
  }

  private static async parseMemoryLeak(
    file: ImportedLogFile,
    rule: SystemRuleDefinition,
    fallbackTimestamp: number
  ): Promise<SystemParsedEvent[]> {
    let state = new MemoryLeakState(file.fileName)
    await SystemLogImportRule.forEachLine(file, async (line: string): Promise<void> => {
      state.consume(line)
    })
    if (!state.shouldKeep()) {
      return []
    }
    return [{
      rule,
      timestamp: state.timestamp ?? fallbackTimestamp,
      processName: state.processName ?? SystemLogImportRule.processNameFromPath(file.relativePath),
      detail: SystemLogImportRule.buildSummary(rule.category, state.summary()),
      detailRows: SystemLogImportRule.buildCommonRows(rule, file, state.summary())
    }]
  }

  private static async parseKeyLines(
    file: ImportedLogFile,
    rule: SystemRuleDefinition,
    fallbackTimestamp: number
  ): Promise<SystemParsedEvent[]> {
    let events: SystemParsedEvent[] = []
    await SystemLogImportRule.forEachLine(file, async (line: string, lineNumber: number): Promise<void> => {
      if (!SystemLogImportRule.isKeyLine(line)) {
        return
      }
      let normalized = SystemLogImportRule.truncate(line)
      events.push({
        rule,
        timestamp: SystemLogImportRule.parseTimestampFromText(line, fallbackTimestamp),
        processName: SystemLogImportRule.processNameFromPath(file.relativePath),
        detail: SystemLogImportRule.buildSummary(rule.category, normalized),
        detailRows: SystemLogImportRule.buildCommonRows(rule, file, normalized, lineNumber)
      })
    })
    return events
  }

  private static pushBlockEvent(
    events: SystemParsedEvent[],
    rule: SystemRuleDefinition,
    file: ImportedLogFile,
    title: string,
    state: SummaryState,
    timestamp?: number
  ): void {
    if (!state.hasContent()) {
      return
    }
    let summary = state.summary()
    events.push({
      rule,
      timestamp: state.timestamp ?? timestamp,
      processName: state.processName ?? SystemLogImportRule.processNameFromPath(file.relativePath),
      detail: SystemLogImportRule.buildSummary(rule.category, title.length > 0 ? `${title} ${summary}` : summary),
      detailRows: SystemLogImportRule.buildCommonRows(rule, file, summary)
    })
  }

  private static buildEntry(event: SystemParsedEvent, file: ImportedLogFile, fallbackTimestamp: number): LogEntry {
    let timestamp = event.timestamp ?? SystemLogImportRule.parseFilenameTimestamp(file.fileName) ?? fallbackTimestamp
    let detail = LogImportHash.normalizeText(`${event.detail} | ${timestamp}`)
    return {
      id: '',
      timestamp,
      eventType: LogEventType.SYSTEM,
      detail,
      processName: event.processName,
      filePath: file.relativePath,
      rawEventName: event.rule.id,
      rawAction: event.rule.category,
      detailRows: event.detailRows
    }
  }

  private static buildCommonRows(
    rule: SystemRuleDefinition,
    file: ImportedLogFile,
    summary: string,
    lineNumber?: number
  ): LogDetailTableRow[] {
    let rows: LogDetailTableRow[] = [
      { key: 'system.ruleId', label: LogManageImportDetailStrings.RULE_ID, value: rule.id },
      { key: 'system.category', label: LogManageImportDetailStrings.CATEGORY, value: rule.category },
      { key: 'import.sourceFile', label: LogManageImportDetailStrings.SOURCE_FILE, value: file.relativePath },
      { key: 'system.summary', label: '摘要', value: SystemLogImportRule.truncate(summary, MAX_ROW_VALUE_LENGTH) }
    ]
    if (lineNumber !== undefined) {
      rows.push({ key: 'import.lineNumber', label: LogManageImportDetailStrings.LINE_NUMBER, value: `${lineNumber}` })
    }
    return rows
  }

  private static findRule(file: ImportedLogFile): SystemRuleDefinition | undefined {
    let normalized = SystemLogImportRule.normalizePath(file.normalizedPath)
    return SYSTEM_RULES.find((rule: SystemRuleDefinition) => rule.match(normalized))
  }

  private static async forEachLine(
    file: ImportedLogFile,
    onLine: (line: string, lineNumber: number) => Promise<void>
  ): Promise<void> {
    if (SystemLogImportRule.lineReaderForTest) {
      await SystemLogImportRule.lineReaderForTest(file, onLine)
      return
    }
    await LogImportLineReader.forEachUtf8Line(file.path, onLine, {
      yieldEveryLines: YIELD_EVERY_LINES
    })
  }

  private static async resolveFallbackTimestamp(file: ImportedLogFile): Promise<number> {
    let filenameTimestamp = SystemLogImportRule.parseFilenameTimestamp(file.fileName)
    if (filenameTimestamp !== undefined) {
      return filenameTimestamp
    }
    try {
      let stat = await fileIo.stat(file.path)
      if (stat.mtime > 0) {
        return SystemLogImportRule.normalizeEpochMillis(stat.mtime)
      }
    } catch (_) {
    }
    return Date.now()
  }

  static parseFilenameTimestamp(fileName: string): number | undefined {
    let matched = fileName.match(/(\d{17}|\d{14})(?!\d)/)
    if (!matched) {
      return undefined
    }
    return SystemLogImportRule.parseCompactTimestamp(matched[1])
  }

  static parseTimestampFromText(text: string, fallbackTimestamp?: number): number | undefined {
    let matched = text.match(/(\d{4})[/-](\d{2})[/-](\d{2})[- T](\d{2}):(\d{2}):(\d{2})(?:[.:](\d{1,3}))?/)
    if (matched) {
      return new Date(
        Number(matched[1]),
        Number(matched[2]) - 1,
        Number(matched[3]),
        Number(matched[4]),
        Number(matched[5]),
        Number(matched[6]),
        Number((matched[7] ?? '0').padEnd(3, '0'))
      ).getTime()
    }
    let compact = text.match(/\b(\d{17}|\d{14})\b/)
    if (compact) {
      return SystemLogImportRule.parseCompactTimestamp(compact[1])
    }
    return SystemLogImportRule.parseMonthDayTimestamp(text, fallbackTimestamp)
  }

  private static parseCompactTimestamp(value: string): number | undefined {
    if (!/^\d{14}(\d{3})?$/.test(value)) {
      return undefined
    }
    let full = value.length === 14 ? `${value}000` : value
    return new Date(
      Number(full.substring(0, 4)),
      Number(full.substring(4, 6)) - 1,
      Number(full.substring(6, 8)),
      Number(full.substring(8, 10)),
      Number(full.substring(10, 12)),
      Number(full.substring(12, 14)),
      Number(full.substring(14, 17))
    ).getTime()
  }

  static normalizeEpochMillis(value: number): number {
    return value > 0 && value < EPOCH_MILLIS_THRESHOLD ? value * 1000 : value
  }

  private static parseMonthDayTimestamp(text: string, fallbackTimestamp?: number): number | undefined {
    if (fallbackTimestamp === undefined || !Number.isFinite(fallbackTimestamp) || fallbackTimestamp < 0) {
      return undefined
    }
    let matched = text.match(/(^|[^\d])(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?/)
    if (!matched) {
      return undefined
    }
    let fallback = new Date(fallbackTimestamp)
    let parsed = new Date(
      fallback.getFullYear(),
      Number(matched[2]) - 1,
      Number(matched[3]),
      Number(matched[4]),
      Number(matched[5]),
      Number(matched[6]),
      Number((matched[7] ?? '0').padEnd(3, '0'))
    ).getTime()
    if (parsed > fallbackTimestamp + FUTURE_SKEW_TOLERANCE_MS) {
      let previousYear = new Date(parsed)
      previousYear.setFullYear(previousYear.getFullYear() - 1)
      return previousYear.getTime()
    }
    return parsed
  }

  private static parseHisiTimeLine(line: string): number | undefined {
    let matched = line.match(/Time\s*\[([^\]]+)\]/i)
    return matched ? SystemLogImportRule.parseTimestampFromText(matched[1]) : undefined
  }

  private static parseTitleTimestamp(line: string): number | undefined {
    let matched = line.match(/^=+\s*(\d{4}\/\d{2}\/\d{2}\s+\d{2}:\d{2}:\d{2})\s*=+$/)
    return matched ? SystemLogImportRule.parseTimestampFromText(matched[1]) : undefined
  }

  private static isKeyLine(line: string): boolean {
    let normalized = LogImportHash.normalizeText(line)
    if (normalized.length < 8 || SystemLogImportRule.isSeparatorLine(normalized)) {
      return false
    }
    let lower = normalized.toLowerCase()
    return !(lower.includes(' info ') || lower.startsWith('info ') || lower.startsWith('i '))
  }

  private static buildSummary(category: string, text: string): string {
    let normalized = SystemLogImportRule.truncate(text, MAX_DETAIL_LENGTH)
    return normalized.length > 0 ? `${category} | ${normalized}` : category
  }

  static truncate(text: string, maxLength: number = MAX_DETAIL_LENGTH): string {
    let normalized = LogImportHash.normalizeText(text)
    return normalized.length > maxLength ? normalized.substring(0, maxLength) : normalized
  }

  private static normalizePath(path: string): string {
    let normalized = path.replace(/\\/g, '/').toLowerCase()
    return normalized.startsWith('/') ? normalized : `/${normalized}`
  }

  private static processNameFromPath(path: string): string {
    let normalized = path.replace(/\\/g, '/')
    let parts = normalized.split('/').filter((part: string) => part.length > 0)
    return parts.length > 1 ? parts[parts.length - 2] : 'system'
  }

  private static isSeparatorLine(line: string): boolean {
    for (let index = 0; index < line.length; index++) {
      let char = line.charAt(index)
      if (char !== '-' && char !== '=' && char !== '*' && char !== '_' && char !== ' ') {
        return false
      }
    }
    return true
  }
}

class SummaryState {
  timestamp?: number
  processName?: string
  private parts: string[] = []

  consume(line: string): void {
    let normalized = SystemLogImportRule.truncate(line, MAX_ROW_VALUE_LENGTH)
    if (normalized.length === 0 || this.isSeparator(normalized)) {
      return
    }
    this.timestamp = this.timestamp ?? SystemLogImportRule.parseTimestampFromText(normalized)
    this.processName = this.processName ?? this.extractProcessName(normalized)
    if (this.parts.length < 8) {
      this.parts.push(normalized)
    }
  }

  hasContent(): boolean {
    return this.parts.length > 0
  }

  summary(): string {
    return this.parts.join(' ')
  }

  private extractProcessName(line: string): string | undefined {
    let matched = line.match(/^(?:PROCESS_NAME|Process name|Module name)\s*[:=]\s*(.+)$/)
    return matched ? SystemLogImportRule.truncate(matched[1], 120) : undefined
  }

  private isSeparator(line: string): boolean {
    return /^[-=*_ ]+$/.test(line)
  }
}

class MemoryLeakState extends SummaryState {
  private fileName: string
  private lineCount = 0
  private hasTimestamp = false
  private hasPid = false
  private hasMemcheck = false
  private hasMemoryName = false
  private hasDiagnosticKeyword = false

  constructor(fileName: string) {
    super()
    this.fileName = fileName.toLowerCase()
    this.hasDiagnosticKeyword = this.hasDiagnosticKeyword || this.hasDiagnosticName(this.fileName)
  }

  consume(line: string): void {
    this.lineCount++
    let lower = line.toLowerCase()
    this.hasTimestamp = this.hasTimestamp || lower.includes('timestamp:')
    this.hasPid = this.hasPid || lower.includes('pid:')
    this.hasMemcheck = this.hasMemcheck || lower.includes('logger_memcheck')
    this.hasMemoryName = this.hasMemoryName || lower.includes('memoryname:')
    this.hasDiagnosticKeyword = this.hasDiagnosticKeyword || this.hasDiagnosticName(lower)
    this.processName = this.processName ?? this.extractName(line)
    super.consume(line)
  }

  shouldKeep(): boolean {
    if (this.hasTimestamp || this.hasPid || this.hasMemcheck) {
      return true
    }
    if (this.hasMemoryName && this.lineCount >= 20) {
      return true
    }
    return this.hasDiagnosticKeyword && !!this.processName
  }

  private hasDiagnosticName(value: string): boolean {
    return value.includes('smaps') || value.includes('leakstack') || value.includes('sample')
  }

  private extractName(line: string): string | undefined {
    let matched = line.match(/(?:processName|process_name|memoryName)\s*[:=]\s*(.+)$/i)
    return matched ? SystemLogImportRule.truncate(matched[1], 120) : undefined
  }
}

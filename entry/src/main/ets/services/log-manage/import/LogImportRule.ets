import { LogEntry } from '../../../models/LogModels'

export interface ImportedLogFile {
  path: string
  fileName: string
  relativePath: string
  normalizedPath: string
}

export interface LogImportRuleResult {
  entries: LogEntry[]
  droppedCount: number
  failedCount: number
}

export interface LogImportRule {
  readonly name: string
  canHandle(file: ImportedLogFile): boolean
  parse(file: ImportedLogFile): Promise<LogImportRuleResult>
}

export function createEmptyLogImportRuleResult(): LogImportRuleResult {
  return {
    entries: [],
    droppedCount: 0,
    failedCount: 0
  }
}

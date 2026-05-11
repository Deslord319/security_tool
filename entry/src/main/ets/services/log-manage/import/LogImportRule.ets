import { LogEntry } from '../../../models/DataModels'

export interface ImportedLogFile {
  fileName: string
  relativePath: string
  normalizedPath: string
  content: string
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

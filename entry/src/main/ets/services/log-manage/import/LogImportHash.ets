import { LogEntry } from '../../../models/DataModels'

export class LogImportHash {
  static buildId(entry: LogEntry): string {
    let payload = [
      `${entry.eventType}`,
      entry.rawEventName ?? '',
      LogImportHash.normalizeText(entry.detail)
    ].join('|')
    return `import_${entry.eventType}_${LogImportHash.hash(payload)}`
  }

  static normalizeText(text: string): string {
    return text.trim().replace(/\s+/g, ' ')
  }

  private static hash(value: string): string {
    let hash = 0x811c9dc5
    for (let index = 0; index < value.length; index++) {
      hash ^= value.charCodeAt(index)
      hash = Math.imul(hash, 0x01000193)
    }
    return (hash >>> 0).toString(16).padStart(8, '0')
  }
}

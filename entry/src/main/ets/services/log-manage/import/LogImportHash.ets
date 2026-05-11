import { LogEntry } from '../../../models/LogModels'

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
    let trimmed = text.trim()
    let normalized = ''
    let inWhitespace = false
    for (let index = 0; index < trimmed.length; index++) {
      let code = trimmed.charCodeAt(index)
      let whitespace = code === 32 || code === 9 || code === 10 || code === 13 || code === 12
      if (whitespace) {
        if (!inWhitespace) {
          normalized += ' '
          inWhitespace = true
        }
        continue
      }
      normalized += trimmed.charAt(index)
      inWhitespace = false
    }
    return normalized
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

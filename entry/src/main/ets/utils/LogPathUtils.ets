import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'LogPathUtils'
const DOMAIN = 0x0006

export class LogPathUtils {
  static normalizePathCandidate(pathOrUri: string | undefined): string | undefined {
    if (!pathOrUri) {
      return undefined
    }
    let normalized = pathOrUri.trim()
    if (normalized.length === 0) {
      return undefined
    }
    try {
      normalized = decodeURIComponent(normalized)
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `decodeURIComponent failed: ${JSON.stringify(err)}`)
    }
    normalized = LogPathUtils.cutPathSuffix(normalized.replace(/\\/g, '/'))
    if (normalized.length === 0) {
      return undefined
    }
    normalized = normalized.replace(/\/+$/, '')
    return normalized.length > 0 ? normalized : undefined
  }

  static extractPathFromRawText(raw: string | undefined): string | undefined {
    if (!raw) {
      return undefined
    }
    let source = raw.trim().replace(/\\/g, '/')
    if (source.length === 0) {
      return undefined
    }
    let uriMatch = source.match(/file:\/\/[^\s"',}\]]+/i)
    if (uriMatch && uriMatch.length > 0) {
      return LogPathUtils.normalizePathCandidate(uriMatch[0])
    }
    let pathMatch = source.match(/\/(?:storage|data|mnt)\/[^\s"',}\]]+/)
    if (pathMatch && pathMatch.length > 0) {
      return LogPathUtils.normalizePathCandidate(pathMatch[0])
    }
    return undefined
  }

  static resolveAuditFilePath(structuredCandidate: string | undefined, rawTexts: Array<string | undefined>): string | undefined {
    let normalized = LogPathUtils.normalizePathCandidate(structuredCandidate)
    if (normalized) {
      return normalized
    }
    for (let raw of rawTexts) {
      let fallback = LogPathUtils.extractPathFromRawText(raw)
      if (fallback) {
        return fallback
      }
    }
    return undefined
  }

  static buildFileFilterPrefixes(basePrefixes: string[], envDirs: Array<string | undefined>): string[] {
    let prefixes = [...basePrefixes]
    for (let dir of envDirs) {
      let normalized = LogPathUtils.normalizePathCandidate(dir)
      if (!normalized) {
        continue
      }
      let prefix = `${normalized}/`
      if (!prefixes.includes(prefix)) {
        prefixes.push(prefix)
      }
    }
    return prefixes
  }

  static hasAllowedPrefix(candidatePath: string | undefined, prefixes: string[]): boolean {
    let normalized = LogPathUtils.normalizePathCandidate(candidatePath)
    if (!normalized) {
      return false
    }
    for (let prefix of prefixes) {
      if (normalized.startsWith(prefix)) {
        return true
      }
    }
    return false
  }

  private static cutPathSuffix(path: string): string {
    let cutIndex = path.length
    for (let sep of ['?', '#', '&', '"', '\'', ',', '}', ']', ' ']) {
      let index = path.indexOf(sep)
      if (index >= 0 && index < cutIndex) {
        cutIndex = index
      }
    }
    return cutIndex >= 0 ? path.substring(0, cutIndex) : path
  }
}

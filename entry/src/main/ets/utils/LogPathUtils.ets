import { LogUtils } from './LogUtils'
const TAG = 'LogPathUtils'
export class LogPathUtils {
  static buildHmdfsAccountFilesPrefix(userId: number): string {
    return `/data/service/el2/${userId}/hmdfs/account/files/`
  }
  static normalizePathCandidate(pathOrUri: string | undefined): string | undefined {
    let normalized = LogPathUtils.sanitizeRawPathCandidate(pathOrUri)
    if (normalized.length === 0) {
      return undefined
    }
    normalized = LogPathUtils.remapUserAuditPath(normalized)
    normalized = normalized.replace(/\/+$/, '')
    return normalized.length > 0 ? normalized : undefined
  }
  static extractRawAuditPath(structuredCandidate: string | undefined, rawTexts: Array<string | undefined>): string | undefined {
    let structured = LogPathUtils.sanitizeRawPathCandidate(structuredCandidate)
    if (structured) {
      return structured
    }
    for (let raw of rawTexts) {
      let fallback = LogPathUtils.extractRawPathFromRawText(raw)
      if (fallback) {
        return fallback
      }
    }
    return undefined
  }
  private static extractRawPathFromRawText(raw: string | undefined): string | undefined {
    if (!raw) {
      return undefined
    }
    let source = raw.trim().replace(/\\/g, '/')
    if (source.length === 0) {
      return undefined
    }
    let uriMatch = source.match(/file:\/\/[^\s"',}\]]+/i)
    if (uriMatch && uriMatch.length > 0) {
      return LogPathUtils.sanitizeRawPathCandidate(uriMatch[0])
    }
    let pathMatch = source.match(/\/(?:storage|data|mnt)\/[^\s"',}\]]+/)
    if (pathMatch && pathMatch.length > 0) {
      return LogPathUtils.sanitizeRawPathCandidate(pathMatch[0])
    }
    return undefined
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
  private static sanitizeRawPathCandidate(pathOrUri: string | undefined): string {
    if (!pathOrUri) {
      return ''
    }
    let normalized = pathOrUri.trim()
    if (normalized.length === 0) {
      return ''
    }
    try {
      normalized = decodeURIComponent(normalized)
    } catch (err) {
      LogUtils.warn(TAG, `decodeURIComponent failed: ${JSON.stringify(err)}`)
    }
    return LogPathUtils.cutPathSuffix(normalized.replace(/\\/g, '/'))
  }
  private static remapUserAuditPath(path: string): string {
    let docsMatched = path.match(/^\/data\/service\/el2\/\d+\/hmdfs\/account\/files\/Docs\/(Download|Documents|Desktop)(?:\/(.*))?$/)
    if (docsMatched) {
      let baseDir = docsMatched[1]
      let remainder = docsMatched[2] ? `/${docsMatched[2]}` : ''
      let remapped = `/storage/Users/currentUser/${baseDir}${remainder}`
      LogUtils.info(TAG,
        `remap audit path by rule=hmdfs_docs_${baseDir.toLowerCase()}, rawPath=${path}, normalizedPath=${remapped}`
      )
      return remapped
    }
    let rootMatched = path.match(/^\/data\/service\/el2\/\d+\/hmdfs\/account\/files(?:\/(.*))?$/)
    if (!rootMatched) {
      return path
    }
    let remainder = rootMatched[1] ? `/${rootMatched[1]}` : ''
    let remapped = `/storage/Users/currentUser${remainder}`
    LogUtils.info(TAG,
      `remap audit path by rule=hmdfs_account_files_root, rawPath=${path}, normalizedPath=${remapped}`
    )
    return remapped
  }
}

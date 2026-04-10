import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LogTimestampResolver'
const UNIX_MILLIS_THRESHOLD = 1_000_000_000_000

export function resolveCrashSourceTimestamp(
  rawValues: Array<Object | undefined>,
  nowProvider: () => number
): number {
  for (const rawValue of rawValues) {
    const parsed = parseFlexibleTimestamp(rawValue)
    if (parsed !== undefined) {
      return parsed
    }
  }
  return nowProvider()
}

export function resolveAuditSourceTimestamp(rawValue: string, nowProvider: () => number): number {
  const parsed = parseStrictAuditTimestamp(rawValue)
  if (parsed !== undefined) {
    return parsed
  }
  LogUtils.warn(TAG, `resolveAuditSourceTimestamp fallback: invalid_audit_timestamp, raw=${rawValue}`)
  return nowProvider()
}

function parseFlexibleTimestamp(rawValue: Object | undefined): number | undefined {
  if (typeof rawValue === 'number') {
    return normalizeUnixTimestamp(rawValue)
  }
  if (typeof rawValue !== 'string') {
    return undefined
  }
  const trimmed = rawValue.trim()
  if (trimmed.length === 0) {
    return undefined
  }
  const numeric = Number(trimmed)
  if (Number.isFinite(numeric)) {
    return normalizeUnixTimestamp(numeric)
  }
  const parsed = Date.parse(trimmed)
  return Number.isFinite(parsed) ? parsed : undefined
}

function parseStrictAuditTimestamp(rawValue: string): number | undefined {
  if (!/^\d{14}$/.test(rawValue)) {
    return undefined
  }
  const year = parseInt(rawValue.substring(0, 4))
  const month = parseInt(rawValue.substring(4, 6))
  const day = parseInt(rawValue.substring(6, 8))
  const hour = parseInt(rawValue.substring(8, 10))
  const minute = parseInt(rawValue.substring(10, 12))
  const second = parseInt(rawValue.substring(12, 14))
  const parsed = new Date(year, month - 1, day, hour, minute, second)
  if (
    parsed.getFullYear() !== year ||
    parsed.getMonth() !== month - 1 ||
    parsed.getDate() !== day ||
    parsed.getHours() !== hour ||
    parsed.getMinutes() !== minute ||
    parsed.getSeconds() !== second
  ) {
    return undefined
  }
  return parsed.getTime()
}

function normalizeUnixTimestamp(value: number): number | undefined {
  if (!Number.isFinite(value) || value <= 0) {
    return undefined
  }
  if (value < UNIX_MILLIS_THRESHOLD) {
    return Math.floor(value * 1000)
  }
  return Math.floor(value)
}

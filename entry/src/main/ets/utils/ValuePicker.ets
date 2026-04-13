import { LooseRecord } from '../types/LooseValueTypes'

export function generateRandomSuffix(length: number = 8): string {
  return Math.random().toString(36).substring(2, 2 + length)
}

export function pickStringFromRecords(
  sources: LooseRecord | LooseRecord[],
  keys: string[]
): string | undefined {
  const normalized = Array.isArray(sources) ? sources : [sources]
  for (const source of normalized) {
    for (const key of keys) {
      const raw = source[key]
      if (typeof raw === 'string' && raw.trim().length > 0) {
        return raw.trim()
      }
    }
  }
  return undefined
}

export function pickNumberFromRecords(
  sources: LooseRecord | LooseRecord[],
  keys: string[],
  supportHex: boolean = false
): number | undefined {
  const normalized = Array.isArray(sources) ? sources : [sources]
  for (const source of normalized) {
    for (const key of keys) {
      const raw = source[key]
      if (typeof raw === 'number' && Number.isFinite(raw)) {
        return raw
      }
      if (typeof raw === 'string') {
        const trimmed = raw.trim()
        if (trimmed.length === 0) {
          continue
        }
        if (supportHex) {
          const radix = trimmed.startsWith('0x') || trimmed.startsWith('0X') ? 16 : 10
          const parsed = parseInt(trimmed.replace(/^0x/i, ''), radix)
          if (Number.isFinite(parsed)) {
            return parsed
          }
        } else {
          const parsed = Number(trimmed)
          if (Number.isFinite(parsed)) {
            return parsed
          }
        }
      }
    }
  }
  return undefined
}

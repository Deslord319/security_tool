import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { LooseRecord } from '../types/LooseValueTypes'
import { LogUtils } from './LogUtils'

const TAG = 'ValuePicker'
const RANDOM_ALPHABET = 'abcdefghijklmnopqrstuvwxyz0123456789'
let fallbackSuffixCounter = 0
let randomFallbackLogged = false

export function generateRandomSuffix(length: number = 8): string {
  let normalizedLength = normalizeSuffixLength(length)
  if (normalizedLength === 0) {
    return ''
  }
  try {
    let randomBytes = cryptoFramework.createRandom().generateRandomSync(normalizedLength).data
    let result = ''
    for (let i = 0; i < randomBytes.length && result.length < normalizedLength; i++) {
      result += RANDOM_ALPHABET.charAt(randomBytes[i] % RANDOM_ALPHABET.length)
    }
    if (result.length === normalizedLength) {
      return result
    }
    logRandomFallbackOnce('random byte length mismatch')
    return generateFallbackSuffix(normalizedLength)
  } catch (err) {
    logRandomFallbackOnce(`random generation failed: ${JSON.stringify(err)}`)
    return generateFallbackSuffix(normalizedLength)
  }
}

function logRandomFallbackOnce(reason: string): void {
  if (randomFallbackLogged) {
    return
  }
  randomFallbackLogged = true
  LogUtils.warn(TAG, `generateRandomSuffix fallback activated: ${reason}`)
}

function normalizeSuffixLength(length: number): number {
  if (!Number.isFinite(length) || length <= 0) {
    return 0
  }
  return Math.floor(length)
}

function generateFallbackSuffix(length: number): string {
  fallbackSuffixCounter++
  let seed = `${Date.now().toString(36)}${fallbackSuffixCounter.toString(36)}`
  while (seed.length < length) {
    fallbackSuffixCounter++
    seed += fallbackSuffixCounter.toString(36)
  }
  return seed.slice(-length)
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

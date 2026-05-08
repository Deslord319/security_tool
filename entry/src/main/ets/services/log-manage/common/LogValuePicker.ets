import { pickNumberFromRecords, pickStringFromRecords } from '../../../utils/ValuePicker'
import { LooseRecord } from '../../../types/LooseValueTypes'

function normalizeSources(
  sources: LooseRecord | LooseRecord[]
): LooseRecord[] {
  return Array.isArray(sources) ? sources : [sources]
}

export function pickString(
  sources: LooseRecord | LooseRecord[],
  keys: string[]
): string | undefined {
  return pickStringFromRecords(normalizeSources(sources), keys)
}

export function pickNumber(
  sources: LooseRecord | LooseRecord[],
  keys: string[]
): number | undefined {
  return pickNumberFromRecords(normalizeSources(sources), keys)
}

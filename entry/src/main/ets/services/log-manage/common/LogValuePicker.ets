import { pickNumberFromRecords, pickStringFromRecords } from '../../../utils/ValuePicker'

type LogValuePickerObject = Object

function normalizeSources(
  sources: LogValuePickerObject | LogValuePickerObject[]
): LogValuePickerObject[] {
  return Array.isArray(sources) ? sources : [sources]
}

export function pickString(
  sources: LogValuePickerObject | LogValuePickerObject[],
  keys: string[]
): string | undefined {
  return pickStringFromRecords(normalizeSources(sources) as Record<string, Object | string | number | boolean | undefined>[], keys)
}

export function pickNumber(
  sources: LogValuePickerObject | LogValuePickerObject[],
  keys: string[]
): number | undefined {
  return pickNumberFromRecords(normalizeSources(sources) as Record<string, Object | string | number | boolean | undefined>[], keys)
}

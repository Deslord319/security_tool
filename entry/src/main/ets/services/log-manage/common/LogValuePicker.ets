type LogValuePickerField = string | number | boolean | Object | undefined
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
  for (const source of normalizeSources(sources)) {
    const sourceMap = source as Record<string, LogValuePickerField>
    for (const key of keys) {
      const raw = sourceMap[key]
      if (typeof raw === 'string' && raw.trim().length > 0) {
        return raw.trim()
      }
    }
  }
  return undefined
}

export function pickNumber(
  sources: LogValuePickerObject | LogValuePickerObject[],
  keys: string[]
): number | undefined {
  for (const source of normalizeSources(sources)) {
    const sourceMap = source as Record<string, LogValuePickerField>
    for (const key of keys) {
      const raw = sourceMap[key]
      if (typeof raw === 'number' && Number.isFinite(raw)) {
        return raw
      }
      if (typeof raw === 'string') {
        const parsed = Number(raw)
        if (Number.isFinite(parsed)) {
          return parsed
        }
      }
    }
  }
  return undefined
}

type EventPayloadRecord = Record<string, Object>

export function collectPayloadSources(data: Object): EventPayloadRecord[] {
  const sources: EventPayloadRecord[] = []
  const root = toRecord(data)
  const parameters = toRecord((data as Record<string, Object>).parameters as Object)
  const want = readObjectField(root, 'want')
  const wantParameters = readObjectField(want, 'parameters')
  const rootData = parseJsonObjectField(root, 'data')
  const wantData = parseJsonObjectField(want, 'data')

  pushRecord(sources, root)
  pushRecord(sources, parameters)
  pushRecord(sources, want)
  pushRecord(sources, wantParameters)
  pushRecord(sources, rootData)
  pushRecord(sources, wantData)

  pushRecord(sources, readDeviceField(root))
  pushRecord(sources, readDeviceField(parameters))
  pushRecord(sources, readDeviceField(want))
  pushRecord(sources, readDeviceField(wantParameters))
  pushRecord(sources, readDeviceField(rootData))
  pushRecord(sources, readDeviceField(wantData))
  return sources
}

export function pickNumber(sources: EventPayloadRecord[], keys: string[]): number {
  for (const source of sources) {
    for (const key of keys) {
      const value = source[key]
      if (typeof value === 'number' && Number.isFinite(value)) {
        return value
      }
      if (typeof value === 'string') {
        const normalized = value.trim()
        if (normalized.length === 0) {
          continue
        }
        const radix = normalized.startsWith('0x') || normalized.startsWith('0X') ? 16 : 10
        const parsed = parseInt(normalized.replace(/^0x/i, ''), radix)
        if (Number.isFinite(parsed)) {
          return parsed
        }
      }
    }
  }
  return Number.NaN
}

export function pickString(sources: EventPayloadRecord[], keys: string[]): string {
  for (const source of sources) {
    for (const key of keys) {
      const value = source[key]
      if (typeof value === 'string' && value.trim().length > 0) {
        return value.trim()
      }
    }
  }
  return ''
}

export function pushRecord(target: EventPayloadRecord[], value: EventPayloadRecord | undefined): void {
  if (value === undefined) {
    return
  }
  if (target.some((item: EventPayloadRecord) => item === value)) {
    return
  }
  target.push(value)
}

export function toRecord(value: Object | undefined | null): EventPayloadRecord | undefined {
  if (!value || typeof value !== 'object') {
    return undefined
  }
  return value as EventPayloadRecord
}

export function readObjectField(
  source: EventPayloadRecord | undefined,
  key: string
): EventPayloadRecord | undefined {
  if (source === undefined) {
    return undefined
  }
  return toRecord(source[key])
}

export function parseJsonObjectField(
  source: EventPayloadRecord | undefined,
  key: string
): EventPayloadRecord | undefined {
  if (source === undefined) {
    return undefined
  }
  const value = source[key]
  if (typeof value !== 'string') {
    return undefined
  }
  const normalized = value.trim()
  if (normalized.length === 0 || !normalized.startsWith('{')) {
    return undefined
  }
  try {
    return toRecord(JSON.parse(normalized) as Object)
  } catch (_err) {
    return undefined
  }
}

export function readDeviceField(source: EventPayloadRecord | undefined): EventPayloadRecord | undefined {
  if (source === undefined) {
    return undefined
  }
  return readObjectField(source, 'device') ||
    readObjectField(source, 'remoteDevice') ||
    readObjectField(source, 'remote_device') ||
    readObjectField(source, 'bluetoothDevice') ||
    readObjectField(source, 'usbDevice') ||
    readObjectField(source, 'usb_device')
}

export function toRecordArray(value: Object | undefined | null): EventPayloadRecord[] {
  if (!Array.isArray(value)) {
    return []
  }
  const result: EventPayloadRecord[] = []
  for (const item of value as Object[]) {
    const record = toRecord(item)
    if (record) {
      result.push(record)
    }
  }
  return result
}

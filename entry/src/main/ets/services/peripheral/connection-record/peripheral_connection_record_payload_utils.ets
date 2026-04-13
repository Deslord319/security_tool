import { LooseRecord, LooseValue } from '../../../types/LooseValueTypes'
import { pickNumberFromRecords, pickStringFromRecords } from '../../../utils/ValuePicker'

type EventPayloadRecord = LooseRecord

export function collectPayloadSources(data: Object): EventPayloadRecord[] {
  const sources: EventPayloadRecord[] = []
  const root = toRecord(data)
  const parameters = toRecord((data as LooseRecord).parameters)
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
  const result = pickNumberFromRecords(sources, keys, true)
  return result !== undefined ? result : Number.NaN
}

export function pickString(sources: EventPayloadRecord[], keys: string[]): string {
  return pickStringFromRecords(sources, keys) ?? ''
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

export function toRecord(value: LooseValue | null): EventPayloadRecord | undefined {
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
    return toRecord(JSON.parse(normalized) as LooseValue)
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

export function toRecordArray(value: LooseValue | null): EventPayloadRecord[] {
  if (!Array.isArray(value)) {
    return []
  }
  const result: EventPayloadRecord[] = []
  for (const item of value as LooseValue[]) {
    const record = toRecord(item)
    if (record) {
      result.push(record)
    }
  }
  return result
}

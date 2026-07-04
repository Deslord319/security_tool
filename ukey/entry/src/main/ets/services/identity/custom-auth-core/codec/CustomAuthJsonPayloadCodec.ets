import { util } from '@kit.ArkTS'

const ENCODING = 'utf-8'
const TEXT_ENCODER = new util.TextEncoder()
const TEXT_DECODER = util.TextDecoder.create(ENCODING)

function base64Encode(data: Uint8Array): string {
  const helper = new util.Base64Helper()
  let encoded = helper.encodeToStringSync(data)
  while (encoded.length % 4 !== 0) {
    encoded += '='
  }
  return encoded
}

function base64Decode(str: string): Uint8Array {
  const helper = new util.Base64Helper()
  return helper.decodeSync(str)
}

export function encodePayload(obj: Record<string, Object | null>): Uint8Array {
  const json = JSON.stringify(obj)
  return TEXT_ENCODER.encodeInto(json)
}

export function decodePayload(data: Uint8Array): Record<string, Object | null> {
  const json = TEXT_DECODER.decodeToString(data)
  return JSON.parse(json) as Record<string, Object | null>
}

export function encodePayloadField(data: Uint8Array): string {
  return base64Encode(data)
}

export function decodePayloadField(value: Object | null): Uint8Array | null {
  if (value === null || value === undefined) {
    return null
  }
  return base64Decode(value as string)
}

export function decodeIntField(value: Object | null): number | null {
  if (value === null || value === undefined) {
    return null
  }
  return value as number
}

export function decodeStringField(value: Object | null): string | null {
  if (value === null || value === undefined) {
    return null
  }
  return value as string
}

// Encrypted JSON payloads are strict: missing or unknown fields are protocol errors.
export function requireField(payload: Record<string, Object | null>, key: string): Object {
  const v = payload[key]
  if (v === null || v === undefined) {
    throw new Error(`payload missing required field: ${key}`)
  }
  return v
}

export function rejectExtraFields(payload: Record<string, Object | null>, allowedKeys: string[]): void {
  const allowed = new Set<string>(allowedKeys)
  for (const key of Object.keys(payload)) {
    if (!allowed.has(key)) {
      throw new Error(`payload has unexpected field: ${key}`)
    }
  }
}

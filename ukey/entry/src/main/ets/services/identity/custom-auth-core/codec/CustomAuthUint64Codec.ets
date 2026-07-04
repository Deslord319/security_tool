// Convert uint64 byte sequences to decimal strings without JS number precision loss.

export function decodeUint64Be(bytes: Uint8Array): string {
  if (bytes.length !== 8) {
    throw new Error(`decodeUint64Be: expected 8 bytes, got ${bytes.length}`)
  }
  let v = 0n
  for (let i = 0; i < bytes.length; i++) {
    v = (v << 8n) | BigInt(bytes[i])
  }
  return v.toString()
}

export function decodeUint64Le(bytes: Uint8Array): string {
  if (bytes.length !== 8) {
    throw new Error(`decodeUint64Le: expected 8 bytes, got ${bytes.length}`)
  }
  let v = 0n
  for (let i = bytes.length - 1; i >= 0; i--) {
    v = (v << 8n) | BigInt(bytes[i])
  }
  return v.toString()
}

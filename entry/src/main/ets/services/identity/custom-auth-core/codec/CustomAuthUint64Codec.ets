// Convert uint64 decimal strings to/from big-endian bytes without JS number precision loss.

export function encodeUint64Be(decimalStr: string): Uint8Array {
  let v = BigInt(decimalStr)
  if (v < 0n || v > 0xFFFFFFFFFFFFFFFFn) {
    throw new Error(`encodeUint64Be: value out of uint64 range: ${decimalStr}`)
  }
  const bytes = new Uint8Array(8)
  for (let i = 7; i >= 0; i--) {
    bytes[i] = Number(v & 0xFFn)
    v = v >> 8n
  }
  return bytes
}

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

// Convert a uint64 big-endian byte sequence to a decimal string without JS number precision loss.

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

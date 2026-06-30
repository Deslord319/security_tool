import { rpc } from '@kit.IPCKit'
import type {
  EncryptedData,
  AlgorithmParam,
  InitOutput,
  BeginEnrollInput,
  EndEnrollInput,
  EndEnrollOutput,
  BeginAuthenticateInput,
} from './CustomAuthTypes'

// byte[] is encoded as int32(count) + N * int32(byte), matching the native IDL side.
export function writeByteArray(data: rpc.MessageSequence, arr: number[]): void {
  data.writeInt(arr.length)
  for (const byte of arr) {
    data.writeInt(byte)
  }
}

// When the count is already consumed by the caller, pass it as preReadLen.
export function readByteArray(data: rpc.MessageSequence, preReadLen?: number): number[] {
  const len = preReadLen !== undefined ? preReadLen : data.readInt()
  const result: number[] = []
  for (let i = 0; i < len; i++) {
    result.push(data.readInt())
  }
  return result
}

// string[] is encoded as int32(count) + N * string.
export function writeStringArray(data: rpc.MessageSequence, arr: string[]): void {
  data.writeInt(arr.length)
  for (const s of arr) {
    data.writeString(s)
  }
}

export function readStringArray(data: rpc.MessageSequence): string[] {
  const len = data.readInt()
  const result: string[] = []
  for (let i = 0; i < len; i++) {
    result.push(data.readString())
  }
  return result
}

// templateId is uint64 on the native side; serialize as decimal string to avoid JS precision loss.
export function writeTemplateId(data: rpc.MessageSequence, templateId: string): void {
  data.writeString(templateId)
}

export function readTemplateId(data: rpc.MessageSequence): string {
  return data.readString()
}

export function writeEncryptedData(data: rpc.MessageSequence, ed: EncryptedData): void {
  try {
    writeByteArray(data, ed.nonce)
    writeByteArray(data, ed.tag)
    writeByteArray(data, ed.ciphertext)
  } catch (e) {
    throw new Error(`writeEncryptedData failed: ${e}`)
  }
}

function readEncryptedData(data: rpc.MessageSequence): EncryptedData {
  return {
    nonce: readByteArray(data),
    tag: readByteArray(data),
    ciphertext: readByteArray(data),
  }
}

function readRawAlgorithmParam(data: rpc.MessageSequence): AlgorithmParam {
  try {
    return {
      // Native code writes these uint8 fields widened to int32.
      asymmetricKeyExchangeAlgorithm: data.readInt(),
      asymmetricEncryptionAlgorithm: data.readInt(),
      symmetricEncryptionAlgorithm: data.readInt(),
      keyDerivationAlgorithm: data.readInt(),
    }
  } catch (e) {
    throw new Error(`readAlgorithmParam failed: ${e}`)
  }
}

// InitOutput = 4 algorithm arrays + authenticatorTemplateIds.
export function writeInitOutput(data: rpc.MessageSequence, out: InitOutput): void {
  try {
    writeByteArray(data, out.asymmetricKeyExchangeAlgorithms)
    writeByteArray(data, out.asymmetricEncryptionAlgorithms)
    writeByteArray(data, out.symmetricEncryptionAlgorithms)
    writeByteArray(data, out.keyDerivationAlgorithms)
    writeStringArray(data, out.authenticatorTemplateIds)
  } catch (e) {
    throw new Error(`writeInitOutput failed: ${e}`)
  }
}

export function readBeginEnrollInput(data: rpc.MessageSequence): BeginEnrollInput {
  try {
    const requestId = data.readInt()
    const algorithmParam = readRawAlgorithmParam(data)
    return { requestId, algorithmParam }
  } catch (e) {
    throw new Error(`readBeginEnrollInput failed: ${e}`)
  }
}

// EndEnrollInput must follow the native write order exactly.
export function readEndEnrollInput(data: rpc.MessageSequence): EndEnrollInput {
  try {
    return {
      requestId: data.readInt(),
      templateId: readTemplateId(data),
      userId: data.readInt(),
      userEnrolledTemplateIds: readStringArray(data),
      salt: readByteArray(data),
      publicKey: readByteArray(data),
      challenge: readByteArray(data),
      encryptedData: readEncryptedData(data),
    }
  } catch (e) {
    throw new Error(`readEndEnrollInput failed: ${e}`)
  }
}

export function writeEndEnrollOutput(data: rpc.MessageSequence, output: EndEnrollOutput): void {
  try {
    data.writeInt(output.resultCode)
    writeByteArray(data, output.encryptedData.nonce)
    writeByteArray(data, output.encryptedData.tag)
    writeByteArray(data, output.encryptedData.ciphertext)
  } catch (e) {
    throw new Error(`writeEndEnrollOutput failed: ${e}`)
  }
}

export function readBeginAuthenticateInput(data: rpc.MessageSequence): BeginAuthenticateInput {
  try {
    return {
      requestId: data.readInt(),
      algorithmParam: readRawAlgorithmParam(data),
      userId: data.readInt(),
      salt: readByteArray(data),
      challenge: readByteArray(data),
    }
  } catch (e) {
    throw new Error(`readBeginAuthenticateInput failed: ${e}`)
  }
}

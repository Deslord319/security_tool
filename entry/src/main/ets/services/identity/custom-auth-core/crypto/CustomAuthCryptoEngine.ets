import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { LogUtils } from '../../../../utils/LogUtils'

const TAG = 'CustomAuth.Crypto'
const ECC_P256_CURVE = 'NID_X9_62_prime256v1'
const RSA_OAEP_SHA256_CIPHER_SPEC = 'RSA4096|PKCS1_OAEP|SHA256|MGF1_SHA256'

// P-256 domain parameters used to validate peer ECDH public keys before key agreement.
const P256_PRIME = (1n << 256n) - (1n << 224n) + (1n << 192n) + (1n << 96n) - 1n
const P256_B_COEFFICIENT = 0x5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604bn

function bytesToBigInt(bytes: Uint8Array): bigint {
  let v = 0n
  for (let i = 0; i < bytes.length; i++) {
    v = (v << 8n) | BigInt(bytes[i])
  }
  return v
}

// Reject invalid-curve points before converting the peer public key.
function isOnCurveP256(x: bigint, y: bigint): boolean {
  const lhs = (y * y) % P256_PRIME
  const xCubed = (x * x % P256_PRIME) * x % P256_PRIME
  const rhs = (xCubed - (3n * x) % P256_PRIME + P256_B_COEFFICIENT + P256_PRIME) % P256_PRIME
  return lhs === rhs
}

export interface EcdhKeyPair {
  pubKey: Uint8Array   // 65B uncompressed P-256
  privKey: Uint8Array
  keyPair: cryptoFramework.KeyPair
}

export interface AeadResult {
  ciphertext: Uint8Array
  nonce: Uint8Array
  tag: Uint8Array
}

export interface RsaKeyPair {
  pubKey: Uint8Array
  privKey: Uint8Array
  keyPair: cryptoFramework.KeyPair
}

export async function generateEcdhKeyPair(): Promise<EcdhKeyPair | null> {
  try {
    const generator = cryptoFramework.createAsyKeyGenerator('ECC256')
    const keyPair = await generator.generateKeyPair()
    const pkX = keyPair.pubKey.getAsyKeySpec(cryptoFramework.AsyKeySpecItem.ECC_PK_X_BN) as bigint
    const pkY = keyPair.pubKey.getAsyKeySpec(cryptoFramework.AsyKeySpecItem.ECC_PK_Y_BN) as bigint
    const pubKeyRaw = cryptoFramework.ECCKeyUtil.getEncodedPoint(ECC_P256_CURVE, { x: pkX, y: pkY }, 'UNCOMPRESSED')
    const priEncoded = await keyPair.priKey.getEncoded()
    return {
      pubKey: pubKeyRaw,
      privKey: priEncoded.data,
      keyPair,
    }
  } catch (e) {
    LogUtils.error(TAG, `generateEcdhKeyPair failed: ${e}`)
    return null
  }
}

export async function ecdhSharedSecret(localKeyPair: cryptoFramework.KeyPair, peerPubKeyData: Uint8Array): Promise<Uint8Array | null> {
  try {
    // Peer key must be an uncompressed, non-identity P-256 point.
    if (peerPubKeyData.length !== 65 || peerPubKeyData[0] !== 0x04) {
      LogUtils.error(TAG,
        `ecdhSharedSecret: invalid P-256 uncompressed point (len=${peerPubKeyData.length}, prefix=0x${(peerPubKeyData[0] ?? 0).toString(16)})`)
      return null
    }
    let isIdentity = true
    for (let i = 1; i < 65; i++) {
      if (peerPubKeyData[i] !== 0) { isIdentity = false; break; }
    }
    if (isIdentity) {
      LogUtils.error(TAG, 'ecdhSharedSecret: rejecting identity point')
      return null
    }
    // Validate X/Y on the P-256 curve before passing the point to cryptoFramework.
    const x = bytesToBigInt(peerPubKeyData.slice(1, 33))
    const y = bytesToBigInt(peerPubKeyData.slice(33, 65))
    if (!isOnCurveP256(x, y)) {
      LogUtils.error(TAG, 'ecdhSharedSecret: rejecting off-curve P-256 point')
      return null
    }
    const point = cryptoFramework.ECCKeyUtil.convertPoint(ECC_P256_CURVE, peerPubKeyData)
    const eccCommonParamsSpec = cryptoFramework.ECCKeyUtil.genECCCommonParamsSpec(ECC_P256_CURVE)
    const eccPubKeySpec: cryptoFramework.ECCPubKeySpec = {
      algName: 'ECC',
      specType: cryptoFramework.AsyKeySpecType.PUBLIC_KEY_SPEC,
      params: eccCommonParamsSpec,
      pk: point,
    }
    const generatorBySpec = cryptoFramework.createAsyKeyGeneratorBySpec(eccPubKeySpec)
    const peerPubKey = await generatorBySpec.generatePubKey()
    const agreement = cryptoFramework.createKeyAgreement('ECC256')
    const secret = await agreement.generateSecret(localKeyPair.priKey, peerPubKey)
    return secret.data
  } catch (e) {
    LogUtils.error(TAG, `ecdhSharedSecret failed: ${e}`)
    return null
  }
}

export async function hkdfDerive(salt: Uint8Array, info: Uint8Array, inputKey: Uint8Array, outLen: number): Promise<Uint8Array | null> {
  try {
    const spec: cryptoFramework.HKDFSpec = {
      algName: 'HKDF',
      salt,
      info,
      key: inputKey,
      keySize: outLen,
    }
    const kdf = cryptoFramework.createKdf('HKDF|SHA256')
    const derived = await kdf.generateSecret(spec)
    return derived.data
  } catch (e) {
    LogUtils.error(TAG, `hkdfDerive failed: ${e}`)
    return null
  }
}

// AES-256-GCM uses message-type AAD to bind encrypted CustomAuth payloads.
export async function aesGcmEncrypt(key: Uint8Array, plaintext: Uint8Array, aad: Uint8Array): Promise<AeadResult | null> {
  try {
    const nonce = await generateRandom(12)
    const symGenerator = cryptoFramework.createSymKeyGenerator('AES256')
    const symKey = await symGenerator.convertKey({ data: key })

    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding')
    const gcmParams: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: { data: nonce },
      aad: { data: aad },
      authTag: { data: new Uint8Array(16) },
    }
    await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, gcmParams)
    const encrypted = await cipher.doFinal({ data: plaintext })

    return {
      ciphertext: encrypted.data.slice(0, encrypted.data.length - 16),
      nonce,
      tag: encrypted.data.slice(encrypted.data.length - 16),
    }
  } catch (e) {
    LogUtils.error(TAG, `aesGcmEncrypt failed: ${e}`)
    return null
  }
}

export async function aesGcmDecrypt(key: Uint8Array, nonce: Uint8Array, ciphertext: Uint8Array, tag: Uint8Array,
  aad: Uint8Array): Promise<Uint8Array | null> {
  try {
    const symGenerator = cryptoFramework.createSymKeyGenerator('AES256')
    const symKey = await symGenerator.convertKey({ data: key })

    const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding')
    const gcmParams: cryptoFramework.GcmParamsSpec = {
      algName: 'GcmParamsSpec',
      iv: { data: nonce },
      aad: { data: aad },
      authTag: { data: tag },
    }
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, gcmParams)
    const decrypted = await cipher.doFinal({ data: ciphertext })
    return decrypted.data
  } catch (e) {
    LogUtils.error(TAG, `aesGcmDecrypt failed: ${e}`)
    return null
  }
}

export async function generateRsaKeyPair(): Promise<RsaKeyPair | null> {
  try {
    const generator = cryptoFramework.createAsyKeyGenerator('RSA4096')
    const keyPair = await generator.generateKeyPair()
    const pubEncoded = await keyPair.pubKey.getEncoded()
    const priEncoded = await keyPair.priKey.getEncoded()
    return {
      pubKey: pubEncoded.data,
      privKey: priEncoded.data,
      keyPair,
    }
  } catch (e) {
    LogUtils.error(TAG, `generateRsaKeyPair failed: ${e}`)
    return null
  }
}

export async function rsaOaepDecrypt(privKey: cryptoFramework.PriKey, ciphertext: Uint8Array): Promise<Uint8Array | null> {
  try {
    const cipher = cryptoFramework.createCipher(RSA_OAEP_SHA256_CIPHER_SPEC)
    await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, privKey, null)
    const decrypted = await cipher.doFinal({ data: ciphertext })
    return decrypted.data
  } catch (e) {
    LogUtils.error(TAG, `rsaOaepDecrypt FAILED at step: ${e}`)
    return null
  }
}

export async function generateRandom(len: number): Promise<Uint8Array> {
  try {
    const random = cryptoFramework.createRandom()
    const result = await random.generateRandom(len)
    return result.data
  } catch (e) {
    LogUtils.error(TAG, `generateRandom failed: ${e}`)
    return new Uint8Array(0)
  }
}

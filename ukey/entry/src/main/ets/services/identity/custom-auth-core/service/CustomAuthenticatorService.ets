import { LogUtils } from '../../../../utils/LogUtils'
import {
  generateEcdhKeyPair,
  ecdhSharedSecret,
  hkdfDerive,
  aesGcmEncrypt,
  aesGcmDecrypt,
  generateRsaKeyPair,
  rsaOaepDecrypt,
  generateRandom,
  type EcdhKeyPair,
  type RsaKeyPair,
} from '../crypto/CustomAuthCryptoEngine'
import {
  storeKeys,
  loadKeys,
  deleteKeys,
  aliasExists,
  updateAuthSecretAndSeq,
  listAllTemplateIds,
  reconcile,
} from '../store/CustomAuthKeyStore'
import {
  encodePayload,
  decodePayload,
  encodePayloadField,
  decodePayloadField,
  decodeIntField,
  decodeStringField,
  requireField,
  rejectExtraFields,
} from '../codec/CustomAuthJsonPayloadCodec'
import { authenticatorUKeyProvider } from '../ukey/AuthenticatorUKeyProvider'
import type {
  BeginEnrollInput,
  EnrollCallbackResult,
  EndEnrollInput,
  EndEnrollOutput,
  BeginAuthenticateInput,
  InitOutput,
  InitAuthenticatorResult,
  EncryptedData,
  AuthCallbackResult,
} from '../ipc/CustomAuthTypes'
import { ResultCode, AsymmetricKeyExchangeAlgorithm, KeyDerivationAlgorithm, AsymmetricEncryptionAlgorithm,
  SymmetricEncryptionAlgorithm } from '../ipc/CustomAuthTypes'

const TAG = 'CustomAuth.Service'
const SESSION_KEY_LENGTH = 32
const AUTHENTICATOR_SECRET_LENGTH = 32
const FAILURE_TEMPLATE_ID = '0'
const PASSCODE_PROMPT_ENABLED = true
const AAD_END_ENROLL_INPUT = 'custom_auth.end_enroll_input'
const AAD_END_ENROLL_OUTPUT = 'custom_auth.end_enroll_output'
const AAD_ON_PROMPT = 'custom_auth.on_prompt'
const AAD_ON_AUTH_RESULT = 'custom_auth.on_auth_result'

interface EnrollSession {
  ecdhKeyPair: EcdhKeyPair | null
  challenge: number[]
  active: boolean
}

interface AuthSession {
  sessionKey: Uint8Array | null
  rsaKeyPair: RsaKeyPair | null
  userId: number
  cdaChallenge: number[]
  templateId: string
  sharedKey: Uint8Array
  authenticatorSecret: Uint8Array
  authenticatorSecretSeq: number
  active: boolean
}

interface BeginAuthResult {
  resultCode: number
  templateId: string
  encryptedData: EncryptedData
  completed?: boolean
}

const EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA: EncryptedData = { nonce: [], tag: [], ciphertext: [] }

function asciiToBytes(value: string): Uint8Array {
  const data = new Uint8Array(value.length)
  for (let i = 0; i < value.length; i++) {
    data[i] = value.charCodeAt(i) & 0xFF
  }
  return data
}

function arraysEqual(a: Uint8Array, b: number[]): boolean {
  if (a.length !== b.length) return false
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false
  }
  return true
}

function toEncryptedData(nonce: Uint8Array, tag: Uint8Array, ciphertext: Uint8Array): EncryptedData {
  return {
    nonce: Array.from(nonce),
    tag: Array.from(tag),
    ciphertext: Array.from(ciphertext),
  }
}

function cleanupEnrollSession(session: EnrollSession | undefined): void {
  if (!session || !session.ecdhKeyPair) {
    return
  }
  session.ecdhKeyPair.pubKey.fill(0)
  session.ecdhKeyPair.privKey.fill(0)
}

function cleanupAuthSession(session: AuthSession | undefined): void {
  if (!session) {
    return
  }
  if (session.sessionKey) session.sessionKey.fill(0)
  if (session.sharedKey) session.sharedKey.fill(0)
  if (session.authenticatorSecret) session.authenticatorSecret.fill(0)
}

export class CustomAuthenticatorService {
  private enrollSessions: Map<number, EnrollSession> = new Map()
  private authSessions: Map<number, AuthSession> = new Map()
  private sharedRsaKeyPair: RsaKeyPair | null = null
  private rsaReady: Promise<void> | null = null

  private async initRsaKey(): Promise<void> {
    this.sharedRsaKeyPair = await generateRsaKeyPair()
    if (this.sharedRsaKeyPair) {
      LogUtils.info(TAG, 'initRsaKey: ready')
    }
    this.rsaReady = null
  }

  private async ensureRsaKey(): Promise<void> {
    if (this.sharedRsaKeyPair) {
      return
    }
    if (this.rsaReady === null) {
      this.rsaReady = this.initRsaKey()
    }
    await this.rsaReady
  }

  initAuthenticator(templateIds: string[]): InitAuthenticatorResult {
    const held = reconcile(templateIds)
    const initOutput: InitOutput = {
      asymmetricKeyExchangeAlgorithms: [AsymmetricKeyExchangeAlgorithm.ECDH_P256],
      asymmetricEncryptionAlgorithms: [AsymmetricEncryptionAlgorithm.RSA_4096_OAEP_SHA256],
      symmetricEncryptionAlgorithms: [SymmetricEncryptionAlgorithm.AES_256_GCM],
      keyDerivationAlgorithms: [KeyDerivationAlgorithm.HKDF_SHA256],
      authenticatorTemplateIds: held,
    }
    LogUtils.info(TAG, `initAuthenticator: valid=${templateIds.length} held=${initOutput.authenticatorTemplateIds.length}`)
    const result: InitAuthenticatorResult = { resultCode: ResultCode.SUCCESS, initOutput: initOutput }
    return result
  }

  async beginEnroll(input: BeginEnrollInput): Promise<EnrollCallbackResult> {
    if (this.enrollSessions.has(input.requestId)) {
      LogUtils.warn(TAG, `beginEnroll: overwriting existing session for requestId=${input.requestId}`)
      cleanupEnrollSession(this.enrollSessions.get(input.requestId))
      this.enrollSessions.delete(input.requestId)
    }
    LogUtils.info(TAG, `beginEnroll: requestId=${input.requestId} (algorithmParam reserved)`)

    const keyPair = await generateEcdhKeyPair()
    if (!keyPair) {
      LogUtils.error(TAG, 'beginEnroll: ECDH keygen failed')
      return { resultCode: ResultCode.GENERAL_ERROR, challenge: [], publicKey: [] }
    }

    const challengeRaw = await generateRandom(8)
    if (!challengeRaw) {
      keyPair.pubKey.fill(0)
      keyPair.privKey.fill(0)
      LogUtils.error(TAG, 'beginEnroll: challenge generation failed')
      return { resultCode: ResultCode.GENERAL_ERROR, challenge: [], publicKey: [] }
    }
    const challenge = Array.from(challengeRaw)

    this.enrollSessions.set(input.requestId, { ecdhKeyPair: keyPair, challenge, active: true })

    LogUtils.info(TAG, `beginEnroll: success, requestId=${input.requestId}, challengeLen=${challenge.length}, publicKeyLen=${keyPair.pubKey.length}`)
    return {
      resultCode: ResultCode.SUCCESS,
      challenge,
      publicKey: Array.from(keyPair.pubKey),
    }
  }

  async endEnroll(input: EndEnrollInput): Promise<EndEnrollOutput> {
    const session = this.enrollSessions.get(input.requestId)
    if (!session || !session.active || !session.ecdhKeyPair) {
      LogUtils.error(TAG, `endEnroll: no active session for requestId=${input.requestId}`)
      return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    try {
      const cdaPub = new Uint8Array(input.publicKey)
      const sharedKey = await ecdhSharedSecret(session.ecdhKeyPair.keyPair, cdaPub)
      if (!sharedKey) {
        LogUtils.error(TAG, 'endEnroll: ECDH agreement failed')
        return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }

      const salt = new Uint8Array(input.salt)
      const sessionKey = await hkdfDerive(salt, new Uint8Array(0), sharedKey, SESSION_KEY_LENGTH)
      if (!sessionKey) {
        LogUtils.error(TAG, 'endEnroll: HKDF derive failed')
        return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }

      const decrypted = await aesGcmDecrypt(
        sessionKey,
        new Uint8Array(input.encryptedData.nonce),
        new Uint8Array(input.encryptedData.ciphertext),
        new Uint8Array(input.encryptedData.tag),
        asciiToBytes(AAD_END_ENROLL_INPUT),
      )
      if (!decrypted) {
        LogUtils.error(TAG, 'endEnroll: AEAD decrypt failed')
        return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }

      let payload: Record<string, Object | null>
      try {
        payload = decodePayload(decrypted)
        rejectExtraFields(payload, ['user_id', 'template_id', 'authenticator_challenge'])
        requireField(payload, 'user_id')
        requireField(payload, 'template_id')
        requireField(payload, 'authenticator_challenge')
      } catch (e) {
        LogUtils.error(TAG, `endEnroll: payload contract violation: ${e}`)
        return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }

      const payloadUserId = decodeIntField(payload['user_id'])
      if (payloadUserId === null || payloadUserId !== input.userId) {
        LogUtils.error(TAG, 'endEnroll: user_id missing or mismatch')
        return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }

      const payloadTemplateId = decodeStringField(payload['template_id'])
      if (payloadTemplateId === null || payloadTemplateId !== input.templateId) {
        LogUtils.error(TAG, 'endEnroll: template_id missing or mismatch')
        return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }

      const authChallengeRaw = decodePayloadField(payload['authenticator_challenge'])
      if (authChallengeRaw === null || !arraysEqual(authChallengeRaw, session.challenge)) {
        LogUtils.error(TAG, 'endEnroll: authenticator_challenge mismatch')
        return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }

      const authenticatorSecret = await generateRandom(AUTHENTICATOR_SECRET_LENGTH)
      if (!authenticatorSecret) {
        LogUtils.error(TAG, 'endEnroll: authenticatorSecret generation failed')
        return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }
      const cdaChallenge = new Uint8Array(input.challenge)

      const responsePayload = encodePayload({
        'user_id': input.userId,
        'cda_challenge': encodePayloadField(cdaChallenge),
        'authenticator_secret': encodePayloadField(authenticatorSecret),
      })

      const aeadResult = await aesGcmEncrypt(sessionKey, responsePayload, asciiToBytes(AAD_END_ENROLL_OUTPUT))
      if (!aeadResult) {
        LogUtils.error(TAG, 'endEnroll: AEAD encrypt response failed')
        return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }

      const stored = storeKeys(input.templateId, sharedKey, authenticatorSecret)
      if (!stored) {
        LogUtils.error(TAG, `endEnroll: storeKeys failed, templateId=${input.templateId}`)
        return { resultCode: ResultCode.GENERAL_ERROR, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }
      await authenticatorUKeyProvider.onEnrolled(input.templateId)

      LogUtils.info(TAG, `endEnroll: success, userId=${input.userId}, templateId=${input.templateId}`)
      sessionKey.fill(0)
      sharedKey.fill(0)
      authenticatorSecret.fill(0)
      return { resultCode: ResultCode.SUCCESS, encryptedData: toEncryptedData(aeadResult.nonce, aeadResult.tag, aeadResult.ciphertext) }
    } finally {
      cleanupEnrollSession(session)
      this.enrollSessions.delete(input.requestId)
    }
  }

  async beginAuthenticate(input: BeginAuthenticateInput): Promise<BeginAuthResult> {
    if (this.authSessions.has(input.requestId)) {
      LogUtils.warn(TAG, `beginAuthenticate: cleaning up existing session for requestId=${input.requestId}`)
      cleanupAuthSession(this.authSessions.get(input.requestId))
      this.authSessions.delete(input.requestId)
    }

    const all = listAllTemplateIds()
    if (all.length === 0) {
      LogUtils.error(TAG, `beginAuthenticate: no templates for userId=${input.userId}`)
      return { resultCode: ResultCode.NOT_ENROLLED, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    let chosen = await authenticatorUKeyProvider.getPresentTemplateId(all)
    if (chosen === null) {
      LogUtils.warn(TAG, 'beginAuthenticate: no bound UKey template matched')
      return { resultCode: ResultCode.FAIL, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }
    if (await authenticatorUKeyProvider.isLocked()) {
      LogUtils.warn(TAG, 'beginAuthenticate: UKey is locked')
      return { resultCode: ResultCode.LOCKED, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    const material = loadKeys(chosen)
    if (!material) {
      LogUtils.error(TAG, `beginAuthenticate: loadKeys failed for templateId=${chosen}`)
      return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    LogUtils.info(TAG, `beginAuthenticate: requestId=${input.requestId}, chosen=${chosen} (algorithmParam reserved)`)

    const salt = new Uint8Array(input.salt)
    const sessionKey = await hkdfDerive(salt, new Uint8Array(0), material.sharedKey, SESSION_KEY_LENGTH)
    if (!sessionKey) {
      material.sharedKey.fill(0)
      material.authenticatorSecret.fill(0)
      return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    const promptPasscode = PASSCODE_PROMPT_ENABLED
    if (!promptPasscode) {
      LogUtils.error(TAG, 'beginAuthenticate: passcode prompt disabled')
      sessionKey.fill(0)
      material.sharedKey.fill(0)
      material.authenticatorSecret.fill(0)
      return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    await this.ensureRsaKey()
    let rsaKeyPair = this.sharedRsaKeyPair
    if (rsaKeyPair) {
      LogUtils.info(TAG, 'beginAuthenticate: using shared RSA key pair')
    } else {
      rsaKeyPair = await generateRsaKeyPair()
      if (rsaKeyPair) {
        this.sharedRsaKeyPair = rsaKeyPair
      }
    }
    if (!rsaKeyPair) {
      LogUtils.error(TAG, 'beginAuthenticate: RSA keygen failed')
      sessionKey.fill(0)
      material.sharedKey.fill(0)
      material.authenticatorSecret.fill(0)
      return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    const cdaChallenge = new Uint8Array(input.challenge)
    const payload = encodePayload({
      'cda_challenge': encodePayloadField(cdaChallenge),
      'public_key': encodePayloadField(rsaKeyPair.pubKey),
    })

    const aeadResult = await aesGcmEncrypt(sessionKey, payload, asciiToBytes(AAD_ON_PROMPT))
    if (!aeadResult) {
      sessionKey.fill(0)
      material.sharedKey.fill(0)
      material.authenticatorSecret.fill(0)
      return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    this.authSessions.set(input.requestId, {
      sessionKey,
      rsaKeyPair,
      userId: input.userId,
      cdaChallenge: input.challenge,
      templateId: chosen,
      sharedKey: material.sharedKey,
      authenticatorSecret: material.authenticatorSecret,
      authenticatorSecretSeq: material.authenticatorSecretSeq,
      active: true,
    })

    LogUtils.info(TAG, `beginAuthenticate: success, userId=${input.userId}, templateId=${chosen}`)
    return {
      resultCode: ResultCode.SUCCESS,
      templateId: chosen,
      encryptedData: toEncryptedData(aeadResult.nonce, aeadResult.tag, aeadResult.ciphertext),
      completed: false,
    }
  }

  async submitPasscode(requestId: number, passcodeCipherText: number[]): Promise<AuthCallbackResult> {
    const session = this.authSessions.get(requestId)
    if (!session || !session.active || !session.rsaKeyPair) {
      LogUtils.error(TAG, `submitPasscode: no active session for requestId=${requestId}`)
      return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    try {
      if (!session.sessionKey) {
        LogUtils.error(TAG, 'submitPasscode: sessionKey is null')
        return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }

      if (!await authenticatorUKeyProvider.isTemplatePresent(session.templateId)) {
        LogUtils.warn(TAG, `submitPasscode: target UKey absent before passcode, templateId=${session.templateId}`)
        return { resultCode: ResultCode.FAIL, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }
      if (await authenticatorUKeyProvider.isLocked()) {
        LogUtils.warn(TAG, 'submitPasscode: UKey is locked')
        return { resultCode: ResultCode.LOCKED, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }
      if (passcodeCipherText.length === 0) {
        LogUtils.warn(TAG, 'submitPasscode: empty passcode is rejected')
        return { resultCode: ResultCode.FAIL, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }

      const ciphertext = new Uint8Array(passcodeCipherText)
      const passcode = await rsaOaepDecrypt(session.rsaKeyPair.keyPair.priKey, ciphertext)
      if (!passcode) {
        LogUtils.error(TAG, 'submitPasscode: RSA decrypt failed')
        return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }
      let passcodeStr = ''
      for (let i = 0; i < passcode.length; i++) {
        passcodeStr += String.fromCharCode(passcode[i])
      }
      const passcodeResult = await authenticatorUKeyProvider.verifyPasscode(passcodeStr)
      passcode.fill(0)
      if (!passcodeResult.success) {
        LogUtils.warn(TAG, `submitPasscode: passcode rejected, reason=${passcodeResult.reason}, attempts=${passcodeResult.failedAttempts}`)
        return {
          resultCode: passcodeResult.locked ? ResultCode.LOCKED : ResultCode.FAIL,
          templateId: FAILURE_TEMPLATE_ID,
          encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA
        }
      }
      if (!await authenticatorUKeyProvider.isTemplatePresent(session.templateId)) {
        LogUtils.warn(TAG, `submitPasscode: target UKey absent after passcode, templateId=${session.templateId}`)
        return { resultCode: ResultCode.FAIL, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }
      return await this.finishAuth(session)
    } finally {
      cleanupAuthSession(session)
      this.authSessions.delete(requestId)
    }
  }

  private async finishAuth(session: AuthSession): Promise<AuthCallbackResult> {
    const sessionKey = session.sessionKey
    if (!sessionKey) {
      LogUtils.error(TAG, 'finishAuth: sessionKey is null')
      return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    const rotate = await authenticatorUKeyProvider.shouldRotate(session.templateId)
    let finalSecret: Uint8Array = session.authenticatorSecret
    let finalSeq: number = session.authenticatorSecretSeq
    let newSecret: Uint8Array | null = null
    if (rotate) {
      newSecret = await generateRandom(AUTHENTICATOR_SECRET_LENGTH)
      if (!newSecret) {
        LogUtils.error(TAG, `finishAuth: rotation secret generation failed, templateId=${session.templateId}`)
        return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }
      const committedSeq = updateAuthSecretAndSeq(session.templateId, newSecret)
      if (committedSeq === null) {
        LogUtils.error(TAG, `finishAuth: rotation store failed, templateId=${session.templateId}`)
        newSecret.fill(0)
        return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
      }
      await authenticatorUKeyProvider.onRotated(session.templateId)
      finalSecret = newSecret
      finalSeq = committedSeq
      LogUtils.info(TAG, `finishAuth: rotated, templateId=${session.templateId}, seq=${committedSeq}`)
    }

    const cdaChallenge = new Uint8Array(session.cdaChallenge)
    const resultPayload = encodePayload({
      'cda_challenge': encodePayloadField(cdaChallenge),
      'authenticator_secret': encodePayloadField(finalSecret),
      'auth_secret_seq': finalSeq,
    })
    if (newSecret) {
      newSecret.fill(0)
    }

    const aeadResult = await aesGcmEncrypt(sessionKey, resultPayload, asciiToBytes(AAD_ON_AUTH_RESULT))
    if (!aeadResult) {
      return { resultCode: ResultCode.GENERAL_ERROR, templateId: FAILURE_TEMPLATE_ID, encryptedData: EMPTY_CUSTOM_AUTH_ENCRYPTED_DATA }
    }

    LogUtils.info(TAG, `finishAuth: success, templateId=${session.templateId}, rotated=${rotate}, seq=${finalSeq}`)
    return {
      resultCode: ResultCode.SUCCESS,
      templateId: session.templateId,
      encryptedData: toEncryptedData(aeadResult.nonce, aeadResult.tag, aeadResult.ciphertext),
    }
  }

  async remove(templateId: string): Promise<number> {
    if (!aliasExists(templateId)) {
      LogUtils.info(TAG, `remove: templateId=${templateId} not enrolled`)
      return ResultCode.NOT_ENROLLED
    }
    const ok = deleteKeys(templateId)
    LogUtils.info(TAG, `remove: templateId=${templateId}, result=${ok}`)
    return ok ? ResultCode.SUCCESS : ResultCode.GENERAL_ERROR
  }

  async cancel(requestId: number): Promise<number> {
    const authSession = this.authSessions.get(requestId)
    cleanupAuthSession(authSession)
    cleanupEnrollSession(this.enrollSessions.get(requestId))
    this.enrollSessions.delete(requestId)
    this.authSessions.delete(requestId)
    LogUtils.info(TAG, `cancel: requestId=${requestId}`)
    return ResultCode.SUCCESS
  }

  cleanupAllSessions(): void {
    let authCount = 0
    for (const session of this.authSessions.values()) {
      cleanupAuthSession(session)
      authCount++
    }
    let enrollCount = 0
    for (const session of this.enrollSessions.values()) {
      cleanupEnrollSession(session)
      enrollCount++
    }
    this.authSessions.clear()
    this.enrollSessions.clear()
    if (authCount > 0 || enrollCount > 0) {
      LogUtils.info(TAG, `cleanupAllSessions: cleared auth=${authCount} enroll=${enrollCount}`)
    }
  }
}

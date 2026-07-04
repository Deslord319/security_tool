import { common } from '@kit.AbilityKit'
import {
  LockScreenUKeyDevice,
  PREF_KEY_LOCKSCREEN_UKEY_PASSWORD_STATES,
  PREF_STORE_NAME_LOCKSCREEN_AUTH
} from '../../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { PreferencesAccessor } from '../../../../storage/preferences/PreferencesAccessor'
import { LogUtils } from '../../../../utils/LogUtils'
import {
  LockScreenAuthRepository,
  PreferencesLockScreenAuthRepository
} from '../../lockscreen-auth/LockScreenAuthRepository'
import {
  DdkLockScreenUKeyDeviceService,
  LockScreenUKeyDeviceProvider
} from '../../lockscreen-auth/LockScreenUKeyDeviceService'
import {
  LockScreenUKeyBindingRepository,
  PreferencesLockScreenUKeyActiveCredentialRepository,
  PreferencesLockScreenUKeyBindingRepository,
  type LockScreenUKeyActiveCredentialRepository
} from '../../lockscreen-auth/LockScreenUKeyBindingRepository'
import { decodeUint64Be } from '../codec/CustomAuthUint64Codec'

const TAG = 'CustomAuth.UKeyProvider'
const FIXED_UKEY_PASSWORD = '666666'
const MAX_UKEY_PASSWORD_FAILURES = 5

export interface AuthenticatorUKeyProvider {
  getPresentTemplateId(candidates: string[]): Promise<string | null>
  verifyPasscode(passcode: string): Promise<AuthenticatorUKeyPasscodeVerification>
  isTemplatePresent(templateId: string): Promise<boolean>
  isLocked(): Promise<boolean>
  shouldRotate(templateId: string): Promise<boolean>
}

export type AuthenticatorUKeyPasswordFailureReason =
  'none' |
  'context_missing' |
  'ukey_absent' |
  'locked' |
  'mismatch'

export interface AuthenticatorUKeyPasscodeVerification {
  success: boolean
  locked: boolean
  failedAttempts: number
  remainingAttempts: number
  fingerprint: string
  reason: AuthenticatorUKeyPasswordFailureReason
}

export interface AuthenticatorUKeyPasswordState {
  failedAttempts: number
  locked: boolean
  updatedAt: number
}

export type AuthenticatorUKeyPasswordStateMap = Record<string, AuthenticatorUKeyPasswordState>

export interface AuthenticatorUKeyPasswordStateRepository {
  loadPasswordStates(context: common.Context): Promise<AuthenticatorUKeyPasswordStateMap>
  savePasswordStates(context: common.Context, states: AuthenticatorUKeyPasswordStateMap): Promise<boolean>
}

function normalizePasswordState(state: AuthenticatorUKeyPasswordState | undefined | null): AuthenticatorUKeyPasswordState {
  if (!state) {
    return {
      failedAttempts: 0,
      locked: false,
      updatedAt: 0
    }
  }
  let failedAttempts = Number.isFinite(state.failedAttempts) ? Math.floor(state.failedAttempts) : 0
  failedAttempts = Math.min(MAX_UKEY_PASSWORD_FAILURES, Math.max(0, failedAttempts))
  return {
    failedAttempts: failedAttempts,
    locked: state.locked === true || failedAttempts >= MAX_UKEY_PASSWORD_FAILURES,
    updatedAt: Number.isFinite(state.updatedAt) && state.updatedAt > 0 ? state.updatedAt : 0
  }
}

export class PreferencesAuthenticatorUKeyPasswordStateRepository
implements AuthenticatorUKeyPasswordStateRepository {
  async loadPasswordStates(context: common.Context): Promise<AuthenticatorUKeyPasswordStateMap> {
    let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
    let raw = await pref.getJsonObject<AuthenticatorUKeyPasswordStateMap>(PREF_KEY_LOCKSCREEN_UKEY_PASSWORD_STATES, {})
    let result: AuthenticatorUKeyPasswordStateMap = {}
    for (let key of Object.keys(raw)) {
      let value = raw[key]
      if (key.length === 0 || !value) {
        continue
      }
      result[key] = normalizePasswordState(value)
    }
    return result
  }

  async savePasswordStates(context: common.Context, states: AuthenticatorUKeyPasswordStateMap): Promise<boolean> {
    let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
    return await pref.setJson(PREF_KEY_LOCKSCREEN_UKEY_PASSWORD_STATES, states)
  }
}

export class SecurityToolAuthenticatorUKeyProvider implements AuthenticatorUKeyProvider {
  private context: common.Context | null = null
  private readonly deviceProvider: LockScreenUKeyDeviceProvider
  private readonly bindingRepository: LockScreenUKeyBindingRepository
  private readonly activeCredentialRepository: LockScreenUKeyActiveCredentialRepository
  private readonly passwordStateRepository: AuthenticatorUKeyPasswordStateRepository
  private readonly authRepository: LockScreenAuthRepository

  constructor(
    deviceProvider: LockScreenUKeyDeviceProvider = new DdkLockScreenUKeyDeviceService(),
    bindingRepository: LockScreenUKeyBindingRepository = new PreferencesLockScreenUKeyBindingRepository(),
    activeCredentialRepository: LockScreenUKeyActiveCredentialRepository =
      new PreferencesLockScreenUKeyActiveCredentialRepository(),
    passwordStateRepository: AuthenticatorUKeyPasswordStateRepository =
      new PreferencesAuthenticatorUKeyPasswordStateRepository(),
    authRepository: LockScreenAuthRepository = new PreferencesLockScreenAuthRepository()
  ) {
    this.deviceProvider = deviceProvider
    this.bindingRepository = bindingRepository
    this.activeCredentialRepository = activeCredentialRepository
    this.passwordStateRepository = passwordStateRepository
    this.authRepository = authRepository
  }

  bindContext(context: common.Context): void {
    this.context = context
  }

  async getPresentTemplateId(candidates: string[]): Promise<string | null> {
    if (candidates.length === 0) {
      return null
    }
    if (!await this.isUnlockEnabled()) {
      LogUtils.warn(TAG, '[AUTH_MATCH_FAIL] reason=disabled')
      return null
    }
    let presentFingerprint = await this.resolvePresentBoundFingerprint()
    if (presentFingerprint.length === 0) {
      LogUtils.warn(TAG, '[AUTH_MATCH_FAIL] reason=bound_ukey_absent')
      return null
    }
    let credentialKeys = await this.loadPresentFingerprintCredentialKeys(presentFingerprint)
    for (let candidate of candidates) {
      if (SecurityToolAuthenticatorUKeyProvider.matchesCredentialKey(candidate, credentialKeys)) {
        return candidate
      }
    }
    LogUtils.warn(TAG, `[AUTH_MATCH_FAIL] reason=no_credential_binding, candidates=${candidates.length}, credentials=${credentialKeys.size}`)
    return null
  }

  async verifyPasscode(passcode: string): Promise<AuthenticatorUKeyPasscodeVerification> {
    let context = this.context
    if (!context) {
      return SecurityToolAuthenticatorUKeyProvider.buildPasscodeResult(false, false, 0, '', 'context_missing')
    }
    let binding = await this.bindingRepository.loadBinding(context)
    if (!binding || binding.fingerprint.length === 0) {
      return SecurityToolAuthenticatorUKeyProvider.buildPasscodeResult(false, false, 0, '', 'ukey_absent')
    }
    return await this.verifyPasscodeForFingerprint(context, binding.fingerprint, passcode)
  }

  async verifyPasscodeForFingerprint(
    context: common.Context,
    fingerprint: string,
    passcode: string
  ): Promise<AuthenticatorUKeyPasscodeVerification> {
    if (fingerprint.length === 0) {
      return SecurityToolAuthenticatorUKeyProvider.buildPasscodeResult(false, false, 0, '', 'ukey_absent')
    }
    if (!this.isFingerprintPresent(fingerprint)) {
      return SecurityToolAuthenticatorUKeyProvider.buildPasscodeResult(false, false, 0, fingerprint, 'ukey_absent')
    }
    let states = await this.passwordStateRepository.loadPasswordStates(context)
    let current = normalizePasswordState(states[fingerprint])
    if (current.locked) {
      return SecurityToolAuthenticatorUKeyProvider.buildPasscodeResult(
        false,
        true,
        current.failedAttempts,
        fingerprint,
        'locked'
      )
    }
    if (passcode === FIXED_UKEY_PASSWORD) {
      states[fingerprint] = {
        failedAttempts: 0,
        locked: false,
        updatedAt: Date.now()
      }
      await this.passwordStateRepository.savePasswordStates(context, states)
      return SecurityToolAuthenticatorUKeyProvider.buildPasscodeResult(true, false, 0, fingerprint, 'none')
    }

    let failedAttempts = Math.min(MAX_UKEY_PASSWORD_FAILURES, current.failedAttempts + 1)
    let locked = failedAttempts >= MAX_UKEY_PASSWORD_FAILURES
    states[fingerprint] = {
      failedAttempts: failedAttempts,
      locked: locked,
      updatedAt: Date.now()
    }
    await this.passwordStateRepository.savePasswordStates(context, states)
    return SecurityToolAuthenticatorUKeyProvider.buildPasscodeResult(
      false,
      locked,
      failedAttempts,
      fingerprint,
      locked ? 'locked' : 'mismatch'
    )
  }

  async isTemplatePresent(templateId: string): Promise<boolean> {
    if (templateId.length === 0 || !await this.isUnlockEnabled()) {
      return false
    }
    let presentFingerprint = await this.resolvePresentBoundFingerprint()
    if (presentFingerprint.length === 0) {
      return false
    }
    let credentialKeys = await this.loadPresentFingerprintCredentialKeys(presentFingerprint)
    return SecurityToolAuthenticatorUKeyProvider.matchesCredentialKey(templateId, credentialKeys)
  }

  async isLocked(): Promise<boolean> {
    let context = this.context
    if (!context) {
      return false
    }
    let fingerprint = await this.resolvePresentBoundFingerprint()
    if (fingerprint.length === 0) {
      return false
    }
    return await this.isFingerprintLocked(context, fingerprint)
  }

  async isFingerprintLocked(context: common.Context, fingerprint: string): Promise<boolean> {
    if (fingerprint.length === 0) {
      return false
    }
    let states = await this.passwordStateRepository.loadPasswordStates(context)
    return normalizePasswordState(states[fingerprint]).locked
  }

  async shouldRotate(_templateId: string): Promise<boolean> {
    return false
  }

  private async resolvePresentBoundFingerprint(): Promise<string> {
    let context = this.context
    if (!context) {
      LogUtils.warn(TAG, '[AUTH_MATCH_FAIL] reason=context_unbound')
      return ''
    }
    let binding = await this.bindingRepository.loadBinding(context)
    if (!binding || binding.fingerprint.length === 0) {
      LogUtils.warn(TAG, '[AUTH_MATCH_FAIL] reason=no_mdm_binding')
      return ''
    }
    let fingerprint = binding.fingerprint
    return this.isFingerprintPresent(fingerprint) ? fingerprint : ''
  }

  private isFingerprintPresent(fingerprint: string): boolean {
    if (fingerprint.length === 0) {
      return false
    }
    let devices = this.queryCandidateDevices()
    return devices.some((item: LockScreenUKeyDevice): boolean => item.fingerprint === fingerprint)
  }

  private async isUnlockEnabled(): Promise<boolean> {
    let context = this.context
    if (!context) {
      return false
    }
    let config = await this.authRepository.loadConfig(context)
    return config.ukeyUnlockEnabled
  }

  private queryCandidateDevices(): LockScreenUKeyDevice[] {
    let result = this.deviceProvider.getCandidateDevices()
    if (!result.success) {
      LogUtils.warn(TAG, `[QUERY_FAIL] stage=${result.stage ?? 'query_ukey'}, message=${result.errorMessage ?? 'unknown'}`)
      return []
    }
    return result.data ?? []
  }

  private async loadPresentFingerprintCredentialKeys(fingerprint: string): Promise<Set<string>> {
    let keys = new Set<string>()
    let context = this.context
    if (!context || fingerprint.length === 0) {
      return keys
    }
    let active = await this.activeCredentialRepository.loadActiveCredential(context)
    if (!active || active.fingerprint !== fingerprint || active.userCredentials.length === 0) {
      return keys
    }
    for (let credential of active.userCredentials) {
      let normalized = SecurityToolAuthenticatorUKeyProvider.normalizeCredentialIdHex(credential.credentialIdHex)
      if (normalized.length === 0) {
        continue
      }
      keys.add(normalized)
      let decimal = SecurityToolAuthenticatorUKeyProvider.credentialIdHexToUint64Decimal(normalized)
      if (decimal.length > 0) {
        keys.add(decimal)
      }
    }
    return keys
  }

  private static normalizeCredentialIdHex(value: string): string {
    let normalized = value.replace(/[^0-9a-fA-F]/g, '').toLowerCase()
    return normalized.length > 0 && normalized.length % 2 === 0 ? normalized : ''
  }

  private static credentialIdHexToUint64Decimal(value: string): string {
    if (value.length !== 16) {
      return ''
    }
    try {
      let bytes = new Uint8Array(8)
      for (let i = 0; i < bytes.length; i++) {
        bytes[i] = parseInt(value.substring(i * 2, i * 2 + 2), 16)
      }
      return decodeUint64Be(bytes)
    } catch (err) {
      LogUtils.warn(TAG, `[CREDENTIAL_ID_DECODE_FAIL] err=${JSON.stringify(err)}`)
      return ''
    }
  }

  private static matchesCredentialKey(candidate: string, credentialKeys: Set<string>): boolean {
    if (credentialKeys.has(candidate)) {
      return true
    }
    let normalized = SecurityToolAuthenticatorUKeyProvider.normalizeCredentialIdHex(candidate)
    return normalized.length > 0 && credentialKeys.has(normalized)
  }

  private static buildPasscodeResult(
    success: boolean,
    locked: boolean,
    failedAttempts: number,
    fingerprint: string,
    reason: AuthenticatorUKeyPasswordFailureReason
  ): AuthenticatorUKeyPasscodeVerification {
    let normalizedAttempts = Math.min(MAX_UKEY_PASSWORD_FAILURES, Math.max(0, failedAttempts))
    return {
      success: success,
      locked: locked,
      failedAttempts: normalizedAttempts,
      remainingAttempts: Math.max(0, MAX_UKEY_PASSWORD_FAILURES - normalizedAttempts),
      fingerprint: fingerprint,
      reason: reason
    }
  }
}

export const authenticatorUKeyProvider: SecurityToolAuthenticatorUKeyProvider = new SecurityToolAuthenticatorUKeyProvider()

import { common } from '@kit.AbilityKit'
import {
  LockScreenUKeyDevice,
  PREF_KEY_LOCKSCREEN_UKEY_TEMPLATE_BINDINGS,
  PREF_STORE_NAME_LOCKSCREEN_AUTH
} from '../../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { PreferencesAccessor } from '../../../../storage/preferences/PreferencesAccessor'
import { LogUtils } from '../../../../utils/LogUtils'
import {
  DdkLockScreenUKeyDeviceService,
  LockScreenUKeyDeviceProvider
} from '../../lockscreen-auth/LockScreenUKeyDeviceService'
import {
  LockScreenUKeyBindingRepository,
  PreferencesLockScreenUKeyBindingRepository
} from '../../lockscreen-auth/LockScreenUKeyBindingRepository'

const TAG = 'CustomAuth.UKeyProvider'

export interface AuthenticatorUKeyProvider {
  onEnrolled(templateId: string): Promise<void>
  getPresentTemplateId(candidates: string[]): Promise<string | null>
  verifyPasscode(passcode: string): Promise<boolean>
  shouldRotate(templateId: string): Promise<boolean>
  onRotated(templateId: string): Promise<void>
}

export type AuthenticatorUKeyTemplateBindingMap = Record<string, string>

export interface AuthenticatorUKeyTemplateBindingRepository {
  loadTemplateBindings(context: common.Context): Promise<AuthenticatorUKeyTemplateBindingMap>
  saveTemplateBindings(context: common.Context, bindings: AuthenticatorUKeyTemplateBindingMap): Promise<boolean>
}

export class PreferencesAuthenticatorUKeyTemplateBindingRepository
implements AuthenticatorUKeyTemplateBindingRepository {
  async loadTemplateBindings(context: common.Context): Promise<AuthenticatorUKeyTemplateBindingMap> {
    let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
    let raw = await pref.getJsonObject<AuthenticatorUKeyTemplateBindingMap>(PREF_KEY_LOCKSCREEN_UKEY_TEMPLATE_BINDINGS, {})
    let result: AuthenticatorUKeyTemplateBindingMap = {}
    for (let key of Object.keys(raw)) {
      let value = raw[key]
      if (typeof value === 'string' && key.length > 0 && value.length > 0) {
        result[key] = value
      }
    }
    return result
  }

  async saveTemplateBindings(context: common.Context, bindings: AuthenticatorUKeyTemplateBindingMap): Promise<boolean> {
    let pref = PreferencesAccessor.of(context, PREF_STORE_NAME_LOCKSCREEN_AUTH)
    return await pref.setJson(PREF_KEY_LOCKSCREEN_UKEY_TEMPLATE_BINDINGS, bindings)
  }
}

export class SecurityToolAuthenticatorUKeyProvider implements AuthenticatorUKeyProvider {
  private context: common.Context | null = null
  private readonly deviceProvider: LockScreenUKeyDeviceProvider
  private readonly bindingRepository: LockScreenUKeyBindingRepository
  private readonly templateBindingRepository: AuthenticatorUKeyTemplateBindingRepository

  constructor(
    deviceProvider: LockScreenUKeyDeviceProvider = new DdkLockScreenUKeyDeviceService(),
    bindingRepository: LockScreenUKeyBindingRepository = new PreferencesLockScreenUKeyBindingRepository(),
    templateBindingRepository: AuthenticatorUKeyTemplateBindingRepository =
      new PreferencesAuthenticatorUKeyTemplateBindingRepository()
  ) {
    this.deviceProvider = deviceProvider
    this.bindingRepository = bindingRepository
    this.templateBindingRepository = templateBindingRepository
  }

  bindContext(context: common.Context): void {
    this.context = context
  }

  async onEnrolled(templateId: string): Promise<void> {
    if (templateId.length === 0) {
      return
    }
    let fingerprint = await this.resolveEnrollmentFingerprint()
    if (fingerprint.length === 0) {
      LogUtils.warn(TAG, `[ENROLL_BIND_SKIP] templateId=${templateId}, reason=no_present_ukey`)
      return
    }
    let bindings = await this.loadTemplateBindings()
    bindings[templateId] = fingerprint
    let saved = await this.saveTemplateBindings(bindings)
    if (!saved) {
      LogUtils.error(TAG, `[ENROLL_BIND_FAIL] templateId=${templateId}`)
      return
    }
    LogUtils.info(TAG, `[ENROLL_BIND_SUCCESS] templateId=${templateId}`)
  }

  async getPresentTemplateId(candidates: string[]): Promise<string | null> {
    if (candidates.length === 0) {
      return null
    }
    let presentFingerprint = await this.resolvePresentBoundFingerprint()
    if (presentFingerprint.length === 0) {
      LogUtils.warn(TAG, '[AUTH_MATCH_FAIL] reason=bound_ukey_absent')
      return null
    }
    let bindings = await this.loadTemplateBindings()
    for (let templateId of candidates) {
      if (bindings[templateId] === presentFingerprint) {
        return templateId
      }
    }
    LogUtils.warn(TAG, `[AUTH_MATCH_FAIL] reason=no_template_binding, candidates=${candidates.length}`)
    return null
  }

  async verifyPasscode(passcode: string): Promise<boolean> {
    return passcode.length === 0
  }

  async shouldRotate(_templateId: string): Promise<boolean> {
    return false
  }

  async onRotated(templateId: string): Promise<void> {
    await this.onEnrolled(templateId)
  }

  private async resolveEnrollmentFingerprint(): Promise<string> {
    let context = this.context
    let binding = context ? await this.bindingRepository.loadBinding(context) : null
    if (binding && binding.fingerprint.length > 0) {
      return binding.fingerprint
    }
    let devices = this.queryCandidateDevices()
    return devices.length === 1 ? devices[0].fingerprint : ''
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
    let devices = this.queryCandidateDevices()
    let matched = devices.some((item: LockScreenUKeyDevice): boolean => item.fingerprint === fingerprint)
    return matched ? fingerprint : ''
  }

  private queryCandidateDevices(): LockScreenUKeyDevice[] {
    let result = this.deviceProvider.getCandidateDevices()
    if (!result.success) {
      LogUtils.warn(TAG, `[QUERY_FAIL] stage=${result.stage ?? 'query_ukey'}, message=${result.errorMessage ?? 'unknown'}`)
      return []
    }
    return result.data ?? []
  }

  private async loadTemplateBindings(): Promise<AuthenticatorUKeyTemplateBindingMap> {
    let context = this.context
    if (!context) {
      return {}
    }
    return await this.templateBindingRepository.loadTemplateBindings(context)
  }

  private async saveTemplateBindings(bindings: AuthenticatorUKeyTemplateBindingMap): Promise<boolean> {
    let context = this.context
    if (!context) {
      return false
    }
    return await this.templateBindingRepository.saveTemplateBindings(context, bindings)
  }
}

export const authenticatorUKeyProvider: SecurityToolAuthenticatorUKeyProvider = new SecurityToolAuthenticatorUKeyProvider()

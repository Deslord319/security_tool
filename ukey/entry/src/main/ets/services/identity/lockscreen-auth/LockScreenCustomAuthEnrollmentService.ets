import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import osAccount from '@ohos.account.osAccount'
import { OperationResult } from '../../../models/CommonModels'
import {
  LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO,
  LockScreenUKeyActiveCredential,
  LockScreenUKeyBinding,
  LockScreenUKeyDevice,
  LockScreenUKeyUserCredential
} from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { LogUtils } from '../../../utils/LogUtils'
import { decodeUint64Be } from '../custom-auth-core/codec/CustomAuthUint64Codec'
import { generateRandom } from '../custom-auth-core/crypto/CustomAuthCryptoEngine'
import {
  AuthenticatorUKeyTemplateBindingMap,
  AuthenticatorUKeyTemplateBindingRepository,
  authenticatorUKeyProvider,
  PreferencesAuthenticatorUKeyTemplateBindingRepository
} from '../custom-auth-core/ukey/AuthenticatorUKeyProvider'
import {
  LockScreenUKeyActiveCredentialRepository,
  LockScreenUKeyBindingRepository,
  PreferencesLockScreenUKeyActiveCredentialRepository,
  PreferencesLockScreenUKeyBindingRepository
} from './LockScreenUKeyBindingRepository'
import {
  DdkLockScreenUKeyDeviceService,
  LockScreenUKeyDeviceProvider,
} from './LockScreenUKeyDeviceService'

const TAG = 'LockScreenCustomAuth.Enroll'
const LOCKSCREEN_CUSTOM_AUTH_TYPE = 128
const LOCKSCREEN_CUSTOM_AUTH_SUB_TYPE = 0
const CUSTOM_AUTH_VERIFY_CHALLENGE_LENGTH = 16
const CUSTOM_AUTH_VERIFY_TIMEOUT_MS = 15000
export const LOCKSCREEN_CUSTOM_AUTH_TRUST_LEVEL_LABEL = 'ATL3'

export type LockScreenUKeyEnrollmentStage =
  'already_bound' |
  'bound_device_present' |
  'bound_other_device_present' |
  'no_ukey' |
  'multiple_ukeys' |
  'register_credential' |
  'delete_credential' |
  'cleanup_credential' |
  'credential_deleted' |
  'active_credential_present' |
  'active_credential_missing' |
  'save_binding' |
  'save_active_credential' |
  'clear_active_credential' |
  'startup_reconcile' |
  'query_user_ids' |
  'partial_registered' |
  'system_pin_required' |
  'ukey_password_required' |
  'ukey_password_mismatch' |
  'ukey_locked' |
  'manual_input_required' |
  'completed'

export interface CustomAuthCredentialRegistrationResult {
  success: boolean
  resultCode?: number
  credentialIdHex?: string
  errorCode?: number
  errorMessage?: string
}

export interface CustomAuthCredentialRegistrar {
  addCredential(userId: number, pluginInfo: string, systemPin: string): Promise<CustomAuthCredentialRegistrationResult>
}

export interface CustomAuthCredentialDeletionResult {
  success: boolean
  resultCode?: number
  credentialIdHex?: string
  errorCode?: number
  errorMessage?: string
}

export interface CustomAuthSystemCredentialInfo {
  userId: number
  credentialIdHex: string
  templateId: string
}

export interface CustomAuthCredentialListResult {
  success: boolean
  userId: number
  credentials: CustomAuthSystemCredentialInfo[]
  errorCode?: number
  errorMessage?: string
}

export interface CustomAuthCredentialManager extends CustomAuthCredentialRegistrar {
  deleteCredential(userId: number, credentialIdHex: string, systemPin: string): Promise<CustomAuthCredentialDeletionResult>
  listCustomAuthCredentialIds(userId: number): Promise<CustomAuthCredentialListResult>
}

export interface CustomAuthCredentialVerificationResult {
  success: boolean
  userId: number
  credentialIdHex: string
  challengeHex: string
  resultCode?: number
  tokenLength?: number
  errorCode?: number
  errorMessage?: string
}

export interface CustomAuthCredentialVerificationSummary {
  total: number
  successCount: number
  failureCount: number
  results: CustomAuthCredentialVerificationResult[]
}

export interface CustomAuthCredentialVerifier {
  verifyCredential(
    userId: number,
    credentialIdHex: string,
    challenge: Uint8Array
  ): Promise<CustomAuthCredentialVerificationResult>
}

export interface UKeyUserProvider {
  loadAvailableUserIds(): Promise<OperationResult<number[]>>
}

export interface LockScreenUKeyEnrollmentService {
  ensureFirstUKeyRegistered(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>>
  onUKeyAttached(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>>
  onUKeyDetached(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>>
  reconcileOnStartup(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>>
}

interface PinAuthTokenResult {
  success: boolean
  token?: Uint8Array
  resultCode?: number
  errorCode?: number
  errorMessage?: string
}

interface IdmOperationResult {
  resultCode: number
  credentialId?: Uint8Array
}

interface UserCredentialDispatchFailure {
  userId: number
  resultCode?: number
  errorCode?: number
  errorMessage?: string
}

interface UserCredentialDispatchResult {
  credentials: LockScreenUKeyUserCredential[]
  failures: UserCredentialDispatchFailure[]
}

interface SystemCustomAuthCredentialRecord {
  userId: number
  credentialIdHex: string
  templateId: string
}

interface SystemCustomAuthCredentialReconcileResult {
  ownCredentials: LockScreenUKeyUserCredential[]
}

export class OsAccountUKeyUserProvider implements UKeyUserProvider {
  async loadAvailableUserIds(): Promise<OperationResult<number[]>> {
    try {
      let accountManager = osAccount.getAccountManager()
      let rawUserIds = await accountManager.getOsAccountLocalIds()
      let userIds = OsAccountUKeyUserProvider.normalizeUserIds(rawUserIds)
      if (userIds.length === 0) {
        return {
          success: false,
          data: [],
          errorMessage: '未读取到可下发的系统用户',
          userMessage: '未读取到可下发的系统用户',
          stage: 'query_user_ids'
        } as OperationResult<number[]>
      }
      return {
        success: true,
        data: userIds,
        stage: 'query_user_ids'
      } as OperationResult<number[]>
    } catch (err) {
      let errorCode = OsAccountCustomAuthCredentialManager.getErrorCode(err)
      let errorMessage = OsAccountCustomAuthCredentialManager.getErrorMessage(err)
      LogUtils.error(TAG, `[QUERY_USERS_FAIL] code=${errorCode}, message=${errorMessage}`)
      return {
        success: false,
        data: [],
        errorCode: errorCode,
        errorMessage: errorMessage,
        userMessage: '读取系统用户失败',
        stage: 'query_user_ids'
      } as OperationResult<number[]>
    }
  }

  private static normalizeUserIds(userIds: number[]): number[] {
    let normalizedIds = new Set<number>()
    userIds.forEach((userId: number) => {
      if (Number.isFinite(userId) && userId >= 0) {
        normalizedIds.add(userId)
      }
    })
    return Array.from(normalizedIds).sort((left: number, right: number): number => left - right)
  }
}

export class OsAccountCustomAuthCredentialVerifier implements CustomAuthCredentialVerifier {
  async verifyCredential(
    userId: number,
    credentialIdHex: string,
    challenge: Uint8Array
  ): Promise<CustomAuthCredentialVerificationResult> {
    let userAuth = new osAccount.UserAuth()
    let contextId = new Uint8Array(0)
    let challengeHex = OsAccountCustomAuthCredentialManager.toHex(challenge)
    try {
      return await new Promise<CustomAuthCredentialVerificationResult>(
        (resolve: (value: CustomAuthCredentialVerificationResult) => void): void => {
          let settled = false
          let timeoutId = setTimeout(() => {
            if (settled) {
              return
            }
            settled = true
            try {
              if (contextId.length > 0) {
                userAuth.cancelAuth(contextId)
              }
            } catch (err) {
              LogUtils.warn(TAG, `[VERIFY_CANCEL_FAIL] userId=${userId}, err=${JSON.stringify(err)}`)
            }
            resolve({
              success: false,
              userId: userId,
              credentialIdHex: credentialIdHex,
              challengeHex: challengeHex,
              errorCode: -1,
              errorMessage: 'CustomAuth credential verification timeout'
            })
          }, CUSTOM_AUTH_VERIFY_TIMEOUT_MS)

          let finish = (result: CustomAuthCredentialVerificationResult): void => {
            if (settled) {
              return
            }
            settled = true
            clearTimeout(timeoutId)
            resolve(result)
          }

          let callback: osAccount.IUserAuthCallback = {
            onResult: (result: number, extraInfo: osAccount.AuthResult): void => {
              finish({
                success: result === 0,
                userId: userId,
                credentialIdHex: credentialIdHex,
                challengeHex: challengeHex,
                resultCode: result,
                tokenLength: extraInfo.token ? extraInfo.token.length : 0,
                errorCode: result === 0 ? undefined : result,
                errorMessage: result === 0 ? undefined : `CustomAuth credential verification failed, result=${result}`
              })
            },
            onAcquireInfo: (_module: number, _acquire: number, _extraInfo: Uint8Array): void => {
            }
          }

          try {
            contextId = userAuth.authUser(
              userId,
              challenge,
              LOCKSCREEN_CUSTOM_AUTH_TYPE as osAccount.AuthType,
              osAccount.AuthTrustLevel.ATL3,
              callback
            )
          } catch (err) {
            finish({
              success: false,
              userId: userId,
              credentialIdHex: credentialIdHex,
              challengeHex: challengeHex,
              errorCode: OsAccountCustomAuthCredentialManager.getErrorCode(err),
              errorMessage: OsAccountCustomAuthCredentialManager.getErrorMessage(err)
            })
          }
        }
      )
    } catch (err) {
      return {
        success: false,
        userId: userId,
        credentialIdHex: credentialIdHex,
        challengeHex: challengeHex,
        errorCode: OsAccountCustomAuthCredentialManager.getErrorCode(err),
        errorMessage: OsAccountCustomAuthCredentialManager.getErrorMessage(err)
      }
    }
  }
}

export class OsAccountCustomAuthCredentialManager implements CustomAuthCredentialManager {
  async addCredential(
    userId: number,
    pluginInfo: string,
    systemPin: string
  ): Promise<CustomAuthCredentialRegistrationResult> {
    if (systemPin.length === 0) {
      return {
        success: false,
        errorCode: -1,
        errorMessage: 'system PIN is required'
      }
    }
    let idm: osAccount.UserIdentityManager | null = null
    let sessionOpened = false
    try {
      idm = new osAccount.UserIdentityManager()
      let challenge = await idm.openSession(userId)
      sessionOpened = true
      let tokenResult = await OsAccountCustomAuthCredentialManager.getPinAuthToken(userId, challenge, systemPin)
      if (!tokenResult.success || !tokenResult.token || tokenResult.token.length === 0) {
        return {
          success: false,
          resultCode: tokenResult.resultCode,
          errorCode: tokenResult.errorCode ?? -1,
          errorMessage: tokenResult.errorMessage ?? 'PIN authentication failed'
        }
      }
      let credentialInfo: osAccount.CredentialInfo = {
        credType: LOCKSCREEN_CUSTOM_AUTH_TYPE as osAccount.AuthType,
        credSubType: LOCKSCREEN_CUSTOM_AUTH_SUB_TYPE as number as osAccount.AuthSubType,
        token: tokenResult.token,
        accountId: userId,
        additionalInfo: pluginInfo
      }
      let result = await OsAccountCustomAuthCredentialManager.addCredentialByCallback(idm, credentialInfo)
      let credentialIdHex = OsAccountCustomAuthCredentialManager.toHex(result.credentialId)
      return {
        success: result.resultCode === 0 && credentialIdHex.length > 0,
        resultCode: result.resultCode,
        credentialIdHex: credentialIdHex
      }
    } catch (err) {
      let errorCode = OsAccountCustomAuthCredentialManager.getErrorCode(err)
      let errorMessage = OsAccountCustomAuthCredentialManager.getErrorMessage(err)
      LogUtils.error(TAG, `[REGISTER_FAIL] osAccount addCredential | code=${errorCode}, message=${errorMessage}`)
      return {
        success: false,
        errorCode: errorCode,
        errorMessage: errorMessage
      }
    } finally {
      OsAccountCustomAuthCredentialManager.closeSessionBestEffort(idm, userId, sessionOpened)
    }
  }

  async deleteCredential(
    userId: number,
    credentialIdHex: string,
    systemPin: string
  ): Promise<CustomAuthCredentialDeletionResult> {
    if (systemPin.length === 0) {
      return {
        success: false,
        errorCode: -1,
        errorMessage: 'system PIN is required',
        credentialIdHex: credentialIdHex
      }
    }
    if (credentialIdHex.length === 0) {
      return {
        success: false,
        errorCode: -1,
        errorMessage: 'invalid credentialId'
      }
    }
    let credentialId = OsAccountCustomAuthCredentialManager.hexToBytes(credentialIdHex)
    if (credentialId.length === 0) {
      return {
        success: false,
        errorCode: -1,
        errorMessage: 'invalid credentialId'
      }
    }
    let idm: osAccount.UserIdentityManager | null = null
    let sessionOpened = false
    try {
      idm = new osAccount.UserIdentityManager()
      let challenge = await idm.openSession(userId)
      sessionOpened = true
      let tokenResult = await OsAccountCustomAuthCredentialManager.getPinAuthToken(userId, challenge, systemPin)
      if (!tokenResult.success || !tokenResult.token || tokenResult.token.length === 0) {
        return {
          success: false,
          resultCode: tokenResult.resultCode,
          errorCode: tokenResult.errorCode ?? -1,
          errorMessage: tokenResult.errorMessage ?? 'PIN authentication failed',
          credentialIdHex: credentialIdHex
        }
      }
      let result = await OsAccountCustomAuthCredentialManager.deleteCredentialByCallback(
        idm,
        credentialId,
        tokenResult.token
      )
      return {
        success: result.resultCode === 0,
        resultCode: result.resultCode,
        credentialIdHex: credentialIdHex
      }
    } catch (err) {
      let errorCode = OsAccountCustomAuthCredentialManager.getErrorCode(err)
      let errorMessage = OsAccountCustomAuthCredentialManager.getErrorMessage(err)
      LogUtils.error(TAG, `[DELETE_FAIL] osAccount delCred | code=${errorCode}, message=${errorMessage}`)
      return {
        success: false,
        errorCode: errorCode,
        errorMessage: errorMessage,
        credentialIdHex: credentialIdHex
      }
    } finally {
      OsAccountCustomAuthCredentialManager.closeSessionBestEffort(idm, userId, sessionOpened)
    }
  }

  async listCustomAuthCredentialIds(userId: number): Promise<CustomAuthCredentialListResult> {
    try {
      let idm = new osAccount.UserIdentityManager()
      let infos = await idm.getAuthInfo({
        authType: LOCKSCREEN_CUSTOM_AUTH_TYPE as osAccount.AuthType,
        accountId: userId
      })
      let credentials: CustomAuthSystemCredentialInfo[] = []
      let seen = new Set<string>()
      for (let i = 0; i < infos.length; i++) {
        let credentialIdHex = OsAccountCustomAuthCredentialManager.toHex(infos[i].credentialId)
        let templateId = OsAccountCustomAuthCredentialManager.decodeTemplateId(infos[i].templateId)
        if (credentialIdHex.length === 0 || templateId.length === 0 || seen.has(credentialIdHex)) {
          continue
        }
        seen.add(credentialIdHex)
        credentials.push({
          userId: userId,
          credentialIdHex: credentialIdHex,
          templateId: templateId
        })
      }
      return {
        success: true,
        userId: userId,
        credentials: credentials
      }
    } catch (err) {
      let errorCode = OsAccountCustomAuthCredentialManager.getErrorCode(err)
      let errorMessage = OsAccountCustomAuthCredentialManager.getErrorMessage(err)
      LogUtils.error(TAG, `[LIST_CUSTOM_CRED_FAIL] userId=${userId}, code=${errorCode}, message=${errorMessage}`)
      return {
        success: false,
        userId: userId,
        credentials: [],
        errorCode: errorCode,
        errorMessage: errorMessage
      }
    }
  }

  private static async getPinAuthToken(
    userId: number,
    challenge: Uint8Array,
    systemPin: string
  ): Promise<PinAuthTokenResult> {
    let pinAuth = new osAccount.PINAuth()
    let inputerRegistered = false
    try {
      let pinData = OsAccountCustomAuthCredentialManager.stringToBytes(systemPin)
      let inputer: osAccount.IInputer = {
        onGetData: (authSubType: osAccount.AuthSubType, callback: osAccount.IInputData,
          _options: osAccount.GetInputDataOptions): void => {
          callback.onSetData(authSubType, pinData)
        }
      }
      pinAuth.registerInputer(inputer)
      inputerRegistered = true
      let userAuth = new osAccount.UserAuth()
      return await new Promise<PinAuthTokenResult>((resolve: (value: PinAuthTokenResult) => void): void => {
        let callback: osAccount.IUserAuthCallback = {
          onResult: (result: number, extraInfo: osAccount.AuthResult): void => {
            if (result === 0 && extraInfo.token && extraInfo.token.length > 0) {
              resolve({
                success: true,
                token: extraInfo.token,
                resultCode: result
              })
              return
            }
            resolve({
              success: false,
              resultCode: result,
              errorCode: result,
              errorMessage: `PIN authentication failed, result=${result}`
            })
          },
          onAcquireInfo: (_module: number, _acquire: number, _extraInfo: Uint8Array): void => {
          }
        }
        try {
          userAuth.authUser(userId, challenge, osAccount.AuthType.PIN, osAccount.AuthTrustLevel.ATL3, callback)
        } catch (err) {
          resolve({
            success: false,
            errorCode: OsAccountCustomAuthCredentialManager.getErrorCode(err),
            errorMessage: OsAccountCustomAuthCredentialManager.getErrorMessage(err)
          })
        }
      })
    } catch (err) {
      return {
        success: false,
        errorCode: OsAccountCustomAuthCredentialManager.getErrorCode(err),
        errorMessage: OsAccountCustomAuthCredentialManager.getErrorMessage(err)
      }
    } finally {
      if (inputerRegistered) {
        try {
          pinAuth.unregisterInputer()
        } catch (err) {
          LogUtils.warn(TAG, `[PIN_INPUTER_UNREGISTER_FAIL] err=${JSON.stringify(err)}`)
        }
      }
    }
  }

  private static async addCredentialByCallback(
    idm: osAccount.UserIdentityManager,
    credentialInfo: osAccount.CredentialInfo
  ): Promise<IdmOperationResult> {
    return await new Promise<IdmOperationResult>((resolve: (value: IdmOperationResult) => void): void => {
      let callback: osAccount.IIdmCallback = {
        onResult: (result: number, extraInfo: osAccount.RequestResult): void => {
          resolve({
            resultCode: result,
            credentialId: extraInfo.credentialId
          })
        },
        onAcquireInfo: (_module: number, _acquire: number, _extraInfo: Uint8Array): void => {
        }
      }
      try {
        idm.addCredential(credentialInfo, callback)
      } catch (err) {
        resolve({
          resultCode: OsAccountCustomAuthCredentialManager.getErrorCode(err)
        })
      }
    })
  }

  private static async deleteCredentialByCallback(
    idm: osAccount.UserIdentityManager,
    credentialId: Uint8Array,
    token: Uint8Array
  ): Promise<IdmOperationResult> {
    return await new Promise<IdmOperationResult>((resolve: (value: IdmOperationResult) => void): void => {
      let callback: osAccount.IIdmCallback = {
        onResult: (result: number, extraInfo: osAccount.RequestResult): void => {
          resolve({
            resultCode: result,
            credentialId: extraInfo.credentialId
          })
        },
        onAcquireInfo: (_module: number, _acquire: number, _extraInfo: Uint8Array): void => {
        }
      }
      try {
        idm.delCred(credentialId, token, callback)
      } catch (err) {
        resolve({
          resultCode: OsAccountCustomAuthCredentialManager.getErrorCode(err)
        })
      }
    })
  }

  private static closeSessionBestEffort(
    idm: osAccount.UserIdentityManager | null,
    userId: number,
    sessionOpened: boolean
  ): void {
    if (!sessionOpened || !idm) {
      return
    }
    try {
      idm.closeSession(userId)
    } catch (err) {
      LogUtils.warn(TAG, `[CLOSE_SESSION_FAIL] userId=${userId}, err=${JSON.stringify(err)}`)
    }
  }

  private static stringToBytes(value: string): Uint8Array {
    let bytes = new Uint8Array(value.length)
    for (let i = 0; i < value.length; i++) {
      bytes[i] = value.charCodeAt(i) & 0xFF
    }
    return bytes
  }

  static toHex(data?: Uint8Array): string {
    if (!data || data.length === 0) {
      return ''
    }
    let parts: string[] = []
    for (let i = 0; i < data.length; i++) {
      parts.push(data[i].toString(16).padStart(2, '0'))
    }
    return parts.join('')
  }

  static decodeTemplateId(data?: Uint8Array): string {
    if (!data || data.length !== 8) {
      return ''
    }
    try {
      return decodeUint64Be(data)
    } catch (err) {
      LogUtils.warn(TAG, `[DECODE_TEMPLATE_ID_FAIL] err=${JSON.stringify(err)}`)
      return ''
    }
  }

  private static hexToBytes(hex: string): Uint8Array {
    if (!hex || hex.length === 0) {
      return new Uint8Array(0)
    }
    let clean = hex.replace(/[^0-9a-fA-F]/g, '')
    if (clean.length === 0 || clean.length % 2 !== 0) {
      return new Uint8Array(0)
    }
    let bytes = new Uint8Array(clean.length / 2)
    for (let i = 0; i < bytes.length; i++) {
      bytes[i] = parseInt(clean.substring(i * 2, i * 2 + 2), 16)
    }
    return bytes
  }

  static getErrorCode(err: Error | BusinessError | Object): number {
    return typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
  }

  static getErrorMessage(err: Error | BusinessError | Object): string {
    let error = err as Error
    if (typeof error?.message === 'string' && error.message.length > 0) {
      return error.message
    }
    return 'unknown'
  }
}

export class LockScreenCustomAuthEnrollmentService implements LockScreenUKeyEnrollmentService {
  private static pendingOperation: Promise<OperationResult<LockScreenUKeyBinding | null>> | null = null
  private readonly bindingRepository: LockScreenUKeyBindingRepository
  private readonly activeCredentialRepository: LockScreenUKeyActiveCredentialRepository
  private readonly deviceProvider: LockScreenUKeyDeviceProvider
  private readonly registrar: CustomAuthCredentialManager
  private readonly userProvider: UKeyUserProvider
  private readonly verifier: CustomAuthCredentialVerifier
  private readonly templateBindingRepository: AuthenticatorUKeyTemplateBindingRepository

  constructor(
    bindingRepository: LockScreenUKeyBindingRepository = new PreferencesLockScreenUKeyBindingRepository(),
    deviceProvider: LockScreenUKeyDeviceProvider = new DdkLockScreenUKeyDeviceService(),
    registrar: CustomAuthCredentialManager = new OsAccountCustomAuthCredentialManager(),
    activeCredentialRepository: LockScreenUKeyActiveCredentialRepository =
      new PreferencesLockScreenUKeyActiveCredentialRepository(),
    userProvider: UKeyUserProvider = new OsAccountUKeyUserProvider(),
    verifier: CustomAuthCredentialVerifier = new OsAccountCustomAuthCredentialVerifier(),
    templateBindingRepository: AuthenticatorUKeyTemplateBindingRepository =
      new PreferencesAuthenticatorUKeyTemplateBindingRepository()
  ) {
    this.bindingRepository = bindingRepository
    this.deviceProvider = deviceProvider
    this.registrar = registrar
    this.activeCredentialRepository = activeCredentialRepository
    this.userProvider = userProvider
    this.verifier = verifier
    this.templateBindingRepository = templateBindingRepository
  }

  async ensureFirstUKeyRegistered(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await this.onUKeyAttached(context)
  }

  async addCredentialWithUserInput(
    context: common.Context,
    systemPin: string,
    ukeyPassword: string
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await LockScreenCustomAuthEnrollmentService.runSerialized(
      (): Promise<OperationResult<LockScreenUKeyBinding | null>> => {
        return this.doAddCredentialWithUserInput(context, systemPin.trim(), ukeyPassword.trim())
      }
    )
  }

  async deleteActiveCredentialByPin(
    context: common.Context,
    systemPin: string
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await LockScreenCustomAuthEnrollmentService.runSerialized(
      (): Promise<OperationResult<LockScreenUKeyBinding | null>> => {
        return this.doDeleteActiveCredentialByPin(context, systemPin.trim())
      }
    )
  }

  async reconcileSystemCredentials(
    context: common.Context
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await LockScreenCustomAuthEnrollmentService.runSerialized(
      (): Promise<OperationResult<LockScreenUKeyBinding | null>> => {
        return this.doReconcileSystemCredentials(context)
      }
    )
  }

  async onUKeyAttached(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await LockScreenCustomAuthEnrollmentService.runSerialized(
      (): Promise<OperationResult<LockScreenUKeyBinding | null>> => this.doHandleUKeyAttached(context)
    )
  }

  async onUKeyDetached(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await LockScreenCustomAuthEnrollmentService.runSerialized(
      (): Promise<OperationResult<LockScreenUKeyBinding | null>> => this.doHandleUKeyDetached(context)
    )
  }

  async reconcileOnStartup(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await LockScreenCustomAuthEnrollmentService.runSerialized(
      (): Promise<OperationResult<LockScreenUKeyBinding | null>> => this.doReconcileOnStartup(context)
    )
  }

  async disableAndDeleteActiveCredential(
    context: common.Context
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await LockScreenCustomAuthEnrollmentService.runSerialized(
      (): Promise<OperationResult<LockScreenUKeyBinding | null>> => this.doDisableAndDeleteActiveCredential(context)
    )
  }

  async verifyActiveCredentials(
    context: common.Context
  ): Promise<OperationResult<CustomAuthCredentialVerificationSummary>> {
    let active = await this.activeCredentialRepository.loadActiveCredential(context)
    if (!active || active.userCredentials.length === 0) {
      return {
        success: false,
        errorMessage: '当前无可验证的 UKEY解锁凭据',
        userMessage: '当前无可验证的 UKEY解锁凭据',
        stage: 'verify_credential'
      } as OperationResult<CustomAuthCredentialVerificationSummary>
    }

    let credentials = LockScreenCustomAuthEnrollmentService.extractUserCredentials(active).filter(
      (credential: LockScreenUKeyUserCredential): boolean => credential.lifecycle === 'active'
    )
    if (credentials.length === 0) {
      return {
        success: false,
        errorMessage: '当前无 active 状态的 UKEY解锁凭据',
        userMessage: '当前无 active 状态的 UKEY解锁凭据',
        stage: 'verify_credential'
      } as OperationResult<CustomAuthCredentialVerificationSummary>
    }

    let results: CustomAuthCredentialVerificationResult[] = []
    for (let credential of credentials) {
      let challenge = await generateRandom(CUSTOM_AUTH_VERIFY_CHALLENGE_LENGTH)
      if (!challenge) {
        results.push({
          success: false,
          userId: credential.userId,
          credentialIdHex: credential.credentialIdHex,
          challengeHex: '',
          errorCode: -1,
          errorMessage: 'Generate CustomAuth challenge failed'
        })
        continue
      }
      results.push(await this.verifier.verifyCredential(
        credential.userId,
        credential.credentialIdHex,
        challenge
      ))
    }

    let successCount = results.filter((result: CustomAuthCredentialVerificationResult): boolean => {
      return result.success
    }).length
    let summary: CustomAuthCredentialVerificationSummary = {
      total: results.length,
      successCount: successCount,
      failureCount: results.length - successCount,
      results: results
    }
    return {
      success: summary.total > 0 && summary.failureCount === 0,
      data: summary,
      errorMessage: summary.failureCount === 0 ? undefined : `UKEY解锁凭据认证失败，失败用户数 ${summary.failureCount}`,
      userMessage: summary.failureCount === 0 ? undefined : `UKEY解锁凭据认证失败，失败用户数 ${summary.failureCount}`,
      stage: 'verify_credential'
    } as OperationResult<CustomAuthCredentialVerificationSummary>
  }

  private async doDisableAndDeleteActiveCredential(
    context: common.Context
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let existing = await this.bindingRepository.loadBinding(context)
    return LockScreenCustomAuthEnrollmentService.failure(
      'system_pin_required',
      '删除 UKEY解锁凭据需要输入系统 PIN',
      existing ?? null
    )
  }

  private async doAddCredentialWithUserInput(
    context: common.Context,
    systemPin: string,
    ukeyPassword: string
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let existing = await this.bindingRepository.loadBinding(context)
    let active = await this.loadActiveCredential(context)
    if (systemPin.length === 0) {
      return LockScreenCustomAuthEnrollmentService.failure('system_pin_required', '请输入系统 PIN', existing)
    }
    if (ukeyPassword.length === 0) {
      return LockScreenCustomAuthEnrollmentService.failure('ukey_password_required', '请输入 UKey 密码', existing)
    }

    let deviceResult = this.deviceProvider.getCandidateDevices()
    if (!deviceResult.success) {
      return LockScreenCustomAuthEnrollmentService.failure(deviceResult.stage ?? 'query_usb_devices',
        deviceResult.errorMessage ?? '读取 UKey 失败',
        existing)
    }
    let candidates = deviceResult.data ?? []
    if (existing !== null && !LockScreenCustomAuthEnrollmentService.containsBoundDevice(existing, candidates)) {
      return LockScreenCustomAuthEnrollmentService.failure(
        'no_ukey',
        '请插入已绑定的目标 UKey 后再添加凭据',
        existing
      )
    }
    if (existing !== null) {
      let bound = existing
      let matching = candidates.filter((item: LockScreenUKeyDevice): boolean => item.fingerprint === bound.fingerprint)
      return await this.verifyUKeyPasswordAndEnsureAllUserCredentials(
        context,
        matching[0],
        bound,
        active,
        systemPin,
        ukeyPassword
      )
    }
    if (candidates.length === 0) {
      return LockScreenCustomAuthEnrollmentService.failure('no_ukey', '未检测到 UKey，请插入一把 UKey 后重试')
    }
    if (candidates.length > 1) {
      return LockScreenCustomAuthEnrollmentService.failure('multiple_ukeys', '检测到多把 UKey，请仅保留一把后重试')
    }
    return await this.verifyUKeyPasswordAndEnsureAllUserCredentials(
      context,
      candidates[0],
      null,
      active,
      systemPin,
      ukeyPassword
    )
  }

  private async doDeleteActiveCredentialByPin(
    context: common.Context,
    systemPin: string
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let existing = await this.bindingRepository.loadBinding(context)
    if (systemPin.length === 0) {
      return LockScreenCustomAuthEnrollmentService.failure('system_pin_required', '请输入系统 PIN', existing)
    }
    let active = await this.loadActiveCredential(context)
    if (!active) {
      return LockScreenCustomAuthEnrollmentService.success(existing ?? null, 'active_credential_missing')
    }
    return await this.deleteActiveCredential(
      context,
      existing ?? LockScreenCustomAuthEnrollmentService.toBindingFromActiveCredential(active),
      active,
      systemPin
    )
  }

  private async doHandleUKeyDetached(
    context: common.Context
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let existing = await this.bindingRepository.loadBinding(context)
    let active = await this.loadActiveCredential(context)
    if (!existing) {
      return LockScreenCustomAuthEnrollmentService.success(null, active ? 'active_credential_present' : 'active_credential_missing')
    }
    let deviceResult = this.deviceProvider.getCandidateDevices()
    if (!deviceResult.success) {
      LogUtils.warn(TAG, `[DETACH_QUERY_FAIL] stage=${deviceResult.stage ?? 'query_usb_devices'}`)
      return LockScreenCustomAuthEnrollmentService.success(existing, active ? 'active_credential_present' : 'active_credential_missing')
    }
    let candidates = deviceResult.data ?? []
    if (LockScreenCustomAuthEnrollmentService.containsBoundDevice(existing, candidates)) {
      return LockScreenCustomAuthEnrollmentService.success(existing, 'bound_device_present')
    }
    return LockScreenCustomAuthEnrollmentService.success(existing, active ? 'active_credential_present' : 'already_bound')
  }

  private async doReconcileOnStartup(
    context: common.Context
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let existing = await this.bindingRepository.loadBinding(context)
    if (!existing) {
      return LockScreenCustomAuthEnrollmentService.success(null, 'active_credential_missing')
    }
    let deviceResult = this.deviceProvider.getCandidateDevices()
    if (!deviceResult.success) {
      return LockScreenCustomAuthEnrollmentService.failure(deviceResult.stage ?? 'query_usb_devices',
        deviceResult.errorMessage ?? '读取 UKey 失败')
    }
    let candidates = deviceResult.data ?? []
    if (LockScreenCustomAuthEnrollmentService.containsBoundDevice(existing, candidates)) {
      return await this.resolveExistingBinding(context, existing, candidates)
    }
    let active = await this.loadActiveCredential(context)
    if (!active) {
      return LockScreenCustomAuthEnrollmentService.success(existing, 'active_credential_missing')
    }
    return LockScreenCustomAuthEnrollmentService.success(existing, 'active_credential_present')
  }

  private async doReconcileSystemCredentials(
    context: common.Context
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let existing = await this.bindingRepository.loadBinding(context)
    let targetDevice = this.resolveSystemCredentialRestoreDevice(existing)
    if (!targetDevice) {
      return LockScreenCustomAuthEnrollmentService.success(existing ?? null, 'active_credential_missing')
    }

    let userIdsResult = await this.userProvider.loadAvailableUserIds()
    if (!userIdsResult.success || !userIdsResult.data || userIdsResult.data.length === 0) {
      return LockScreenCustomAuthEnrollmentService.success(existing ?? null, 'active_credential_missing')
    }
    let templateBindings = await this.templateBindingRepository.loadTemplateBindings(context)
    let systemCredentialsResult = await this.loadSystemCustomAuthCredentials(userIdsResult.data)
    if (!systemCredentialsResult.success || !systemCredentialsResult.data) {
      return LockScreenCustomAuthEnrollmentService.success(existing ?? null, 'active_credential_missing')
    }

    let ownCredentials = LockScreenCustomAuthEnrollmentService.toOwnUserCredentials(
      systemCredentialsResult.data,
      templateBindings,
      targetDevice.fingerprint
    )
    if (ownCredentials.length === 0) {
      let active = await this.loadActiveCredential(context)
      if (active) {
        await this.activeCredentialRepository.clearActiveCredential(context)
      }
      return LockScreenCustomAuthEnrollmentService.success(existing ?? null, 'active_credential_missing')
    }

    let binding = LockScreenCustomAuthEnrollmentService.toBindingFromRecords(targetDevice, ownCredentials, existing)
    let saved = await this.bindingRepository.saveBinding(context, binding)
    if (!saved) {
      return LockScreenCustomAuthEnrollmentService.failure('save_binding', 'UKey 绑定记录保存失败', existing)
    }
    let activeSaved = await this.activeCredentialRepository.saveActiveCredential(
      context,
      LockScreenCustomAuthEnrollmentService.toActiveCredentialFromRecords(binding, ownCredentials, 'active')
    )
    if (!activeSaved) {
      return LockScreenCustomAuthEnrollmentService.failure('save_active_credential', 'UKEY解锁凭据状态保存失败', binding)
    }
    LogUtils.info(TAG, `[RESTORE_ACTIVE_FROM_SYSTEM] users=${ownCredentials.length}, deviceId=${binding.deviceId}`)
    return LockScreenCustomAuthEnrollmentService.success(binding, 'active_credential_present')
  }

  private resolveSystemCredentialRestoreDevice(existing: LockScreenUKeyBinding | null): LockScreenUKeyDevice | null {
    if (existing) {
      return LockScreenCustomAuthEnrollmentService.toDeviceFromBinding(existing)
    }
    let deviceResult = this.deviceProvider.getCandidateDevices()
    if (!deviceResult.success) {
      return null
    }
    let candidates = deviceResult.data ?? []
    return candidates.length === 1 ? candidates[0] : null
  }

  private async deleteActiveCredential(
    context: common.Context,
    existing: LockScreenUKeyBinding,
    active: LockScreenUKeyActiveCredential,
    systemPin: string
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let credentials = LockScreenCustomAuthEnrollmentService.extractUserCredentials(active)
    if (credentials.length === 0) {
      return LockScreenCustomAuthEnrollmentService.failure('delete_credential', 'UKEY解锁凭据状态异常')
    }

    let failedCredentials: LockScreenUKeyUserCredential[] = []
    for (let credential of credentials) {
      let deletion = await this.registrar.deleteCredential(credential.userId, credential.credentialIdHex, systemPin)
      if (!deletion.success) {
        failedCredentials.push({
          userId: credential.userId,
          credentialIdHex: credential.credentialIdHex,
          pluginInfo: credential.pluginInfo,
          lifecycle: 'failed',
          createdAt: credential.createdAt
        })
        LogUtils.warn(TAG, `[DELETE_USER_FAIL] userId=${credential.userId}, result=${deletion.resultCode ?? deletion.errorCode ?? -1}`)
      }
    }

    if (failedCredentials.length > 0) {
      let failedActive = LockScreenCustomAuthEnrollmentService.toActiveCredentialFromRecords(
        existing,
        failedCredentials,
        'failed',
        'failed'
      )
      await this.activeCredentialRepository.saveActiveCredential(context, failedActive)
      return LockScreenCustomAuthEnrollmentService.failure('delete_credential',
        `UKey 认证凭据删除失败，失败用户数 ${failedCredentials.length}`,
        existing)
    }

    let cleared = await this.activeCredentialRepository.clearActiveCredential(context)
    if (!cleared) {
      return LockScreenCustomAuthEnrollmentService.failure('clear_active_credential', 'UKEY解锁凭据状态清理失败')
    }
    LogUtils.info(TAG, `[DELETE_SUCCESS] users=${credentials.length}, deviceId=${active.deviceId}`)
    return LockScreenCustomAuthEnrollmentService.success(existing, 'credential_deleted')
  }

  private static async runSerialized(
    taskFactory: () => Promise<OperationResult<LockScreenUKeyBinding | null>>
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    if (LockScreenCustomAuthEnrollmentService.pendingOperation) {
      return await LockScreenCustomAuthEnrollmentService.pendingOperation
    }
    let task = taskFactory()
    LockScreenCustomAuthEnrollmentService.pendingOperation = task
    try {
      return await task
    } finally {
      if (LockScreenCustomAuthEnrollmentService.pendingOperation === task) {
        LockScreenCustomAuthEnrollmentService.pendingOperation = null
      }
    }
  }

  private async doHandleUKeyAttached(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let existing = await this.bindingRepository.loadBinding(context)
    let deviceResult = this.deviceProvider.getCandidateDevices()
    if (!deviceResult.success) {
      if (existing) {
        return LockScreenCustomAuthEnrollmentService.success(existing, 'already_bound')
      }
      return LockScreenCustomAuthEnrollmentService.failure(deviceResult.stage ?? 'query_usb_devices',
        deviceResult.errorMessage ?? '读取 UKey 失败')
    }

    let candidates = deviceResult.data ?? []
    if (existing) {
      return await this.resolveExistingBinding(context, existing, candidates)
    }
    if (candidates.length === 0) {
      return LockScreenCustomAuthEnrollmentService.failure('no_ukey', '未检测到 UKey，请插入一把 UKey 后重试')
    }
    if (candidates.length > 1) {
      return LockScreenCustomAuthEnrollmentService.failure('multiple_ukeys', '检测到多把 UKey，请仅保留一把后重试')
    }

    return LockScreenCustomAuthEnrollmentService.success(null, 'manual_input_required')
  }

  private async registerFirstUKey(
    context: common.Context,
    device: LockScreenUKeyDevice,
    systemPin: string,
    ukeyPassword: string
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await this.verifyUKeyPasswordAndEnsureAllUserCredentials(
      context,
      device,
      null,
      null,
      systemPin,
      ukeyPassword
    )
  }

  private async resolveExistingBinding(
    context: common.Context,
    existing: LockScreenUKeyBinding,
    candidates: LockScreenUKeyDevice[]
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    if (LockScreenCustomAuthEnrollmentService.containsBoundDevice(existing, candidates)) {
      let active = await this.loadActiveCredential(context)
      return LockScreenCustomAuthEnrollmentService.success(
        existing,
        active ? 'active_credential_present' : 'active_credential_missing'
      )
    }
    if (candidates.length > 0) {
      return Promise.resolve(LockScreenCustomAuthEnrollmentService.success(existing, 'bound_other_device_present'))
    }
    return Promise.resolve(LockScreenCustomAuthEnrollmentService.success(existing, 'already_bound'))
  }

  private async verifyUKeyPasswordAndEnsureAllUserCredentials(
    context: common.Context,
    device: LockScreenUKeyDevice,
    existing: LockScreenUKeyBinding | null,
    active: LockScreenUKeyActiveCredential | null,
    systemPin: string,
    ukeyPassword: string
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    authenticatorUKeyProvider.bindContext(context)
    if (await authenticatorUKeyProvider.isFingerprintLocked(context, device.fingerprint)) {
      return LockScreenCustomAuthEnrollmentService.failure('ukey_locked', 'UKey 密码已锁定', existing)
    }
    let passcodeResult = await authenticatorUKeyProvider.verifyPasscodeForFingerprint(
      context,
      device.fingerprint,
      ukeyPassword
    )
    if (!passcodeResult.success) {
      return LockScreenCustomAuthEnrollmentService.failure(
        passcodeResult.locked ? 'ukey_locked' : 'ukey_password_mismatch',
        passcodeResult.locked ? 'UKey 密码已锁定' : `UKey 密码错误，剩余 ${passcodeResult.remainingAttempts} 次`,
        existing
      )
    }
    let refreshedDevices = this.deviceProvider.getCandidateDevices()
    if (!refreshedDevices.success || !LockScreenCustomAuthEnrollmentService.containsDeviceFingerprint(
      device.fingerprint,
      refreshedDevices.data ?? []
    )) {
      return LockScreenCustomAuthEnrollmentService.failure('no_ukey', '目标 UKey 已移除，请重新插入后重试', existing)
    }
    return await this.ensureAllUserCredentials(context, device, existing, active, systemPin)
  }

  private async ensureAllUserCredentials(
    context: common.Context,
    device: LockScreenUKeyDevice,
    existing: LockScreenUKeyBinding | null,
    active: LockScreenUKeyActiveCredential | null,
    systemPin: string
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let userIdsResult = await this.userProvider.loadAvailableUserIds()
    if (!userIdsResult.success || !userIdsResult.data || userIdsResult.data.length === 0) {
      return LockScreenCustomAuthEnrollmentService.failure('query_user_ids',
        userIdsResult.userMessage ?? userIdsResult.errorMessage ?? '读取系统用户失败',
        existing)
    }

    let reconcile = await this.reconcileSystemCustomAuthCredentialsBeforeAdd(
      context,
      userIdsResult.data,
      device,
      active,
      systemPin
    )
    if (!reconcile.success) {
      return LockScreenCustomAuthEnrollmentService.failure(
        reconcile.stage ?? 'cleanup_credential',
        reconcile.userMessage ?? reconcile.errorMessage ?? 'UKEY解锁凭据清理失败',
        existing
      )
    }

    let reusableCredentials = reconcile.data?.ownCredentials ?? []
    let dispatch = await this.dispatchMissingCredentials(userIdsResult.data, reusableCredentials, systemPin)
    if (dispatch.credentials.length === 0) {
      return LockScreenCustomAuthEnrollmentService.failure('register_credential',
        'UKey 锁屏认证凭据注册失败',
        existing)
    }

    let binding = LockScreenCustomAuthEnrollmentService.toBindingFromRecords(device, dispatch.credentials, existing)
    let saved = await this.bindingRepository.saveBinding(context, binding)
    if (!saved) {
      return LockScreenCustomAuthEnrollmentService.failure('save_binding', 'UKey 绑定记录保存失败', binding)
    }

    let lifecycle: 'active' | 'failed' = dispatch.failures.length > 0 ? 'failed' : 'active'
    let activeSaved = await this.activeCredentialRepository.saveActiveCredential(
      context,
      LockScreenCustomAuthEnrollmentService.toActiveCredentialFromRecords(binding, dispatch.credentials, lifecycle)
    )
    if (!activeSaved) {
      return LockScreenCustomAuthEnrollmentService.failure('save_active_credential', 'UKEY解锁凭据状态保存失败', binding)
    }

    LogUtils.info(TAG, `[REGISTER_SUCCESS] users=${dispatch.credentials.length}, failures=${dispatch.failures.length}, deviceId=${binding.deviceId}`)
    if (dispatch.failures.length > 0) {
      return LockScreenCustomAuthEnrollmentService.failure('partial_registered',
        `UKey 锁屏认证凭据部分下发失败，失败用户数 ${dispatch.failures.length}`,
        binding)
    }
    return LockScreenCustomAuthEnrollmentService.success(binding, 'completed')
  }

  private async reconcileSystemCustomAuthCredentialsBeforeAdd(
    context: common.Context,
    targetUserIds: number[],
    device: LockScreenUKeyDevice,
    active: LockScreenUKeyActiveCredential | null,
    systemPin: string
  ): Promise<OperationResult<SystemCustomAuthCredentialReconcileResult>> {
    let templateBindings = await this.templateBindingRepository.loadTemplateBindings(context)
    let systemCredentialsResult = await this.loadSystemCustomAuthCredentials(targetUserIds)
    if (!systemCredentialsResult.success || !systemCredentialsResult.data) {
      return LockScreenCustomAuthEnrollmentService.failureForData<SystemCustomAuthCredentialReconcileResult>(
        'cleanup_credential',
        'UKEY解锁凭据读取失败'
      )
    }

    let ownCredentials: LockScreenUKeyUserCredential[] = []
    let deleteTargets: SystemCustomAuthCredentialRecord[] = []
    let keptUsers = new Set<number>()
    for (let credential of systemCredentialsResult.data) {
      if (templateBindings[credential.templateId] === device.fingerprint && !keptUsers.has(credential.userId)) {
        keptUsers.add(credential.userId)
        ownCredentials.push({
          userId: credential.userId,
          credentialIdHex: credential.credentialIdHex,
          pluginInfo: LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO,
          lifecycle: 'active',
          createdAt: Date.now()
        })
        continue
      }
      deleteTargets.push(credential)
    }

    let failedTargets: SystemCustomAuthCredentialRecord[] = []
    for (let target of deleteTargets) {
      let deletion = await this.registrar.deleteCredential(target.userId, target.credentialIdHex, systemPin)
      if (deletion.success) {
        continue
      }
      failedTargets.push(target)
      LogUtils.warn(TAG, `[CLEANUP_CUSTOM_CRED_FAIL] userId=${target.userId}, templateId=${target.templateId}, result=${deletion.resultCode ?? deletion.errorCode ?? -1}`)
    }
    if (failedTargets.length > 0) {
      return LockScreenCustomAuthEnrollmentService.failureForData<SystemCustomAuthCredentialReconcileResult>(
        'cleanup_credential',
        `UKEY解锁凭据清理失败，失败用户数 ${failedTargets.length}`
      )
    }

    if (active || systemCredentialsResult.data.length > 0) {
      let cleared = await this.activeCredentialRepository.clearActiveCredential(context)
      if (!cleared) {
        return LockScreenCustomAuthEnrollmentService.failureForData<SystemCustomAuthCredentialReconcileResult>(
          'clear_active_credential',
          'UKEY解锁凭据状态清理失败'
        )
      }
    }
    if (systemCredentialsResult.data.length > 0 || active) {
      LogUtils.info(TAG, `[RECONCILE_CUSTOM_CRED_DONE] own=${ownCredentials.length}, removed=${deleteTargets.length}, localActive=${!!active}`)
    }
    return {
      success: true,
      data: {
        ownCredentials: ownCredentials
      },
      stage: 'cleanup_credential'
    } as OperationResult<SystemCustomAuthCredentialReconcileResult>
  }

  private async loadSystemCustomAuthCredentials(
    targetUserIds: number[]
  ): Promise<OperationResult<SystemCustomAuthCredentialRecord[]>> {
    let credentials: SystemCustomAuthCredentialRecord[] = []
    let seen = new Set<string>()
    for (let userId of targetUserIds) {
      let listResult = await this.registrar.listCustomAuthCredentialIds(userId)
      if (!listResult.success) {
        return LockScreenCustomAuthEnrollmentService.failureForData<SystemCustomAuthCredentialRecord[]>(
          'cleanup_credential',
          listResult.errorMessage ?? 'UKEY解锁凭据读取失败'
        )
      }
      for (let credential of listResult.credentials) {
        let key = `${credential.userId}:${credential.credentialIdHex}`
        if (seen.has(key)) {
          continue
        }
        seen.add(key)
        credentials.push({
          userId: credential.userId,
          credentialIdHex: credential.credentialIdHex,
          templateId: credential.templateId
        })
      }
    }
    return {
      success: true,
      data: credentials,
      stage: 'cleanup_credential'
    } as OperationResult<SystemCustomAuthCredentialRecord[]>
  }

  private async dispatchMissingCredentials(
    targetUserIds: number[],
    existingCredentials: LockScreenUKeyUserCredential[],
    systemPin: string
  ): Promise<UserCredentialDispatchResult> {
    let credentials = LockScreenCustomAuthEnrollmentService.cloneActiveCredentialRecords(existingCredentials)
    let failures: UserCredentialDispatchFailure[] = []
    for (let userId of targetUserIds) {
      if (LockScreenCustomAuthEnrollmentService.containsCredentialForUser(credentials, userId)) {
        continue
      }
      let registration = await this.registrar.addCredential(userId, LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO, systemPin)
      if (registration.success && registration.credentialIdHex && registration.credentialIdHex.length > 0) {
        credentials.push({
          userId: userId,
          credentialIdHex: registration.credentialIdHex,
          pluginInfo: LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO,
          lifecycle: 'active',
          createdAt: Date.now()
        })
        continue
      }
      failures.push({
        userId: userId,
        resultCode: registration.resultCode,
        errorCode: registration.errorCode,
        errorMessage: registration.errorMessage
      })
      LogUtils.warn(TAG, `[REGISTER_USER_FAIL] userId=${userId}, result=${registration.resultCode ?? registration.errorCode ?? -1}`)
    }
    return {
      credentials: credentials,
      failures: failures
    }
  }

  private async loadActiveCredential(context: common.Context): Promise<LockScreenUKeyActiveCredential | null> {
    return await this.activeCredentialRepository.loadActiveCredential(context)
  }

  private static containsBoundDevice(binding: LockScreenUKeyBinding, candidates: LockScreenUKeyDevice[]): boolean {
    return candidates.some((item: LockScreenUKeyDevice): boolean => item.fingerprint === binding.fingerprint)
  }

  private static containsDeviceFingerprint(fingerprint: string, candidates: LockScreenUKeyDevice[]): boolean {
    return candidates.some((item: LockScreenUKeyDevice): boolean => item.fingerprint === fingerprint)
  }

  private static toOwnUserCredentials(
    systemCredentials: SystemCustomAuthCredentialRecord[],
    templateBindings: AuthenticatorUKeyTemplateBindingMap,
    fingerprint: string
  ): LockScreenUKeyUserCredential[] {
    let credentials: LockScreenUKeyUserCredential[] = []
    let keptUsers = new Set<number>()
    for (let credential of systemCredentials) {
      if (templateBindings[credential.templateId] !== fingerprint || keptUsers.has(credential.userId)) {
        continue
      }
      keptUsers.add(credential.userId)
      credentials.push({
        userId: credential.userId,
        credentialIdHex: credential.credentialIdHex,
        pluginInfo: LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO,
        lifecycle: 'active',
        createdAt: Date.now()
      })
    }
    return credentials
  }

  private static toDeviceFromBinding(binding: LockScreenUKeyBinding): LockScreenUKeyDevice {
    return {
      fingerprint: binding.fingerprint,
      deviceId: binding.deviceId,
      vendorId: 0,
      productId: 0,
      serial: '',
      manufacturerName: '',
      productName: binding.deviceName,
      deviceName: binding.deviceName,
      clazz: 0,
      subClass: 0,
      protocol: 0,
      stableIdentifier: binding.stableIdentifier
    }
  }

  private static toBindingFromRecords(
    device: LockScreenUKeyDevice,
    credentials: LockScreenUKeyUserCredential[],
    existing: LockScreenUKeyBinding | null
  ): LockScreenUKeyBinding {
    let primary = credentials[0]
    return {
      fingerprint: device.fingerprint,
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      userId: primary.userId,
      credentialIdHex: primary.credentialIdHex,
      pluginInfo: primary.pluginInfo,
      boundAt: existing ? existing.boundAt : Date.now(),
      stableIdentifier: device.stableIdentifier,
      userCredentials: LockScreenCustomAuthEnrollmentService.cloneActiveCredentialRecords(credentials)
    }
  }

  private static toBindingFromActiveCredential(active: LockScreenUKeyActiveCredential): LockScreenUKeyBinding {
    let credentials = LockScreenCustomAuthEnrollmentService.extractUserCredentials(active)
    let primary = credentials[0]
    return {
      fingerprint: active.fingerprint,
      deviceId: active.deviceId,
      deviceName: active.deviceName,
      userId: primary.userId,
      credentialIdHex: primary.credentialIdHex,
      pluginInfo: primary.pluginInfo,
      boundAt: active.createdAt,
      stableIdentifier: false,
      userCredentials: credentials
    }
  }

  private static toActiveCredentialFromRecords(
    binding: LockScreenUKeyBinding,
    credentials: LockScreenUKeyUserCredential[],
    lifecycle: 'active' | 'failed',
    recordLifecycle: 'active' | 'failed' = 'active'
  ): LockScreenUKeyActiveCredential {
    let normalizedCredentials = LockScreenCustomAuthEnrollmentService.cloneCredentialRecords(credentials, recordLifecycle)
    let primary = normalizedCredentials[0]
    return {
      credentialIdHex: primary.credentialIdHex,
      userId: primary.userId,
      pluginInfo: primary.pluginInfo,
      fingerprint: binding.fingerprint,
      deviceId: binding.deviceId,
      deviceName: binding.deviceName,
      createdAt: Date.now(),
      lifecycle: lifecycle,
      userCredentials: normalizedCredentials
    }
  }

  private static extractPersistedCredentials(
    binding: LockScreenUKeyBinding | null,
    active: LockScreenUKeyActiveCredential | null
  ): LockScreenUKeyUserCredential[] {
    if (active) {
      let activeCredentials = LockScreenCustomAuthEnrollmentService.extractUserCredentials(active)
      if (activeCredentials.length > 0) {
        return activeCredentials
      }
    }
    if (!binding) {
      return []
    }
    return LockScreenCustomAuthEnrollmentService.normalizeUserCredentials(binding.userCredentials)
  }

  private static extractUserCredentials(active: LockScreenUKeyActiveCredential): LockScreenUKeyUserCredential[] {
    return LockScreenCustomAuthEnrollmentService.normalizeUserCredentials(active.userCredentials)
  }

  private static normalizeUserCredentials(
    credentials: LockScreenUKeyUserCredential[]
  ): LockScreenUKeyUserCredential[] {
    let normalized: LockScreenUKeyUserCredential[] = []
    for (let credential of credentials) {
      if (!Number.isFinite(credential.userId) || credential.credentialIdHex.length === 0 ||
        credential.pluginInfo.length === 0) {
        continue
      }
      if (LockScreenCustomAuthEnrollmentService.containsCredentialForUser(normalized, credential.userId)) {
        continue
      }
      normalized.push({
        userId: credential.userId,
        credentialIdHex: credential.credentialIdHex,
        pluginInfo: credential.pluginInfo,
        lifecycle: credential.lifecycle === 'failed' ? 'failed' : 'active',
        createdAt: Number.isFinite(credential.createdAt) ? credential.createdAt : Date.now()
      })
    }
    return normalized
  }

  private static cloneActiveCredentialRecords(
    credentials: LockScreenUKeyUserCredential[]
  ): LockScreenUKeyUserCredential[] {
    return LockScreenCustomAuthEnrollmentService.cloneCredentialRecords(credentials, 'active')
  }

  private static cloneCredentialRecords(
    credentials: LockScreenUKeyUserCredential[],
    lifecycle: 'active' | 'failed'
  ): LockScreenUKeyUserCredential[] {
    let normalized = LockScreenCustomAuthEnrollmentService.normalizeUserCredentials(credentials)
    return normalized.map((credential: LockScreenUKeyUserCredential): LockScreenUKeyUserCredential => {
      return {
        userId: credential.userId,
        credentialIdHex: credential.credentialIdHex,
        pluginInfo: credential.pluginInfo,
        lifecycle: lifecycle,
        createdAt: credential.createdAt
      }
    })
  }

  private static containsCredentialForUser(credentials: LockScreenUKeyUserCredential[], userId: number): boolean {
    return credentials.some((credential: LockScreenUKeyUserCredential): boolean => {
      return credential.userId === userId && credential.credentialIdHex.length > 0
    })
  }

  private static success(
    binding: LockScreenUKeyBinding | null,
    stage: LockScreenUKeyEnrollmentStage
  ): OperationResult<LockScreenUKeyBinding | null> {
    return {
      success: true,
      data: binding,
      stage: stage
    } as OperationResult<LockScreenUKeyBinding | null>
  }

  private static failure(
    stage: string,
    message: string,
    binding: LockScreenUKeyBinding | null = null
  ): OperationResult<LockScreenUKeyBinding | null> {
    return {
      success: false,
      data: binding,
      errorMessage: message,
      userMessage: message,
      stage: stage
    } as OperationResult<LockScreenUKeyBinding | null>
  }

  private static failureForData<T>(
    stage: string,
    message: string
  ): OperationResult<T> {
    return {
      success: false,
      errorMessage: message,
      userMessage: message,
      stage: stage
    } as OperationResult<T>
  }
}

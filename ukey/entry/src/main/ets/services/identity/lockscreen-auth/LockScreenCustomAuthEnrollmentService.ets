import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import osAccount from '@ohos.account.osAccount'
import { OperationResult } from '../../../models/CommonModels'
import {
  LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO,
  LockScreenUKeyActiveCredential,
  LockScreenUKeyBinding,
  LockScreenUKeyDevice
} from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { LogUtils } from '../../../utils/LogUtils'
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
const DEFAULT_OS_ACCOUNT_ID = 100
const LOCKSCREEN_CUSTOM_AUTH_TYPE = 128
const LOCKSCREEN_CUSTOM_AUTH_SUB_TYPE = 0
const TEE_RESULT_CREDENTIAL_LIMIT_REACHED = 10018
const ACCOUNT_RESULT_CREDENTIAL_LIMIT_REACHED = 12300115
const DEFAULT_TEST_PIN = '111111'

export type LockScreenUKeyEnrollmentStage =
  'already_bound' |
  'bound_device_present' |
  'bound_other_device_present' |
  'no_ukey' |
  'multiple_ukeys' |
  'register_credential' |
  'delete_credential' |
  'credential_deleted' |
  'active_credential_present' |
  'active_credential_missing' |
  'save_binding' |
  'save_active_credential' |
  'clear_active_credential' |
  'startup_reconcile' |
  'query_user_id' |
  'completed'

export interface CustomAuthCredentialRegistrationResult {
  success: boolean
  resultCode?: number
  credentialIdHex?: string
  errorCode?: number
  errorMessage?: string
}

export interface CustomAuthCredentialRegistrar {
  addCredential(userId: number, pluginInfo: string): Promise<CustomAuthCredentialRegistrationResult>
}

export interface CustomAuthCredentialDeletionResult {
  success: boolean
  resultCode?: number
  credentialIdHex?: string
  errorCode?: number
  errorMessage?: string
}

export interface CustomAuthCredentialManager extends CustomAuthCredentialRegistrar {
  deleteCredential(userId: number, credentialIdHex: string): Promise<CustomAuthCredentialDeletionResult>
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

export class OsAccountCustomAuthCredentialManager implements CustomAuthCredentialManager {
  async addCredential(userId: number, pluginInfo: string): Promise<CustomAuthCredentialRegistrationResult> {
    let idm: osAccount.UserIdentityManager | null = null
    let sessionOpened = false
    try {
      idm = new osAccount.UserIdentityManager()
      let challenge = await idm.openSession(userId)
      sessionOpened = true
      let tokenResult = await OsAccountCustomAuthCredentialManager.getPinAuthToken(userId, challenge)
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
      if (OsAccountCustomAuthCredentialManager.isCredentialLimitReached(result.resultCode)) {
        return await OsAccountCustomAuthCredentialManager.deleteStaleCredentialAndRetryAdd(
          idm,
          userId,
          tokenResult.token,
          credentialInfo
        )
      }
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

  async deleteCredential(userId: number, credentialIdHex: string): Promise<CustomAuthCredentialDeletionResult> {
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
      let tokenResult = await OsAccountCustomAuthCredentialManager.getPinAuthToken(userId, challenge)
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

  private static async getPinAuthToken(userId: number, challenge: Uint8Array): Promise<PinAuthTokenResult> {
    let pinAuth = new osAccount.PINAuth()
    let inputerRegistered = false
    try {
      let pinData = OsAccountCustomAuthCredentialManager.stringToBytes(DEFAULT_TEST_PIN)
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
          userAuth.authUser(userId, challenge, osAccount.AuthType.PIN, osAccount.AuthTrustLevel.ATL2, callback)
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

  private static async deleteStaleCredentialAndRetryAdd(
    idm: osAccount.UserIdentityManager,
    userId: number,
    token: Uint8Array,
    credentialInfo: osAccount.CredentialInfo
  ): Promise<CustomAuthCredentialRegistrationResult> {
    let existing = await OsAccountCustomAuthCredentialManager.queryCustomAuthCredentials(idm, userId)
    if (!existing.success) {
      return {
        success: false,
        resultCode: ACCOUNT_RESULT_CREDENTIAL_LIMIT_REACHED,
        errorCode: existing.errorCode ?? ACCOUNT_RESULT_CREDENTIAL_LIMIT_REACHED,
        errorMessage: existing.errorMessage ?? 'CustomAuth credential limit reached, query stale credential failed'
      }
    }
    let credentials = existing.data ?? []
    if (credentials.length === 0) {
      return {
        success: false,
        resultCode: ACCOUNT_RESULT_CREDENTIAL_LIMIT_REACHED,
        errorCode: ACCOUNT_RESULT_CREDENTIAL_LIMIT_REACHED,
        errorMessage: 'CustomAuth credential limit reached, no stale credential found'
      }
    }
    LogUtils.warn(TAG, `[STALE_CREDENTIAL_CLEAN_START] count=${credentials.length}`)
    for (let credential of credentials) {
      let credentialIdHex = OsAccountCustomAuthCredentialManager.toHex(credential.credentialId)
      let deletion = await OsAccountCustomAuthCredentialManager.deleteCredentialByCallback(
        idm,
        credential.credentialId,
        token
      )
      if (deletion.resultCode !== 0) {
        return {
          success: false,
          resultCode: deletion.resultCode,
          credentialIdHex: credentialIdHex,
          errorCode: deletion.resultCode,
          errorMessage: `Delete stale CustomAuth credential failed, result=${deletion.resultCode}`
        }
      }
      LogUtils.warn(TAG, `[STALE_CREDENTIAL_DELETE_SUCCESS] credentialId=${credentialIdHex}`)
    }
    let retry = await OsAccountCustomAuthCredentialManager.addCredentialByCallback(idm, credentialInfo)
    let retryCredentialIdHex = OsAccountCustomAuthCredentialManager.toHex(retry.credentialId)
    return {
      success: retry.resultCode === 0 && retryCredentialIdHex.length > 0,
      resultCode: retry.resultCode,
      credentialIdHex: retryCredentialIdHex,
      errorCode: retry.resultCode === 0 ? undefined : retry.resultCode,
      errorMessage: retry.resultCode === 0 ? undefined : `Retry add CustomAuth credential failed, result=${retry.resultCode}`
    }
  }

  private static isCredentialLimitReached(resultCode: number): boolean {
    return resultCode === TEE_RESULT_CREDENTIAL_LIMIT_REACHED ||
      resultCode === ACCOUNT_RESULT_CREDENTIAL_LIMIT_REACHED
  }

  private static async queryCustomAuthCredentials(
    idm: osAccount.UserIdentityManager,
    userId: number
  ): Promise<OperationResult<osAccount.EnrolledCredInfo[]>> {
    try {
      let credentials = await idm.getAuthInfo({
        authType: LOCKSCREEN_CUSTOM_AUTH_TYPE as osAccount.AuthType,
        accountId: userId
      })
      let activeCredentials = (credentials ?? []).filter((item: osAccount.EnrolledCredInfo): boolean => {
        return !!item.credentialId && item.credentialId.length > 0 && item.isAbandoned !== true
      })
      return {
        success: true,
        data: activeCredentials
      } as OperationResult<osAccount.EnrolledCredInfo[]>
    } catch (err) {
      return {
        success: false,
        errorCode: OsAccountCustomAuthCredentialManager.getErrorCode(err),
        errorMessage: OsAccountCustomAuthCredentialManager.getErrorMessage(err),
        stage: 'query_custom_auth_credentials'
      } as OperationResult<osAccount.EnrolledCredInfo[]>
    }
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

  private static toHex(data?: Uint8Array): string {
    if (!data || data.length === 0) {
      return ''
    }
    let parts: string[] = []
    for (let i = 0; i < data.length; i++) {
      parts.push(data[i].toString(16).padStart(2, '0'))
    }
    return parts.join('')
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

  private static getErrorCode(err: Error | BusinessError | Object): number {
    return typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
  }

  private static getErrorMessage(err: Error | BusinessError | Object): string {
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

  constructor(
    bindingRepository: LockScreenUKeyBindingRepository = new PreferencesLockScreenUKeyBindingRepository(),
    deviceProvider: LockScreenUKeyDeviceProvider = new DdkLockScreenUKeyDeviceService(),
    registrar: CustomAuthCredentialManager = new OsAccountCustomAuthCredentialManager(),
    activeCredentialRepository: LockScreenUKeyActiveCredentialRepository =
      new PreferencesLockScreenUKeyActiveCredentialRepository()
  ) {
    this.bindingRepository = bindingRepository
    this.deviceProvider = deviceProvider
    this.registrar = registrar
    this.activeCredentialRepository = activeCredentialRepository
  }

  async ensureFirstUKeyRegistered(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await this.onUKeyAttached(context)
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

  private async doDisableAndDeleteActiveCredential(
    context: common.Context
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let existing = await this.bindingRepository.loadBinding(context)
    if (!existing) {
      return LockScreenCustomAuthEnrollmentService.success(null, 'already_bound')
    }
    let active = await this.loadActiveCredentialOrLegacy(context, existing)
    if (!active) {
      return LockScreenCustomAuthEnrollmentService.success(existing, 'active_credential_missing')
    }
    return await this.deleteActiveCredential(context, existing, active)
  }

  private async doHandleUKeyDetached(
    context: common.Context
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let existing = await this.bindingRepository.loadBinding(context)
    if (!existing) {
      return LockScreenCustomAuthEnrollmentService.success(null, 'already_bound')
    }
    let deviceResult = this.deviceProvider.getCandidateDevices()
    if (!deviceResult.success) {
      return LockScreenCustomAuthEnrollmentService.failure(deviceResult.stage ?? 'query_usb_devices',
        deviceResult.errorMessage ?? '读取 UKey 失败')
    }
    let candidates = deviceResult.data ?? []
    if (LockScreenCustomAuthEnrollmentService.containsBoundDevice(existing, candidates)) {
      return LockScreenCustomAuthEnrollmentService.success(existing, 'bound_device_present')
    }
    let active = await this.loadActiveCredentialOrLegacy(context, existing)
    if (!active) {
      return LockScreenCustomAuthEnrollmentService.success(existing, 'active_credential_missing')
    }
    return await this.deleteActiveCredential(context, existing, active)
  }

  private async doReconcileOnStartup(
    context: common.Context
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let existing = await this.bindingRepository.loadBinding(context)
    if (!existing) {
      return await this.doHandleUKeyAttached(context)
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
    let active = await this.loadActiveCredentialOrLegacy(context, existing)
    if (!active) {
      return LockScreenCustomAuthEnrollmentService.success(existing, 'active_credential_missing')
    }
    return await this.deleteActiveCredential(context, existing, active)
  }

  private async deleteActiveCredential(
    context: common.Context,
    existing: LockScreenUKeyBinding,
    active: LockScreenUKeyActiveCredential
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let deletion = await this.registrar.deleteCredential(active.userId, active.credentialIdHex)
    if (!deletion.success) {
      await this.activeCredentialRepository.saveActiveCredential(context, {
        credentialIdHex: active.credentialIdHex,
        userId: active.userId,
        pluginInfo: active.pluginInfo,
        fingerprint: active.fingerprint,
        deviceId: active.deviceId,
        deviceName: active.deviceName,
        createdAt: active.createdAt,
        lifecycle: 'failed'
      })
      let codeText = typeof deletion.resultCode === 'number' ? `，结果码 ${deletion.resultCode}` : ''
      return LockScreenCustomAuthEnrollmentService.failure('delete_credential',
        `UKey 认证凭据删除失败${codeText}`)
    }
    let cleared = await this.activeCredentialRepository.clearActiveCredential(context)
    if (!cleared) {
      return LockScreenCustomAuthEnrollmentService.failure('clear_active_credential', 'UKEY解锁凭据状态清理失败')
    }
    LogUtils.info(TAG, `[DELETE_SUCCESS] userId=${active.userId}, deviceId=${active.deviceId}`)
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

    return await this.registerFirstUKey(context, candidates[0])
  }

  private async registerFirstUKey(
    context: common.Context,
    device: LockScreenUKeyDevice
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    let userIdResult = await LockScreenCustomAuthEnrollmentService.getCurrentUserId()
    if (!userIdResult.success || typeof userIdResult.data !== 'number') {
      return LockScreenCustomAuthEnrollmentService.failure('query_user_id',
        userIdResult.errorMessage ?? '读取当前用户失败')
    }
    let registration = await this.registrar.addCredential(userIdResult.data, LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO)
    if (!registration.success || !registration.credentialIdHex) {
      let codeText = typeof registration.resultCode === 'number' ? `，结果码 ${registration.resultCode}` : ''
      return LockScreenCustomAuthEnrollmentService.failure('register_credential',
        `UKey 锁屏认证凭据注册失败${codeText}`)
    }

    let binding: LockScreenUKeyBinding = {
      fingerprint: device.fingerprint,
      deviceId: device.deviceId,
      deviceName: device.deviceName,
      userId: userIdResult.data,
      credentialIdHex: registration.credentialIdHex,
      pluginInfo: LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO,
      boundAt: Date.now(),
      stableIdentifier: device.stableIdentifier
    }
    let saved = await this.bindingRepository.saveBinding(context, binding)
    if (!saved) {
      return LockScreenCustomAuthEnrollmentService.failure('save_binding', 'UKey 绑定记录保存失败')
    }
    let activeSaved = await this.activeCredentialRepository.saveActiveCredential(
      context,
      LockScreenCustomAuthEnrollmentService.toActiveCredential(binding)
    )
    if (!activeSaved) {
      return LockScreenCustomAuthEnrollmentService.failure('save_active_credential', 'UKEY解锁凭据状态保存失败')
    }
    LogUtils.info(TAG, `[REGISTER_SUCCESS] userId=${binding.userId}, deviceId=${binding.deviceId}`)
    return LockScreenCustomAuthEnrollmentService.success(binding, 'completed')
  }

  private async resolveExistingBinding(
    context: common.Context,
    existing: LockScreenUKeyBinding,
    candidates: LockScreenUKeyDevice[]
  ): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    if (LockScreenCustomAuthEnrollmentService.containsBoundDevice(existing, candidates)) {
      let active = await this.loadActiveCredentialOrLegacy(context, existing)
      if (active) {
        return LockScreenCustomAuthEnrollmentService.success(existing, 'active_credential_present')
      }
      let matching = candidates.filter((item: LockScreenUKeyDevice): boolean => item.fingerprint === existing.fingerprint)
      return await this.registerFirstUKey(context, matching[0])
    }
    if (candidates.length > 0) {
      return Promise.resolve(LockScreenCustomAuthEnrollmentService.success(existing, 'bound_other_device_present'))
    }
    return Promise.resolve(LockScreenCustomAuthEnrollmentService.success(existing, 'already_bound'))
  }

  private async loadActiveCredentialOrLegacy(
    context: common.Context,
    binding: LockScreenUKeyBinding
  ): Promise<LockScreenUKeyActiveCredential | null> {
    let active = await this.activeCredentialRepository.loadActiveCredential(context)
    if (active) {
      return active
    }
    if (binding.credentialIdHex.length === 0) {
      return null
    }
    return LockScreenCustomAuthEnrollmentService.toActiveCredential(binding)
  }

  private static containsBoundDevice(binding: LockScreenUKeyBinding, candidates: LockScreenUKeyDevice[]): boolean {
    return candidates.some((item: LockScreenUKeyDevice): boolean => item.fingerprint === binding.fingerprint)
  }

  private static toActiveCredential(binding: LockScreenUKeyBinding): LockScreenUKeyActiveCredential {
    return {
      credentialIdHex: binding.credentialIdHex,
      userId: binding.userId,
      pluginInfo: binding.pluginInfo,
      fingerprint: binding.fingerprint,
      deviceId: binding.deviceId,
      deviceName: binding.deviceName,
      createdAt: Date.now(),
      lifecycle: 'active'
    }
  }

  private static async getCurrentUserId(): Promise<OperationResult<number>> {
    return {
      success: true,
      data: DEFAULT_OS_ACCOUNT_ID,
      stage: 'default_user_id'
    } as OperationResult<number>
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

  private static failure(stage: string, message: string): OperationResult<LockScreenUKeyBinding | null> {
    return {
      success: false,
      data: null,
      errorMessage: message,
      userMessage: message,
      stage: stage
    } as OperationResult<LockScreenUKeyBinding | null>
  }
}

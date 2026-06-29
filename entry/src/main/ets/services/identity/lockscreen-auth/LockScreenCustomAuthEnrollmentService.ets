/// <reference path="../../../osAccountCustomAuthExtensions.d.ts" />

import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import osAccount from '@ohos.account.osAccount'
import { OperationResult } from '../../../models/CommonModels'
import {
  LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO,
  LockScreenUKeyBinding,
  LockScreenUKeyDevice
} from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import { LogUtils } from '../../../utils/LogUtils'
import {
  LockScreenUKeyBindingRepository,
  PreferencesLockScreenUKeyBindingRepository
} from './LockScreenUKeyBindingRepository'
import {
  LockScreenUKeyDeviceProvider,
  UsbLockScreenUKeyDeviceService
} from './LockScreenUKeyDeviceService'

const TAG = 'LockScreenCustomAuth.Enroll'
const CUSTOM_AUTH_TYPE = 128
const DEFAULT_OS_ACCOUNT_ID = 100

export type LockScreenUKeyEnrollmentStage =
  'already_bound' |
  'bound_device_present' |
  'bound_other_device_present' |
  'no_ukey' |
  'multiple_ukeys' |
  'register_credential' |
  'save_binding' |
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

export interface LockScreenUKeyEnrollmentService {
  ensureFirstUKeyRegistered(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>>
}

export class OsAccountCustomAuthCredentialRegistrar implements CustomAuthCredentialRegistrar {
  async addCredential(userId: number, pluginInfo: string): Promise<CustomAuthCredentialRegistrationResult> {
    let idm: osAccount.UserIdentityManager | null = null
    try {
      idm = new osAccount.UserIdentityManager()
      await idm.openSession(userId)
      let credentialInfo: osAccount.CredentialInfo = {
        credType: CUSTOM_AUTH_TYPE as osAccount.AuthType,
        credSubType: 0 as number as osAccount.AuthSubType,
        token: new Uint8Array(0),
        accountId: userId,
        additionalInfo: pluginInfo
      }
      let result = await OsAccountCustomAuthCredentialRegistrar.addCredentialAsync(idm, credentialInfo)
      return result
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.error(TAG, `[REGISTER_FAIL] addCredential | code=${errorCode}, message=${errorMessage}`)
      return {
        success: false,
        errorCode: errorCode,
        errorMessage: errorMessage
      }
    } finally {
      if (idm) {
        try {
          idm.closeSession(userId)
        } catch (err) {
          LogUtils.warn(TAG, `[CLOSE_SESSION_FAIL] userId=${userId}, err=${JSON.stringify(err)}`)
        }
      }
    }
  }

  private static addCredentialAsync(
    idm: osAccount.UserIdentityManager,
    credentialInfo: osAccount.CredentialInfo
  ): Promise<CustomAuthCredentialRegistrationResult> {
    return new Promise<CustomAuthCredentialRegistrationResult>((resolve) => {
      let callback: osAccount.IIdmCallback = {
        onResult: (result: number, extraInfo: osAccount.RequestResult): void => {
          let credentialIdHex = OsAccountCustomAuthCredentialRegistrar.toHex(extraInfo.credentialId)
          resolve({
            success: result === 0 && credentialIdHex.length > 0,
            resultCode: result,
            credentialIdHex: credentialIdHex
          })
        },
        onAcquireInfo: (_module: number, _acquire: number, _extraInfo: Uint8Array): void => {
        }
      }
      try {
        idm.addCredential(credentialInfo, callback)
      } catch (err) {
        let error = err as Error
        let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
        let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
        resolve({
          success: false,
          errorCode: errorCode,
          errorMessage: errorMessage
        })
      }
    })
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
}

export class LockScreenCustomAuthEnrollmentService implements LockScreenUKeyEnrollmentService {
  private static pendingEnrollment: Promise<OperationResult<LockScreenUKeyBinding | null>> | null = null
  private readonly bindingRepository: LockScreenUKeyBindingRepository
  private readonly deviceProvider: LockScreenUKeyDeviceProvider
  private readonly registrar: CustomAuthCredentialRegistrar

  constructor(
    bindingRepository: LockScreenUKeyBindingRepository = new PreferencesLockScreenUKeyBindingRepository(),
    deviceProvider: LockScreenUKeyDeviceProvider = new UsbLockScreenUKeyDeviceService(),
    registrar: CustomAuthCredentialRegistrar = new OsAccountCustomAuthCredentialRegistrar()
  ) {
    this.bindingRepository = bindingRepository
    this.deviceProvider = deviceProvider
    this.registrar = registrar
  }

  async ensureFirstUKeyRegistered(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    if (LockScreenCustomAuthEnrollmentService.pendingEnrollment) {
      return await LockScreenCustomAuthEnrollmentService.pendingEnrollment
    }
    let task = this.doEnsureFirstUKeyRegistered(context)
    LockScreenCustomAuthEnrollmentService.pendingEnrollment = task
    try {
      return await task
    } finally {
      if (LockScreenCustomAuthEnrollmentService.pendingEnrollment === task) {
        LockScreenCustomAuthEnrollmentService.pendingEnrollment = null
      }
    }
  }

  private async doEnsureFirstUKeyRegistered(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
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
      return LockScreenCustomAuthEnrollmentService.resolveExistingBinding(existing, candidates)
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
    LogUtils.info(TAG, `[REGISTER_SUCCESS] userId=${binding.userId}, deviceId=${binding.deviceId}`)
    return LockScreenCustomAuthEnrollmentService.success(binding, 'completed')
  }

  private static resolveExistingBinding(
    existing: LockScreenUKeyBinding,
    candidates: LockScreenUKeyDevice[]
  ): OperationResult<LockScreenUKeyBinding | null> {
    if (candidates.length === 1 && candidates[0].fingerprint === existing.fingerprint) {
      return LockScreenCustomAuthEnrollmentService.success(existing, 'bound_device_present')
    }
    if (candidates.length > 0) {
      return LockScreenCustomAuthEnrollmentService.success(existing, 'bound_other_device_present')
    }
    return LockScreenCustomAuthEnrollmentService.success(existing, 'already_bound')
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

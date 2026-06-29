/// <reference path="../../../mdmCustomCredential.d.ts" />

import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
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
const MDM_CUSTOM_CREDENTIAL_MODULE = 'mdm'

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
}

export class MdmCustomAuthCredentialManager implements CustomAuthCredentialManager {
  async addCredential(userId: number, pluginInfo: string): Promise<CustomAuthCredentialRegistrationResult> {
    let sessionOpened = false
    let mdm: MdmCustomCredentialModule | null = null
    try {
      mdm = MdmCustomAuthCredentialManager.loadMdmModule()
      if (!mdm) {
        return {
          success: false,
          errorCode: -1,
          errorMessage: 'mdm custom credential module unavailable'
        }
      }
      await mdm.openSession(userId)
      sessionOpened = true
      let result = await mdm.addUserCustomCredential({
        userId: userId,
        pluginInfo: pluginInfo
      })
      let credentialIdHex = MdmCustomAuthCredentialManager.toHex(result.credentialId)
      return {
        success: result.resultCode === 0 && credentialIdHex.length > 0,
        resultCode: result.resultCode,
        credentialIdHex: credentialIdHex
      }
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
      if (sessionOpened && mdm) {
        try {
          mdm.closeSession(userId)
        } catch (err) {
          LogUtils.warn(TAG, `[CLOSE_SESSION_FAIL] userId=${userId}, err=${JSON.stringify(err)}`)
        }
      }
    }
  }

  async deleteCredential(userId: number, credentialIdHex: string): Promise<CustomAuthCredentialDeletionResult> {
    let sessionOpened = false
    let mdm: MdmCustomCredentialModule | null = null
    try {
      mdm = MdmCustomAuthCredentialManager.loadMdmModule()
      if (!mdm) {
        return {
          success: false,
          errorCode: -1,
          errorMessage: 'mdm custom credential module unavailable'
        }
      }
      let credentialId = MdmCustomAuthCredentialManager.hexToBytes(credentialIdHex)
      if (credentialId.length === 0) {
        return {
          success: false,
          errorCode: -1,
          errorMessage: 'invalid credentialId'
        }
      }
      await mdm.openSession(userId)
      sessionOpened = true
      await mdm.deleteUserCustomCredential({
        credentialId: credentialId
      })
      return {
        success: true,
        resultCode: 0,
        credentialIdHex: credentialIdHex
      }
    } catch (err) {
      let error = err as Error
      let errorCode = typeof (err as BusinessError)?.code === 'number' ? (err as BusinessError).code : -1
      let errorMessage = typeof error?.message === 'string' && error.message.length > 0 ? error.message : 'unknown'
      LogUtils.error(TAG, `[DELETE_FAIL] deleteCredential | code=${errorCode}, message=${errorMessage}`)
      return {
        success: false,
        errorCode: errorCode,
        errorMessage: errorMessage
      }
    } finally {
      if (sessionOpened && mdm) {
        try {
          mdm.closeSession(userId)
        } catch (err) {
          LogUtils.warn(TAG, `[CLOSE_SESSION_FAIL] userId=${userId}, err=${JSON.stringify(err)}`)
        }
      }
    }
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

  private static loadMdmModule(): MdmCustomCredentialModule | null {
    try {
      return loadNativeModule(MDM_CUSTOM_CREDENTIAL_MODULE) as MdmCustomCredentialModule
    } catch (err) {
      LogUtils.error(TAG, `[LOAD_MDM_FAIL] module=${MDM_CUSTOM_CREDENTIAL_MODULE}, err=${JSON.stringify(err)}`)
      return null
    }
  }
}

export class LockScreenCustomAuthEnrollmentService implements LockScreenUKeyEnrollmentService {
  private static pendingEnrollment: Promise<OperationResult<LockScreenUKeyBinding | null>> | null = null
  private readonly bindingRepository: LockScreenUKeyBindingRepository
  private readonly activeCredentialRepository: LockScreenUKeyActiveCredentialRepository
  private readonly deviceProvider: LockScreenUKeyDeviceProvider
  private readonly registrar: CustomAuthCredentialManager

  constructor(
    bindingRepository: LockScreenUKeyBindingRepository = new PreferencesLockScreenUKeyBindingRepository(),
    deviceProvider: LockScreenUKeyDeviceProvider = new DdkLockScreenUKeyDeviceService(),
    registrar: CustomAuthCredentialManager = new MdmCustomAuthCredentialManager(),
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
    if (LockScreenCustomAuthEnrollmentService.pendingEnrollment) {
      return await LockScreenCustomAuthEnrollmentService.pendingEnrollment
    }
    let task = this.doHandleUKeyAttached(context)
    LockScreenCustomAuthEnrollmentService.pendingEnrollment = task
    try {
      return await task
    } finally {
      if (LockScreenCustomAuthEnrollmentService.pendingEnrollment === task) {
        LockScreenCustomAuthEnrollmentService.pendingEnrollment = null
      }
    }
  }

  async onUKeyDetached(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
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
      return LockScreenCustomAuthEnrollmentService.failure('clear_active_credential', 'UKey 活动凭据状态清理失败')
    }
    LogUtils.info(TAG, `[DELETE_SUCCESS] userId=${active.userId}, deviceId=${active.deviceId}`)
    return LockScreenCustomAuthEnrollmentService.success(existing, 'credential_deleted')
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
      return LockScreenCustomAuthEnrollmentService.failure('save_active_credential', 'UKey 活动凭据状态保存失败')
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

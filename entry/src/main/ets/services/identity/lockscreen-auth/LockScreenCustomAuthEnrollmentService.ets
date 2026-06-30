import { common } from '@kit.AbilityKit'
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

export class PendingOsAccountCustomAuthCredentialManager implements CustomAuthCredentialManager {
  async addCredential(userId: number, pluginInfo: string): Promise<CustomAuthCredentialRegistrationResult> {
    LogUtils.warn(TAG, `[REGISTER_SKIPPED] osAccount PIN token credential path pending | userId=${userId}, pluginInfo=${pluginInfo}`)
    return {
      success: false,
      errorCode: -1,
      errorMessage: 'osAccount custom credential path requires PIN token and is not connected'
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
    LogUtils.warn(TAG, `[DELETE_SKIPPED] osAccount PIN token credential path pending | userId=${userId}, credentialId=${credentialIdHex}`)
    return {
      success: false,
      errorCode: -1,
      errorMessage: 'osAccount custom credential path requires PIN token and is not connected',
      credentialIdHex: credentialIdHex
    }
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
    registrar: CustomAuthCredentialManager = new PendingOsAccountCustomAuthCredentialManager(),
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
      return LockScreenCustomAuthEnrollmentService.failure('clear_active_credential', 'UKey 活动凭据状态清理失败')
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

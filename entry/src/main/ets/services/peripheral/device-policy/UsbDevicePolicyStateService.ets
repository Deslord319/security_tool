import {
  PeripheralDevicePolicy,
  PeripheralType,
  UsbDeviceIdentity,
  UsbDevicePolicyStateRecord,
  inferPeripheralTypeFromBaseClass
} from '../../../models/PeripheralModels'
import { LogUtils } from '../../../utils/LogUtils'
import { PeripheralDevicePolicyRepository } from './PeripheralDevicePolicyRepository'
import {
  PeripheralDevicePolicyDispatchService,
  PeripheralPolicyDispatchResult
} from './PeripheralDevicePolicyDispatchService'
import { UsbDevicePolicyStateRepository } from './UsbDevicePolicyStateRepository'
import { PeripheralReasonCodes } from '../../../constants/modules/PeripheralStrings'

const TAG = 'UsbDevicePolicyStateService'

export interface UsbPolicyStateProcessResult {
  state?: UsbDevicePolicyStateRecord
  dispatchResult?: PeripheralPolicyDispatchResult
  desiredPolicy: PeripheralDevicePolicy
  activePolicy: 'none' | 'deny'
  autoDenyApplied: boolean
  internalAllowRestored: boolean
}

export class UsbDevicePolicyStateService {
  static async handleConnect(
    identity: UsbDeviceIdentity,
    occurAt: number,
    skipDeviceDenyDispatch: boolean
  ): Promise<UsbPolicyStateProcessResult> {
    const existing = await UsbDevicePolicyStateRepository.get(identity.fingerprintKey)
    const existingState = existing === null ? undefined : existing
    const desiredPolicy = existing?.desiredPolicy ??
      (PeripheralDevicePolicyRepository.isUsbDefaultDeny() ? 'deny' : 'allow')
    let nextState = UsbDevicePolicyStateService.buildState(
      identity,
      existingState,
      desiredPolicy,
      true,
      existing?.activePolicy ?? 'none',
      occurAt
    )
    let dispatchResult: PeripheralPolicyDispatchResult | undefined = undefined
    let autoDenyApplied = false

    if (desiredPolicy === 'deny' && !skipDeviceDenyDispatch) {
      dispatchResult = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: identity.fingerprintKey,
        deviceType: UsbDevicePolicyStateService.resolveDeviceType(identity.baseClass),
        policy: 'deny'
      })
      if (dispatchResult.success) {
        nextState.activePolicy = 'deny'
        nextState.updatedAt = Date.now()
        autoDenyApplied = true
      }
    } else if (desiredPolicy === 'allow') {
      nextState.activePolicy = 'none'
    }

    const shouldSave = desiredPolicy === 'allow' || existing !== null || dispatchResult?.success === true
    const saved = shouldSave ? await UsbDevicePolicyStateRepository.upsert(nextState) : false
    if (shouldSave && !saved) {
      LogUtils.error(TAG, `handleConnect state save failed: key=${identity.fingerprintKey}`)
    }

    return {
      state: saved ? nextState : existing ?? undefined,
      dispatchResult: dispatchResult,
      desiredPolicy: desiredPolicy,
      activePolicy: nextState.activePolicy,
      autoDenyApplied: autoDenyApplied,
      internalAllowRestored: false
    }
  }

  static async handleDisconnect(
    identity: UsbDeviceIdentity,
    occurAt: number
  ): Promise<UsbPolicyStateProcessResult> {
    const existing = await UsbDevicePolicyStateRepository.get(identity.fingerprintKey)
    if (!existing) {
      return {
        desiredPolicy: 'allow',
        activePolicy: 'none',
        autoDenyApplied: false,
        internalAllowRestored: false
      }
    }

    let nextState = UsbDevicePolicyStateService.buildState(
      identity,
      existing,
      existing.desiredPolicy,
      false,
      existing.activePolicy,
      occurAt
    )
    let dispatchResult: PeripheralPolicyDispatchResult | undefined = undefined
    let restored = false

    if (existing.activePolicy === 'deny') {
      const hasOtherActiveDeny = await UsbDevicePolicyStateRepository.hasOtherActiveDeny(
        existing.baseClass,
        existing.fingerprintKey
      )
      if (!hasOtherActiveDeny) {
        dispatchResult = await PeripheralDevicePolicyDispatchService.dispatch({
          deviceId: existing.fingerprintKey,
          deviceType: UsbDevicePolicyStateService.resolveDeviceType(existing.baseClass),
          policy: 'allow'
        })
        if (dispatchResult.success) {
          nextState.activePolicy = 'none'
          nextState.updatedAt = Date.now()
          restored = true
        }
      } else {
        nextState.activePolicy = 'none'
        nextState.updatedAt = Date.now()
      }
    }

    const saved = await UsbDevicePolicyStateRepository.upsert(nextState)
    if (!saved) {
      LogUtils.error(TAG, `handleDisconnect state save failed: key=${identity.fingerprintKey}`)
    }

    return {
      state: saved ? nextState : existing,
      dispatchResult: dispatchResult,
      desiredPolicy: existing.desiredPolicy,
      activePolicy: nextState.activePolicy,
      autoDenyApplied: false,
      internalAllowRestored: restored
    }
  }

  static async setPolicy(
    fingerprintKey: string,
    policy: PeripheralDevicePolicy
  ): Promise<PeripheralPolicyDispatchResult> {
    const existing = await UsbDevicePolicyStateRepository.get(fingerprintKey)
    if (!existing) {
      return UsbDevicePolicyStateService.buildFailureResult(
        PeripheralReasonCodes.USB_DISPATCH_FAILED as 'usb_dispatch_failed',
        'device_state_not_found'
      )
    }
    if (!existing.present) {
      return UsbDevicePolicyStateService.buildFailureResult('device_offline', 'device_offline')
    }

    const dispatchResult = await PeripheralDevicePolicyDispatchService.dispatch({
      deviceId: existing.fingerprintKey,
      deviceType: UsbDevicePolicyStateService.resolveDeviceType(existing.baseClass),
      policy: policy
    })
    if (!dispatchResult.success) {
      return dispatchResult
    }

    const nextState: UsbDevicePolicyStateRecord = UsbDevicePolicyStateService.copyStateWithPolicy(existing, policy)
    const saved = await UsbDevicePolicyStateRepository.upsert(nextState)
    return saved ? dispatchResult : UsbDevicePolicyStateService.buildFailureResult(
      PeripheralReasonCodes.USB_DISPATCH_FAILED as 'usb_dispatch_failed',
      'state_save_failed'
    )
  }

  static async suspendActivePolicies(): Promise<boolean> {
    const records = await UsbDevicePolicyStateRepository.listAll()
    const suspended: UsbDevicePolicyStateRecord[] = []
    for (const record of records) {
      if (record.activePolicy !== 'deny') {
        continue
      }
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: record.fingerprintKey,
        deviceType: UsbDevicePolicyStateService.resolveDeviceType(record.baseClass),
        policy: 'allow'
      })
      if (!result.success) {
        await UsbDevicePolicyStateService.compensateSuspendedPolicies(suspended)
        return false
      }
      const saved = await UsbDevicePolicyStateRepository.upsert(
        UsbDevicePolicyStateService.copyStateWithPolicy(record, record.desiredPolicy, 'none')
      )
      if (!saved) {
        suspended.push(record)
        await UsbDevicePolicyStateService.compensateSuspendedPolicies(suspended)
        return false
      }
      suspended.push(record)
    }
    return true
  }

  static async restorePresentDeniedPolicies(): Promise<boolean> {
    const records = await UsbDevicePolicyStateRepository.listAll()
    let success = true
    for (const record of records) {
      if (!record.present || record.desiredPolicy !== 'deny') {
        continue
      }
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: record.fingerprintKey,
        deviceType: UsbDevicePolicyStateService.resolveDeviceType(record.baseClass),
        policy: 'deny'
      })
      if (!result.success) {
        success = false
        continue
      }
      const saved = await UsbDevicePolicyStateRepository.upsert(
        UsbDevicePolicyStateService.copyStateWithPolicy(record, 'deny', 'deny')
      )
      if (!saved) {
        LogUtils.error(TAG, `restore present deny state save failed: key=${record.fingerprintKey}`)
        success = false
      }
    }
    return success
  }

  private static async compensateSuspendedPolicies(records: UsbDevicePolicyStateRecord[]): Promise<void> {
    for (const record of records) {
      const result = await PeripheralDevicePolicyDispatchService.dispatch({
        deviceId: record.fingerprintKey,
        deviceType: UsbDevicePolicyStateService.resolveDeviceType(record.baseClass),
        policy: 'deny'
      })
      if (!result.success) {
        LogUtils.error(TAG, `suspend compensation failed: key=${record.fingerprintKey}`)
        continue
      }
      const saved = await UsbDevicePolicyStateRepository.upsert(
        UsbDevicePolicyStateService.copyStateWithPolicy(record, record.desiredPolicy, 'deny')
      )
      if (!saved) {
        LogUtils.error(TAG, `suspend compensation state save failed: key=${record.fingerprintKey}`)
      }
    }
  }

  static async clearAllPolicies(): Promise<boolean> {
    const records = await UsbDevicePolicyStateRepository.listAll()
    const restoredRecords: UsbDevicePolicyStateRecord[] = []
    for (const record of records) {
      if (record.activePolicy === 'deny') {
        const dispatchResult = await PeripheralDevicePolicyDispatchService.dispatch({
          deviceId: record.fingerprintKey,
          deviceType: UsbDevicePolicyStateService.resolveDeviceType(record.baseClass),
          policy: 'allow'
        })
        if (!dispatchResult.success) {
          LogUtils.error(TAG, `clearAllPolicies dispatch failed: key=${record.fingerprintKey}, reason=${dispatchResult.reason ?? 'unknown'}`)
          return false
        }
      }
      restoredRecords.push(UsbDevicePolicyStateService.copyStateWithPolicy(record, 'allow', 'none'))
    }
    const saved = await UsbDevicePolicyStateRepository.upsertAll(restoredRecords)
    if (!saved) {
      LogUtils.error(TAG, 'clearAllPolicies state save failed')
    }
    return saved
  }

  static resolveDeviceType(baseClass: number): PeripheralType {
    return Number.isFinite(baseClass)
      ? inferPeripheralTypeFromBaseClass(baseClass)
      : PeripheralType.USB_OTHER
  }

  private static buildState(
    identity: UsbDeviceIdentity,
    existing: UsbDevicePolicyStateRecord | undefined,
    desiredPolicy: PeripheralDevicePolicy,
    present: boolean,
    activePolicy: 'none' | 'deny',
    occurAt: number
  ): UsbDevicePolicyStateRecord {
    const now = Date.now()
    return {
      fingerprintKey: identity.fingerprintKey,
      fingerprintType: identity.fingerprintType,
      serialNumber: identity.serialNumber,
      vendorId: identity.vendorId,
      productId: identity.productId,
      description: identity.description,
      baseClass: identity.baseClass,
      deviceName: identity.deviceName || existing?.deviceName || identity.fingerprintKey,
      desiredPolicy: desiredPolicy,
      present: present,
      activePolicy: activePolicy,
      lastSeenAt: present
        ? (Number.isFinite(occurAt) && occurAt > 0 ? Math.floor(occurAt) : now)
        : existing?.lastSeenAt ?? (Number.isFinite(occurAt) && occurAt > 0 ? Math.floor(occurAt) : now),
      updatedAt: now
    }
  }

  private static copyStateWithPolicy(
    existing: UsbDevicePolicyStateRecord,
    policy: PeripheralDevicePolicy,
    activePolicy?: 'none' | 'deny'
  ): UsbDevicePolicyStateRecord {
    return {
      fingerprintKey: existing.fingerprintKey,
      fingerprintType: existing.fingerprintType,
      serialNumber: existing.serialNumber,
      vendorId: existing.vendorId,
      productId: existing.productId,
      description: existing.description,
      baseClass: existing.baseClass,
      deviceName: existing.deviceName,
      desiredPolicy: policy,
      present: existing.present,
      activePolicy: activePolicy ?? (policy === 'deny' ? 'deny' : 'none'),
      lastSeenAt: existing.lastSeenAt,
      updatedAt: Date.now()
    }
  }

  private static buildFailureResult(
    reason: 'usb_dispatch_failed' | 'device_offline',
    message: string
  ): PeripheralPolicyDispatchResult {
    return {
      success: false,
      reason: reason,
      errorMessage: message,
      stage: 'device_policy_dispatch'
    } as PeripheralPolicyDispatchResult
  }
}

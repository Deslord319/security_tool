import { common } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import {
  LockScreenAuthRepository,
  PreferencesLockScreenAuthRepository
} from '../services/identity/lockscreen-auth/LockScreenAuthRepository'
import { OperationResult } from '../models/CommonModels'
import { LockScreenUKeyBinding } from '../models/identity/lockscreen-auth/LockScreenAuthModels'
import {
  LockScreenCustomAuthEnrollmentService,
  LockScreenUKeyEnrollmentService
} from '../services/identity/lockscreen-auth/LockScreenCustomAuthEnrollmentService'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'UKeyRuntime'
const USB_ATTACH_RECONCILE_DELAY_MS = 1000
const USB_DETACH_RECONCILE_DELAY_MS = 600

export class UKeyRuntimeManager {
  private static instance?: UKeyRuntimeManager
  private context: common.Context | null = null
  private usbSubscriber: commonEventManager.CommonEventSubscriber | null = null
  private operationInFlight: boolean = false
  private readonly repository: LockScreenAuthRepository
  private readonly enrollmentService: LockScreenUKeyEnrollmentService

  private constructor(
    repository: LockScreenAuthRepository = new PreferencesLockScreenAuthRepository(),
    enrollmentService: LockScreenUKeyEnrollmentService = new LockScreenCustomAuthEnrollmentService()
  ) {
    this.repository = repository
    this.enrollmentService = enrollmentService
  }

  static getInstance(): UKeyRuntimeManager {
    if (!UKeyRuntimeManager.instance) {
      UKeyRuntimeManager.instance = new UKeyRuntimeManager()
    }
    return UKeyRuntimeManager.instance
  }

  bindContext(context: common.Context): void {
    this.context = context
  }

  async start(): Promise<void> {
    if (!this.context) {
      LogUtils.warn(TAG, '[START_SKIP] reason=context_missing')
      return
    }
    await this.registerUsbRuntimeEvents()
    await this.reconcileOnStartup()
  }

  stop(): void {
    let subscriber = this.usbSubscriber
    this.usbSubscriber = null
    if (!subscriber) {
      return
    }
    commonEventManager.unsubscribe(subscriber, (err?: BusinessError) => {
      if (err) {
        LogUtils.warn(TAG, `[USB_UNSUBSCRIBE_FAIL] code=${err.code}, message=${err.message}`)
      }
    })
  }

  async reconcileOnStartup(): Promise<void> {
    await this.runEnrollmentOperation('startup_reconcile', async (context: common.Context) => {
      return await this.enrollmentService.reconcileOnStartup(context)
    })
  }

  private async registerUsbRuntimeEvents(): Promise<boolean> {
    if (this.usbSubscriber) {
      return true
    }
    return await new Promise<boolean>((resolve: (value: boolean) => void): void => {
      try {
        let subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
          events: [
            commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
            commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED
          ]
        }
        commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
          if (err) {
            LogUtils.error(TAG, `[USB_SUBSCRIBER_CREATE_FAIL] code=${err.code}, message=${err.message}`)
            resolve(false)
            return
          }
          commonEventManager.subscribe(subscriber, (callbackErr: BusinessError, data: commonEventManager.CommonEventData) => {
            if (callbackErr) {
              LogUtils.error(TAG, `[USB_EVENT_CALLBACK_FAIL] code=${callbackErr.code}, message=${callbackErr.message}`)
              return
            }
            this.handleUsbRuntimeEvent(data).catch((eventErr: Error) => {
              LogUtils.warn(TAG, `[USB_EVENT_HANDLE_FAIL] err=${JSON.stringify(eventErr)}`)
            })
          })
          this.usbSubscriber = subscriber
          LogUtils.info(TAG, '[USB_SUBSCRIBER_READY]')
          resolve(true)
        })
      } catch (err) {
        let error = err as BusinessError
        LogUtils.error(TAG, `[USB_SUBSCRIBE_FAIL] code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`)
        resolve(false)
      }
    })
  }

  private async handleUsbRuntimeEvent(data: commonEventManager.CommonEventData): Promise<void> {
    let eventName = data.event ?? ''
    if (eventName === commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED) {
      await UKeyRuntimeManager.sleep(USB_ATTACH_RECONCILE_DELAY_MS)
      await this.runEnrollmentOperation('usb_attached', async (context: common.Context) => {
        return await this.enrollmentService.onUKeyAttached(context)
      })
      return
    }
    if (eventName === commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED) {
      await UKeyRuntimeManager.sleep(USB_DETACH_RECONCILE_DELAY_MS)
      await this.runEnrollmentOperation('usb_detached', async (context: common.Context) => {
        return await this.enrollmentService.onUKeyDetached(context)
      })
      return
    }
    LogUtils.info(TAG, `[USB_EVENT_SKIP] event=${eventName}`)
  }

  private static async sleep(delayMs: number): Promise<void> {
    await new Promise<void>((resolve: () => void): void => {
      setTimeout(() => {
        resolve()
      }, delayMs)
    })
  }

  private async runEnrollmentOperation(
    trigger: string,
    operation: (context: common.Context) => Promise<OperationResult<LockScreenUKeyBinding | null>>
  ): Promise<void> {
    if (!this.context) {
      LogUtils.warn(TAG, `[ENROLLMENT_SKIP] trigger=${trigger}, reason=context_missing`)
      return
    }
    if (this.operationInFlight) {
      LogUtils.info(TAG, `[ENROLLMENT_SKIP] trigger=${trigger}, reason=in_flight`)
      return
    }

    this.operationInFlight = true
    try {
      let config = await this.repository.loadConfig(this.context)
      if (!config.ukeyUnlockEnabled) {
        LogUtils.info(TAG, `[ENROLLMENT_SKIP] trigger=${trigger}, reason=disabled`)
        return
      }
      let result = await operation(this.context)
      if (result.success) {
        LogUtils.info(TAG, `[ENROLLMENT_DONE] trigger=${trigger}, stage=${result.stage ?? 'unknown'}, binding=${!!result.data}`)
      } else {
        LogUtils.warn(TAG, `[ENROLLMENT_FAIL] trigger=${trigger}, stage=${result.stage ?? 'unknown'}, message=${result.errorMessage ?? '-'}`)
      }
    } finally {
      this.operationInFlight = false
    }
  }
}

import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { access } from '@kit.ConnectivityKit'
import { LogUtils } from '../../../utils/LogUtils'
import { CommonSystemErrorCodes } from '../../../constants/SystemErrorCodes'
import {
  PeripheralConnectionRecordProducer,
  PeripheralConnectionRecordProducerEvent,
  PeripheralConnectionRecordProducerListener,
  PeripheralConnectionRecordProducerStatus
} from './PeripheralConnectionRecordProducerContract'

const TAG = 'ConnectionRecordProducer'
const BLUETOOTH_RUNTIME_PERMISSION: Permissions = 'ohos.permission.ACCESS_BLUETOOTH'
const BLUETOOTH_ACL_EVENT = commonEventManager.Support.COMMON_EVENT_BLUETOOTH_REMOTEDEVICE_ACL_STATE_CHANGE

export class PeripheralConnectionRecordRuntimeProducerAdapter implements PeripheralConnectionRecordProducer {
  private nextListenerId: number = 1
  private listeners: Map<number, PeripheralConnectionRecordProducerListener> = new Map()
  private context: common.UIAbilityContext | null = null
  private usbSubscriber: commonEventManager.CommonEventSubscriber | null = null
  private bluetoothAclSubscriber: commonEventManager.CommonEventSubscriber | null = null
  private bluetoothStateListener: ((state: access.BluetoothState) => void) | undefined
  private bluetoothCurrentState: access.BluetoothState = access.BluetoothState.STATE_OFF
  private bluetoothPermissionBlocked: boolean = false
  private bluetoothPermissionPrompted: boolean = false
  private bluetoothPermissionRequestInFlight: boolean = false
  private status: PeripheralConnectionRecordProducerStatus = {
    running: false,
    capabilities: {
      usbRuntimeEvents: false,
      bluetoothRuntimeEvents: false,
      degradedReason: 'not_started'
    }
  }

  bindContext(context: common.UIAbilityContext): void {
    this.context = context
  }

  async start(): Promise<boolean> {
    if (this.status.running) {
      return true
    }
    if (!this.context) {
      this.status = {
        running: false,
        capabilities: {
          usbRuntimeEvents: false,
          bluetoothRuntimeEvents: false,
          degradedReason: 'not_initialized'
        }
      }
      return false
    }

    this.stop()
    const usbReady = await this.registerUsbRuntimeEvents()
    const bluetoothReady = await this.registerBluetoothRuntimeEvents()
    this.status = {
      running: usbReady || bluetoothReady,
      capabilities: {
        usbRuntimeEvents: usbReady,
        bluetoothRuntimeEvents: bluetoothReady,
        degradedReason: this.buildDegradedReason(usbReady, bluetoothReady)
      }
    }
    LogUtils.info(
      TAG,
      `start complete, running=${this.status.running}, usb=${usbReady}, bluetooth=${bluetoothReady}, degradedReason=${this.status.capabilities.degradedReason ?? 'none'}`
    )
    return this.status.running
  }

  stop(): void {
    const usbSubscriber = this.usbSubscriber
    this.usbSubscriber = null
    if (usbSubscriber) {
      commonEventManager.unsubscribe(usbSubscriber, (err?: BusinessError) => {
        if (err) {
          LogUtils.warn(TAG, `usb unsubscribe failed: code=${err.code}, message=${err.message}`)
        }
      })
    }
    this.cleanupBluetoothRuntimeEvents()
    this.status = {
      running: false,
      capabilities: {
        usbRuntimeEvents: false,
        bluetoothRuntimeEvents: false,
        degradedReason: this.context ? 'not_started' : 'not_initialized'
      }
    }
  }

  subscribe(listener: PeripheralConnectionRecordProducerListener): number {
    const listenerId = this.nextListenerId++
    this.listeners.set(listenerId, listener)
    return listenerId
  }

  unsubscribe(listenerId: number): void {
    this.listeners.delete(listenerId)
  }

  getStatus(): PeripheralConnectionRecordProducerStatus {
    return this.status
  }

  private async registerUsbRuntimeEvents(): Promise<boolean> {
    return await new Promise<boolean>((resolve) => {
      try {
        const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
          events: [
            commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED,
            commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED
          ]
        }
        commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
          if (err) {
            LogUtils.error(TAG, `create usb subscriber failed: code=${err.code}, message=${err.message}`)
            resolve(false)
            return
          }
          commonEventManager.subscribe(subscriber, (callbackErr: BusinessError, data: commonEventManager.CommonEventData) => {
            if (callbackErr) {
              LogUtils.error(TAG, `usb callback failed: code=${callbackErr.code}, message=${callbackErr.message}`)
              return
            }
            this.emitRuntimeEvent(this.buildProducerEvent('usb', data))
          })
          this.usbSubscriber = subscriber
          resolve(true)
        })
      } catch (err) {
        const error = err as BusinessError
        LogUtils.error(
          TAG,
          `registerUsbRuntimeEvents failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
        )
        resolve(false)
      }
    })
  }

  private async registerBluetoothRuntimeEvents(): Promise<boolean> {
    try {
      this.bluetoothStateListener = (state: access.BluetoothState): void => {
        this.handleBluetoothStateChange(state)
          .then((ready: boolean) => {
            this.updateBluetoothRuntimeCapability(ready)
          })
          .catch((err: BusinessError) => {
            LogUtils.warn(
              TAG,
              `bluetooth state handler failed: code=${err.code ?? -1}, message=${err.message ?? JSON.stringify(err)}`
            )
            this.updateBluetoothRuntimeCapability(false)
          })
      }
      access.on('stateChange', this.bluetoothStateListener)

      const currentState = access.getState()
      LogUtils.info(TAG, `bluetooth state queried: state=${this.getBluetoothStateLabel(currentState)}`)
      return await this.handleBluetoothStateChange(currentState)
    } catch (err) {
      const error = err as BusinessError
      LogUtils.error(
        TAG,
        `registerBluetoothRuntimeEvents failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      this.cleanupBluetoothRuntimeEvents()
      return false
    }
  }

  private cleanupBluetoothRuntimeEvents(): void {
    this.cleanupBluetoothAclSubscriber('producer-stop')
    if (this.bluetoothStateListener) {
      try {
        access.off('stateChange', this.bluetoothStateListener)
      } catch (_err) {
      }
    }
    this.bluetoothStateListener = undefined
    this.bluetoothCurrentState = access.BluetoothState.STATE_OFF
  }

  private async handleBluetoothStateChange(state: access.BluetoothState): Promise<boolean> {
    this.bluetoothCurrentState = state
    const stateLabel = this.getBluetoothStateLabel(state)
    LogUtils.info(TAG, `bluetooth state change: state=${stateLabel}`)
    if (state === access.BluetoothState.STATE_ON || state === access.BluetoothState.STATE_BLE_ON) {
      return await this.resumeBluetoothAclSubscriptionIfNeeded(`state=${stateLabel}`)
    }
    LogUtils.info(TAG, `keep bluetooth acl subscriber while bluetooth is inactive: state=${stateLabel}`)
    return !this.bluetoothPermissionBlocked
  }

  private async resumeBluetoothAclSubscriptionIfNeeded(trigger: string): Promise<boolean> {
    if (!this.isBluetoothRuntimeActive()) {
      LogUtils.info(
        TAG,
        `skip resumeBluetoothAclSubscriptionIfNeeded: trigger=${trigger}, state=${this.getBluetoothStateLabel(this.bluetoothCurrentState)}`
      )
      return !this.bluetoothPermissionBlocked
    }
    if (this.bluetoothAclSubscriber) {
      return true
    }
    const permissionGranted = await this.ensureBluetoothRuntimePermission(trigger)
    if (!permissionGranted) {
      return false
    }
    return await this.subscribeBluetoothAclStateChange(trigger)
  }

  private async subscribeBluetoothAclStateChange(trigger: string): Promise<boolean> {
    if (this.bluetoothAclSubscriber) {
      return true
    }
    return await new Promise<boolean>((resolve) => {
      try {
        const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
          events: [BLUETOOTH_ACL_EVENT]
        }
        commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
          if (err) {
            if (this.isBluetoothPermissionDeniedError(err)) {
              this.enterBluetoothPermissionBlocked(`acl-subscriber-create-denied:${trigger}`)
            }
            LogUtils.warn(
              TAG,
              `bluetooth acl createSubscriber failed: trigger=${trigger}, code=${err.code}, message=${err.message}`
            )
            resolve(false)
            return
          }
          commonEventManager.subscribe(subscriber, (callbackErr: BusinessError, data: commonEventManager.CommonEventData) => {
            if (callbackErr) {
              LogUtils.warn(
                TAG,
                `bluetooth acl callback failed: code=${callbackErr.code}, message=${callbackErr.message}`
              )
              return
            }
            this.emitRuntimeEvent(this.buildProducerEvent('bluetooth_acl', data))
          })
          this.bluetoothAclSubscriber = subscriber
          this.bluetoothPermissionBlocked = false
          LogUtils.info(TAG, `bluetooth acl subscriber ready: trigger=${trigger}`)
          resolve(true)
        })
      } catch (err) {
        const error = err as BusinessError
        if (this.isBluetoothPermissionDeniedError(error)) {
          this.enterBluetoothPermissionBlocked(`acl-subscriber-subscribe-denied:${trigger}`)
        }
        LogUtils.warn(
          TAG,
          `bluetooth acl subscribe failed: trigger=${trigger}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
        )
        resolve(false)
      }
    })
  }

  private cleanupBluetoothAclSubscriber(reason: string): void {
    const subscriber = this.bluetoothAclSubscriber
    this.bluetoothAclSubscriber = null
    if (!subscriber) {
      return
    }
    commonEventManager.unsubscribe(subscriber, (err?: BusinessError) => {
      if (err) {
        LogUtils.warn(
          TAG,
          `bluetooth acl unsubscribe failed: reason=${reason}, code=${err.code}, message=${err.message}`
        )
        return
      }
      LogUtils.info(TAG, `bluetooth acl subscriber cleaned: reason=${reason}`)
    })
  }

  private isBluetoothRuntimeActive(): boolean {
    return this.bluetoothCurrentState === access.BluetoothState.STATE_ON ||
      this.bluetoothCurrentState === access.BluetoothState.STATE_BLE_ON
  }

  private getSelfAccessTokenId(): number {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      )
      return bundleInfo.appInfo.accessTokenId
    } catch (err) {
      const error = err as BusinessError
      LogUtils.warn(TAG, `getSelfAccessTokenId failed: code=${error?.code ?? 'unknown'}, message=${error?.message ?? 'unknown'}`)
      return 0
    }
  }

  private hasBluetoothRuntimePermission(): boolean {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const grantStatus = atManager.checkAccessTokenSync(
        this.getSelfAccessTokenId(),
        BLUETOOTH_RUNTIME_PERMISSION
      )
      return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    } catch (err) {
      const error = err as BusinessError
      LogUtils.warn(
        TAG,
        `checkAccessTokenSync failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      return false
    }
  }

  private async ensureBluetoothRuntimePermission(trigger: string): Promise<boolean> {
    const granted = this.hasBluetoothRuntimePermission()
    if (granted) {
      if (this.bluetoothPermissionBlocked) {
        LogUtils.info(TAG, `bluetooth permission recovered: trigger=${trigger}`)
      }
      this.bluetoothPermissionBlocked = false
      return true
    }

    if (this.bluetoothPermissionPrompted) {
      this.enterBluetoothPermissionBlocked(`permission-not-granted:${trigger}`)
      LogUtils.info(TAG, `skip bluetooth permission request: trigger=${trigger}, prompted=true`)
      return false
    }

    if (!this.context) {
      this.enterBluetoothPermissionBlocked(`permission-context-missing:${trigger}`)
      LogUtils.warn(TAG, `bluetooth permission request skipped: trigger=${trigger}, context unavailable`)
      return false
    }

    if (this.bluetoothPermissionRequestInFlight) {
      LogUtils.info(TAG, `bluetooth permission request already in flight: trigger=${trigger}`)
      return false
    }

    this.bluetoothPermissionRequestInFlight = true
    this.bluetoothPermissionPrompted = true
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const result = await atManager.requestPermissionsFromUser(this.context, [BLUETOOTH_RUNTIME_PERMISSION])
      const authResult = Array.isArray(result.authResults) && result.authResults.length > 0
        ? result.authResults[0]
        : abilityAccessCtrl.GrantStatus.PERMISSION_DENIED
      const requestGranted = authResult === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED ||
        this.hasBluetoothRuntimePermission()
      LogUtils.info(
        TAG,
        `bluetooth permission request result: trigger=${trigger}, granted=${requestGranted}, authResult=${authResult}`
      )
      if (requestGranted) {
        this.bluetoothPermissionBlocked = false
        return true
      }
      this.enterBluetoothPermissionBlocked(`permission-request-denied:${trigger}`)
      return false
    } catch (err) {
      const error = err as BusinessError
      this.enterBluetoothPermissionBlocked(`permission-request-error:${trigger}`)
      LogUtils.warn(
        TAG,
        `requestPermissionsFromUser failed: trigger=${trigger}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      return false
    } finally {
      this.bluetoothPermissionRequestInFlight = false
    }
  }

  private enterBluetoothPermissionBlocked(reason: string): void {
    this.bluetoothPermissionBlocked = true
    this.cleanupBluetoothAclSubscriber(reason)
    this.updateBluetoothRuntimeCapability(false)
    LogUtils.warn(TAG, `bluetooth runtime paused: reason=${reason}`)
  }

  private isBluetoothPermissionDeniedError(error: BusinessError): boolean {
    if (error.code === CommonSystemErrorCodes.PERMISSION_DENIED) {
      return true
    }
    const message = (error.message ?? '').toLowerCase()
    return message.includes('permission denied')
  }

  private getBluetoothStateLabel(state: access.BluetoothState): string {
    switch (state) {
      case access.BluetoothState.STATE_OFF:
        return 'STATE_OFF'
      case access.BluetoothState.STATE_TURNING_ON:
        return 'STATE_TURNING_ON'
      case access.BluetoothState.STATE_ON:
        return 'STATE_ON'
      case access.BluetoothState.STATE_TURNING_OFF:
        return 'STATE_TURNING_OFF'
      case access.BluetoothState.STATE_BLE_TURNING_ON:
        return 'STATE_BLE_TURNING_ON'
      case access.BluetoothState.STATE_BLE_ON:
        return 'STATE_BLE_ON'
      case access.BluetoothState.STATE_BLE_TURNING_OFF:
        return 'STATE_BLE_TURNING_OFF'
      default:
        return `${state}`
    }
  }

  private buildDegradedReason(usbReady: boolean, bluetoothReady: boolean): string | undefined {
    const reasons: string[] = []
    if (!usbReady) {
      reasons.push('usb_common_event_subscribe_failed')
    }
    if (!bluetoothReady) {
      reasons.push('bluetooth_acl_runtime_register_failed')
    }
    return reasons.length > 0 ? reasons.join('|') : undefined
  }

  private updateBluetoothRuntimeCapability(bluetoothReady: boolean): void {
    if (!this.context) {
      return
    }
    const usbReady = this.status.capabilities.usbRuntimeEvents
    this.status = {
      running: usbReady || bluetoothReady,
      capabilities: {
        usbRuntimeEvents: usbReady,
        bluetoothRuntimeEvents: bluetoothReady,
        degradedReason: this.buildDegradedReason(usbReady, bluetoothReady)
      }
    }
  }

  private buildProducerEvent(
    channel: 'usb' | 'bluetooth_acl',
    data: commonEventManager.CommonEventData
  ): PeripheralConnectionRecordProducerEvent {
    const event: PeripheralConnectionRecordProducerEvent = {
      source: 'runtime',
      channel: channel,
      eventName: data.event ?? '',
      rawData: data
    }
    const payload = data.parameters as Object | undefined
    if (payload !== undefined) {
      event.payload = payload
    }
    return event
  }

  private emitRuntimeEvent(event: PeripheralConnectionRecordProducerEvent): void {
    if (this.listeners.size <= 0) {
      return
    }
    this.listeners.forEach((listener: PeripheralConnectionRecordProducerListener) => {
      try {
        listener(event)
      } catch (_err) {
      }
    })
  }
}

import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { access } from '@kit.ConnectivityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  PeripheralConnectionRecordProducer,
  PeripheralConnectionRecordProducerEvent,
  PeripheralConnectionRecordProducerListener,
  PeripheralConnectionRecordProducerStatus
} from './peripheral_connection_record_producer_contract'

const DOMAIN = 0x000A
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
    hilog.info(
      DOMAIN,
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
          hilog.warn(DOMAIN, TAG, `usb unsubscribe failed: code=${err.code}, message=${err.message}`)
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
            hilog.error(DOMAIN, TAG, `create usb subscriber failed: code=${err.code}, message=${err.message}`)
            resolve(false)
            return
          }
          commonEventManager.subscribe(subscriber, (callbackErr: BusinessError, data: commonEventManager.CommonEventData) => {
            if (callbackErr) {
              hilog.error(DOMAIN, TAG, `usb callback failed: code=${callbackErr.code}, message=${callbackErr.message}`)
              return
            }
            this.emitRuntimeEvent(this.buildProducerEvent('usb', data))
          })
          this.usbSubscriber = subscriber
          resolve(true)
        })
      } catch (err) {
        const error = err as BusinessError
        hilog.error(
          DOMAIN,
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
        void this.handleBluetoothStateChange(state)
      }
      access.on('stateChange', this.bluetoothStateListener)

      const currentState = access.getState()
      hilog.info(DOMAIN, TAG, `bluetooth state queried: state=${this.getBluetoothStateLabel(currentState)}`)
      await this.handleBluetoothStateChange(currentState)
      return true
    } catch (err) {
      const error = err as BusinessError
      hilog.error(
        DOMAIN,
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

  private async handleBluetoothStateChange(state: access.BluetoothState): Promise<void> {
    this.bluetoothCurrentState = state
    const stateLabel = this.getBluetoothStateLabel(state)
    hilog.info(DOMAIN, TAG, `bluetooth state change: state=${stateLabel}`)
    if (state === access.BluetoothState.STATE_ON || state === access.BluetoothState.STATE_BLE_ON) {
      await this.resumeBluetoothAclSubscriptionIfNeeded(`state=${stateLabel}`)
      return
    }
    this.cleanupBluetoothAclSubscriber(`state=${stateLabel}`)
  }

  private async resumeBluetoothAclSubscriptionIfNeeded(trigger: string): Promise<void> {
    if (!this.isBluetoothRuntimeActive()) {
      hilog.info(
        DOMAIN,
        TAG,
        `skip resumeBluetoothAclSubscriptionIfNeeded: trigger=${trigger}, state=${this.getBluetoothStateLabel(this.bluetoothCurrentState)}`
      )
      return
    }
    if (this.bluetoothAclSubscriber) {
      return
    }
    const permissionGranted = await this.ensureBluetoothRuntimePermission(trigger)
    if (!permissionGranted) {
      return
    }
    await this.subscribeBluetoothAclStateChange(trigger)
  }

  private async subscribeBluetoothAclStateChange(trigger: string): Promise<void> {
    if (this.bluetoothAclSubscriber) {
      return
    }
    await new Promise<void>((resolve) => {
      try {
        const subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
          events: [BLUETOOTH_ACL_EVENT]
        }
        commonEventManager.createSubscriber(subscribeInfo, (err: BusinessError, subscriber) => {
          if (err) {
            if (this.isBluetoothPermissionDeniedError(err)) {
              this.enterBluetoothPermissionBlocked(`acl-subscriber-create-denied:${trigger}`)
            }
            hilog.warn(
              DOMAIN,
              TAG,
              `bluetooth acl createSubscriber failed: trigger=${trigger}, code=${err.code}, message=${err.message}`
            )
            resolve()
            return
          }
          commonEventManager.subscribe(subscriber, (callbackErr: BusinessError, data: commonEventManager.CommonEventData) => {
            if (callbackErr) {
              hilog.warn(
                DOMAIN,
                TAG,
                `bluetooth acl callback failed: code=${callbackErr.code}, message=${callbackErr.message}`
              )
              return
            }
            this.emitRuntimeEvent(this.buildProducerEvent('bluetooth_acl', data))
          })
          this.bluetoothAclSubscriber = subscriber
          this.bluetoothPermissionBlocked = false
          hilog.info(DOMAIN, TAG, `bluetooth acl subscriber ready: trigger=${trigger}`)
          resolve()
        })
      } catch (err) {
        const error = err as BusinessError
        if (this.isBluetoothPermissionDeniedError(error)) {
          this.enterBluetoothPermissionBlocked(`acl-subscriber-subscribe-denied:${trigger}`)
        }
        hilog.warn(
          DOMAIN,
          TAG,
          `bluetooth acl subscribe failed: trigger=${trigger}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
        )
        resolve()
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
        hilog.warn(
          DOMAIN,
          TAG,
          `bluetooth acl unsubscribe failed: reason=${reason}, code=${err.code}, message=${err.message}`
        )
        return
      }
      hilog.info(DOMAIN, TAG, `bluetooth acl subscriber cleaned: reason=${reason}`)
    })
  }

  private isBluetoothRuntimeActive(): boolean {
    return this.bluetoothCurrentState === access.BluetoothState.STATE_ON ||
      this.bluetoothCurrentState === access.BluetoothState.STATE_BLE_ON
  }

  private getSelfAccessTokenId(): number {
    const bundleInfo = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
    )
    return bundleInfo.appInfo.accessTokenId
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
      hilog.warn(
        DOMAIN,
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
        hilog.info(DOMAIN, TAG, `bluetooth permission recovered: trigger=${trigger}`)
      }
      this.bluetoothPermissionBlocked = false
      return true
    }

    if (this.bluetoothPermissionPrompted) {
      this.enterBluetoothPermissionBlocked(`permission-not-granted:${trigger}`)
      hilog.info(DOMAIN, TAG, `skip bluetooth permission request: trigger=${trigger}, prompted=true`)
      return false
    }

    if (!this.context) {
      this.enterBluetoothPermissionBlocked(`permission-context-missing:${trigger}`)
      hilog.warn(DOMAIN, TAG, `bluetooth permission request skipped: trigger=${trigger}, context unavailable`)
      return false
    }

    if (this.bluetoothPermissionRequestInFlight) {
      hilog.info(DOMAIN, TAG, `bluetooth permission request already in flight: trigger=${trigger}`)
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
      hilog.info(
        DOMAIN,
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
      hilog.warn(
        DOMAIN,
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
    hilog.warn(DOMAIN, TAG, `bluetooth runtime paused: reason=${reason}`)
  }

  private isBluetoothPermissionDeniedError(error: BusinessError): boolean {
    if (error.code === 201) {
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

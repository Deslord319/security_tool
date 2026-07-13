import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { connection } from '@kit.ConnectivityKit'
import { LogUtils } from '../../../utils/LogUtils'
import { CommonSystemErrorCodes } from '../../../constants/SystemErrorCodes'
import {
  PeripheralConnectionRecordProducer,
  PeripheralConnectionRecordProducerEvent,
  PeripheralConnectionRecordProducerListener,
  PeripheralConnectionRecordProducerStatus,
  PeripheralBluetoothAclAction
} from './PeripheralConnectionRecordProducerContract'

const TAG = 'ConnectionRecordProducer'
const BLUETOOTH_RUNTIME_PERMISSION: Permissions = 'ohos.permission.ACCESS_BLUETOOTH'
const BLUETOOTH_PEER_MAC_PERMISSION: Permissions = 'ohos.permission.GET_BLUETOOTH_PEERS_MAC'
const BLUETOOTH_ACL_EVENT_NAME = 'bluetooth_acl_state_change'
const BLUETOOTH_BOND_EVENT_NAME = 'bluetooth_bond_state_change'

export function mapBluetoothAclStateToAction(state: connection.AclState): PeripheralBluetoothAclAction | null {
  switch (state) {
    case connection.AclState.STATE_CONNECTED:
      return 'connect'
    case connection.AclState.STATE_DISCONNECTED:
      return 'disconnect'
    default:
      return null
  }
}

export class PeripheralConnectionRecordRuntimeProducerAdapter implements PeripheralConnectionRecordProducer {
  private nextListenerId: number = 1
  private listeners: Map<number, PeripheralConnectionRecordProducerListener> = new Map()
  private context: common.UIAbilityContext | null = null
  private usbSubscriber: commonEventManager.CommonEventSubscriber | null = null
  private bluetoothAclStateListener: ((result: connection.AclStateResult) => void) | undefined
  private bluetoothBondStateListener: ((result: connection.BondStateParam) => void) | undefined
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
            this.emitRuntimeEvent(this.buildUsbProducerEvent(data))
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
    const permissionGranted = await this.ensureBluetoothRuntimePermission('runtime-start')
    if (!permissionGranted) {
      return false
    }
    if (!this.hasPermission(BLUETOOTH_PEER_MAC_PERMISSION)) {
      this.enterBluetoothPermissionBlocked('peer-mac-permission-not-granted')
      LogUtils.error(TAG, 'registerBluetoothRuntimeEvents failed: GET_BLUETOOTH_PEERS_MAC not granted')
      return false
    }
    if (this.bluetoothAclStateListener && this.bluetoothBondStateListener) {
      return true
    }
    try {
      const listener = (result: connection.AclStateResult): void => {
        const action = mapBluetoothAclStateToAction(result.state)
        const deviceId = (result.deviceId ?? '').trim()
        if (action === null || deviceId.length === 0) {
          LogUtils.warn(TAG, `skip bluetooth acl callback: state=${result.state}, deviceIdPresent=${deviceId.length > 0}`)
          return
        }
        this.emitRuntimeEvent({
          source: 'runtime',
          channel: 'bluetooth_acl',
          eventName: BLUETOOTH_ACL_EVENT_NAME,
          bluetoothAcl: {
            deviceId: deviceId,
            action: action,
            occurAt: Date.now()
          }
        })
      }
      connection.onAclStateChange(listener)
      this.bluetoothAclStateListener = listener
      const bondListener = (result: connection.BondStateParam): void => {
        const deviceId = (result.deviceId ?? '').trim()
        if (deviceId.length === 0) {
          LogUtils.warn(TAG, `skip bluetooth bond callback: state=${result.state}, deviceIdPresent=false`)
          return
        }
        this.emitRuntimeEvent({
          source: 'runtime',
          channel: 'bluetooth_bond',
          eventName: BLUETOOTH_BOND_EVENT_NAME,
          bluetoothBond: {
            deviceId: deviceId,
            state: result.state,
            cause: result.cause,
            occurAt: Date.now()
          }
        })
      }
      connection.on('bondStateChange', bondListener)
      this.bluetoothBondStateListener = bondListener
      this.bluetoothPermissionBlocked = false
      LogUtils.info(TAG, 'bluetooth acl and bond state listeners ready')
      return true
    } catch (err) {
      const error = err as BusinessError
      if (this.isBluetoothPermissionDeniedError(error)) {
        this.enterBluetoothPermissionBlocked('acl-listener-register-denied')
      }
      LogUtils.error(
        TAG,
        `registerBluetoothRuntimeEvents failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
      )
      this.cleanupBluetoothRuntimeEvents()
      return false
    }
  }

  private cleanupBluetoothRuntimeEvents(): void {
    const listener = this.bluetoothAclStateListener
    const bondListener = this.bluetoothBondStateListener
    this.bluetoothAclStateListener = undefined
    this.bluetoothBondStateListener = undefined
    if (listener) {
      try {
        connection.offAclStateChange(listener)
        LogUtils.info(TAG, 'bluetooth acl state listener cleaned')
      } catch (err) {
        const error = err as BusinessError
        LogUtils.warn(
          TAG,
          `bluetooth acl listener cleanup failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
        )
      }
    }
    if (bondListener) {
      try {
        connection.off('bondStateChange', bondListener)
        LogUtils.info(TAG, 'bluetooth bond state listener cleaned')
      } catch (err) {
        const error = err as BusinessError
        LogUtils.warn(
          TAG,
          `bluetooth bond listener cleanup failed: code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
        )
      }
    }
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
    return this.hasPermission(BLUETOOTH_RUNTIME_PERMISSION)
  }

  private hasPermission(permission: Permissions): boolean {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const grantStatus = atManager.checkAccessTokenSync(
        this.getSelfAccessTokenId(),
        permission
      )
      return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
    } catch (err) {
      const error = err as BusinessError
      LogUtils.warn(
        TAG,
        `checkAccessTokenSync failed: permission=${permission}, code=${error.code ?? -1}, message=${error.message ?? JSON.stringify(err)}`
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
    this.cleanupBluetoothRuntimeEvents()
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

  private buildUsbProducerEvent(data: commonEventManager.CommonEventData): PeripheralConnectionRecordProducerEvent {
    const event: PeripheralConnectionRecordProducerEvent = {
      source: 'runtime',
      channel: 'usb',
      eventName: data.event ?? '',
      rawData: data
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

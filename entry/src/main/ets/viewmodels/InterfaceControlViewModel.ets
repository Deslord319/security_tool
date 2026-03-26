import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PeripheralService } from '../services/PeripheralService'
import {
  REASON_READ_USB_STATUS_FAILED,
  REASON_READ_USB_STORAGE_POLICY_FAILED,
  REASON_SET_USB_INTERFACE_CONFLICT,
  REASON_SET_USB_STORAGE_POLICY_CONFLICT,
  REASON_TOGGLE_INTERFACE_FAILED,
  REASON_USB_STORAGE_POLICY_FAILED
} from './PeripheralViewModelReasons'

const TAG = 'InterfaceControlViewModel'
const DOMAIN = 0x0013

export interface InterfaceControlState {
  usbDisabled: boolean
  btDisabled: boolean
  wifiDisabled: boolean
  hdcDisabled: boolean
  networkDisabled: boolean
  printerDisabled: boolean
  microphoneDisabled: boolean
  cameraDisabled: boolean
  usbStoragePolicyIndex: number
}

@Observed
export class InterfaceControlViewModel {
  state: InterfaceControlState = {
    usbDisabled: false,
    btDisabled: false,
    wifiDisabled: false,
    hdcDisabled: false,
    networkDisabled: false,
    printerDisabled: false,
    microphoneDisabled: false,
    cameraDisabled: false,
    usbStoragePolicyIndex: 1
  }

  processingKey: string = ''

  reloadState(): void {
    try {
      const usbState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_USB)
      const btState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_BLUETOOTH)
      const wifiState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_WIFI)
      const hdcState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_HDC)
      const networkState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_NETWORK)
      const printerState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_PRINTER)
      const microphoneState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_MICROPHONE)
      const cameraState = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_CAMERA)
      const storagePolicy = PeripheralService.getUsbStoragePolicyWithResult()

      this.state.usbDisabled = usbState.data ?? false
      this.state.btDisabled = btState.data ?? false
      this.state.wifiDisabled = wifiState.data ?? false
      this.state.hdcDisabled = hdcState.data ?? false
      this.state.networkDisabled = networkState.data ?? false
      this.state.printerDisabled = printerState.data ?? false
      this.state.microphoneDisabled = microphoneState.data ?? false
      this.state.cameraDisabled = cameraState.data ?? false
      this.state.usbStoragePolicyIndex = this.getUsbStoragePolicyIndex(
        storagePolicy.data ?? edmUsbManager.UsbPolicy.READ_WRITE
      )
    } catch (err) {
      hilog.error(DOMAIN, TAG, `reloadState failed: ${JSON.stringify(err)}`)
    }
  }

  async toggleInterface(feature: string, disallow: boolean): Promise<string | null> {
    this.processingKey = feature
    try {
      const result = PeripheralService.setInterfaceDisabledWithResult(feature, disallow)
      if (!result.success) {
        return this.normalizeReason(result.stage, REASON_TOGGLE_INTERFACE_FAILED)
      }
      this.reloadState()
      return null
    } catch (err) {
      hilog.error(DOMAIN, TAG, `toggleInterface failed: ${JSON.stringify(err)}`)
      return REASON_TOGGLE_INTERFACE_FAILED
    } finally {
      this.processingKey = ''
    }
  }

  async setUsbStoragePolicy(index: number): Promise<string | null> {
    this.processingKey = 'usb-storage-policy'
    try {
      const policy = index === 0
        ? edmUsbManager.UsbPolicy.READ_ONLY
        : index === 1
          ? edmUsbManager.UsbPolicy.READ_WRITE
          : edmUsbManager.UsbPolicy.DISABLED
      const result = PeripheralService.setUsbStoragePolicyWithCleanupResult(policy)
      if (!result.success) {
        return this.normalizeReason(result.stage, REASON_USB_STORAGE_POLICY_FAILED)
      }
      this.state.usbStoragePolicyIndex = index
      this.reloadState()
      return null
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return REASON_USB_STORAGE_POLICY_FAILED
    } finally {
      this.processingKey = ''
    }
  }

  private getUsbStoragePolicyIndex(policy: edmUsbManager.UsbPolicy): number {
    if (policy === edmUsbManager.UsbPolicy.READ_ONLY) {
      return 0
    }
    if (policy === edmUsbManager.UsbPolicy.READ_WRITE) {
      return 1
    }
    return 2
  }

  private normalizeReason(stage: string | undefined, fallbackReason: string): string {
    switch (stage) {
      case REASON_READ_USB_STATUS_FAILED:
        return REASON_READ_USB_STATUS_FAILED
      case REASON_READ_USB_STORAGE_POLICY_FAILED:
        return REASON_READ_USB_STORAGE_POLICY_FAILED
      case REASON_SET_USB_INTERFACE_CONFLICT:
        return REASON_SET_USB_INTERFACE_CONFLICT
      case REASON_SET_USB_STORAGE_POLICY_CONFLICT:
        return REASON_SET_USB_STORAGE_POLICY_CONFLICT
      default:
        return stage || fallbackReason
    }
  }
}

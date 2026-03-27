import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { PeripheralReasons } from '../constants/modules/PeripheralReasons'
import { PeripheralService } from '../services/PeripheralService'

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
  syncVersion: number = 0

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

      this.commitState({
        usbDisabled: usbState.data ?? false,
        btDisabled: btState.data ?? false,
        wifiDisabled: wifiState.data ?? false,
        hdcDisabled: hdcState.data ?? false,
        networkDisabled: networkState.data ?? false,
        printerDisabled: printerState.data ?? false,
        microphoneDisabled: microphoneState.data ?? false,
        cameraDisabled: cameraState.data ?? false,
        usbStoragePolicyIndex: this.getUsbStoragePolicyIndex(
          storagePolicy.data ?? edmUsbManager.UsbPolicy.READ_WRITE
        )
      })
    } catch (err) {
      hilog.error(DOMAIN, TAG, `reloadState failed: ${JSON.stringify(err)}`)
    }
  }

  async toggleInterface(feature: string, disallow: boolean): Promise<string | null> {
    this.processingKey = feature
    this.syncVersion++
    try {
      const result = PeripheralService.setInterfaceDisabledWithResult(feature, disallow)
      if (!result.success) {
        return this.normalizeReason(result.stage, PeripheralReasons.TOGGLE_INTERFACE_FAILED)
      }
      this.updateInterfaceState(feature, disallow)
      this.reloadState()
      return null
    } catch (err) {
      hilog.error(DOMAIN, TAG, `toggleInterface failed: ${JSON.stringify(err)}`)
      return PeripheralReasons.TOGGLE_INTERFACE_FAILED
    } finally {
      this.processingKey = ''
      this.syncVersion++
    }
  }

  async setUsbStoragePolicy(index: number): Promise<string | null> {
    this.processingKey = 'usb-storage-policy'
    this.syncVersion++
    try {
      const policy = index === 0
        ? edmUsbManager.UsbPolicy.READ_ONLY
        : index === 1
          ? edmUsbManager.UsbPolicy.READ_WRITE
          : edmUsbManager.UsbPolicy.DISABLED
      const result = PeripheralService.setUsbStoragePolicyWithCleanupResult(policy)
      if (!result.success) {
        return this.normalizeReason(result.stage, PeripheralReasons.USB_STORAGE_POLICY_FAILED)
      }
      this.commitState({
        usbDisabled: this.state.usbDisabled,
        btDisabled: this.state.btDisabled,
        wifiDisabled: this.state.wifiDisabled,
        hdcDisabled: this.state.hdcDisabled,
        networkDisabled: this.state.networkDisabled,
        printerDisabled: this.state.printerDisabled,
        microphoneDisabled: this.state.microphoneDisabled,
        cameraDisabled: this.state.cameraDisabled,
        usbStoragePolicyIndex: index
      })
      this.reloadState()
      return null
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralReasons.USB_STORAGE_POLICY_FAILED
    } finally {
      this.processingKey = ''
      this.syncVersion++
    }
  }

  private updateInterfaceState(feature: string, disallow: boolean): void {
    this.commitState({
      usbDisabled: feature === PeripheralService.FEATURE_USB ? disallow : this.state.usbDisabled,
      btDisabled: feature === PeripheralService.FEATURE_BLUETOOTH ? disallow : this.state.btDisabled,
      wifiDisabled: feature === PeripheralService.FEATURE_WIFI ? disallow : this.state.wifiDisabled,
      hdcDisabled: feature === PeripheralService.FEATURE_HDC ? disallow : this.state.hdcDisabled,
      networkDisabled: feature === PeripheralService.FEATURE_NETWORK ? disallow : this.state.networkDisabled,
      printerDisabled: feature === PeripheralService.FEATURE_PRINTER ? disallow : this.state.printerDisabled,
      microphoneDisabled: feature === PeripheralService.FEATURE_MICROPHONE ? disallow : this.state.microphoneDisabled,
      cameraDisabled: feature === PeripheralService.FEATURE_CAMERA ? disallow : this.state.cameraDisabled,
      usbStoragePolicyIndex: this.state.usbStoragePolicyIndex
    })
  }

  private commitState(nextState: InterfaceControlState): void {
    this.state = nextState
    this.syncVersion++
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
      case PeripheralReasons.READ_USB_STATUS_FAILED:
        return PeripheralReasons.READ_USB_STATUS_FAILED
      case PeripheralReasons.READ_USB_STORAGE_POLICY_FAILED:
        return PeripheralReasons.READ_USB_STORAGE_POLICY_FAILED
      case PeripheralReasons.SET_USB_INTERFACE_CONFLICT:
        return PeripheralReasons.SET_USB_INTERFACE_CONFLICT
      case PeripheralReasons.SET_USB_STORAGE_POLICY_CONFLICT:
        return PeripheralReasons.SET_USB_STORAGE_POLICY_CONFLICT
      default:
        return stage || fallbackReason
    }
  }
}

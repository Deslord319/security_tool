import { LogUtils } from '../../../utils/LogUtils'
import { usbManager as edmUsbManager } from '@kit.MDMKit'

import { PeripheralReasonCodes } from '../../../constants/modules/PeripheralStrings'
import { PeripheralService } from '../../../services/peripheral/interface-control/PeripheralService'

const TAG = 'InterfaceControlViewModel'

@ObservedV2
export class InterfaceControlStateModel {
  @Trace usbDisabled: boolean = false
  @Trace btDisabled: boolean = false
  @Trace wifiDisabled: boolean = false
  @Trace hdcDisabled: boolean = false
  @Trace networkDisabled: boolean = false
  @Trace printerDisabled: boolean = false
  @Trace microphoneDisabled: boolean = false
  @Trace cameraDisabled: boolean = false
  @Trace usbStoragePolicyIndex: number = 1
}

@ObservedV2
export class InterfaceControlViewModel {
  @Trace state: InterfaceControlStateModel = new InterfaceControlStateModel()

  @Trace processingKey: string = ''

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
      LogUtils.error(TAG, `reloadState failed: ${JSON.stringify(err)}`)
    }
  }

  async toggleInterface(feature: string, disallow: boolean): Promise<string | null> {
    this.processingKey = feature
    try {
      const result = PeripheralService.setInterfaceDisabledWithResult(feature, disallow)
      if (!result.success) {
        return this.normalizeReason(result.stage, PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED)
      }
      this.updateInterfaceState(feature, disallow)
      return null
    } catch (err) {
      LogUtils.error(TAG, `toggleInterface failed: ${JSON.stringify(err)}`)
      return PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED
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
        return this.normalizeReason(result.stage, PeripheralReasonCodes.USB_STORAGE_POLICY_FAILED)
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
      return null
    } catch (err) {
      LogUtils.error(TAG, `setUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralReasonCodes.USB_STORAGE_POLICY_FAILED
    } finally {
      this.processingKey = ''
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

  private commitState(nextState: InterfaceControlStateModel): void {
    this.state.usbDisabled = nextState.usbDisabled
    this.state.btDisabled = nextState.btDisabled
    this.state.wifiDisabled = nextState.wifiDisabled
    this.state.hdcDisabled = nextState.hdcDisabled
    this.state.networkDisabled = nextState.networkDisabled
    this.state.printerDisabled = nextState.printerDisabled
    this.state.microphoneDisabled = nextState.microphoneDisabled
    this.state.cameraDisabled = nextState.cameraDisabled
    this.state.usbStoragePolicyIndex = nextState.usbStoragePolicyIndex
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
      case PeripheralReasonCodes.READ_USB_STATUS_FAILED:
        return PeripheralReasonCodes.READ_USB_STATUS_FAILED
      case PeripheralReasonCodes.READ_USB_STORAGE_POLICY_FAILED:
        return PeripheralReasonCodes.READ_USB_STORAGE_POLICY_FAILED
      case PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT:
        return PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT
      case PeripheralReasonCodes.SET_USB_STORAGE_POLICY_CONFLICT:
        return PeripheralReasonCodes.SET_USB_STORAGE_POLICY_CONFLICT
      default:
        return stage || fallbackReason
    }
  }
}

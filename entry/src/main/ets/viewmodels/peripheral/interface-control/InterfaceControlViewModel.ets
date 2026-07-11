import { LogUtils } from '../../../utils/LogUtils'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { OperationResult } from '../../../models/CommonModels'

import { PeripheralReasonCodes } from '../../../constants/modules/PeripheralStrings'
import {
  PeripheralInterfaceFeature,
  PeripheralInterfaceFeatures,
  UsbStoragePolicy
} from '../../../models/PeripheralModels'
import { PeripheralService } from '../../../services/peripheral/interface-control/PeripheralService'
import { WiredNetworkService } from '../../../services/peripheral/interface-control/WiredNetworkService'
import { UsbGlobalPolicyService } from '../../../services/peripheral/interface-control/UsbGlobalPolicyService'
import { PeripheralPolicySnapshotTraceService } from '../../../services/peripheral/connection-record/PeripheralPolicySnapshotTraceService'
import { BluetoothPolicySnapshotTraceService } from '../../../services/peripheral/connection-record/BluetoothPolicySnapshotTraceService'
import {
  BluetoothConnectedDeviceSnapshot,
  BluetoothRuntimeConnectionStore
} from '../../../services/peripheral/connection-record/BluetoothRuntimeConnectionStore'

const TAG = 'InterfaceControlViewModel'
const USB_STORAGE_POLICY_INDEX_READ_ONLY = 0
const USB_STORAGE_POLICY_INDEX_READ_WRITE = 1
const USB_STORAGE_POLICY_INDEX_DISABLED = 2

interface UsbStoragePolicyOption {
  index: number
  policy: edmUsbManager.UsbPolicy
}

const USB_STORAGE_POLICY_OPTIONS: UsbStoragePolicyOption[] = [
  { index: USB_STORAGE_POLICY_INDEX_READ_ONLY, policy: edmUsbManager.UsbPolicy.READ_ONLY },
  { index: USB_STORAGE_POLICY_INDEX_READ_WRITE, policy: edmUsbManager.UsbPolicy.READ_WRITE },
  { index: USB_STORAGE_POLICY_INDEX_DISABLED, policy: edmUsbManager.UsbPolicy.DISABLED }
]

@ObservedV2
export class InterfaceControlStateModel {
  @Trace usbDisabled: boolean = false
  @Trace btDisabled: boolean = false
  @Trace wifiDisabled: boolean = false
  @Trace ethernetDisabled: boolean = false
  @Trace hdcDisabled: boolean = false
  @Trace networkDisabled: boolean = false
  @Trace printerDisabled: boolean = false
  @Trace microphoneDisabled: boolean = false
  @Trace cameraDisabled: boolean = false
  @Trace usbStoragePolicyIndex: number = USB_STORAGE_POLICY_INDEX_READ_WRITE
}

@ObservedV2
export class InterfaceControlViewModel {
  @Trace state: InterfaceControlStateModel = new InterfaceControlStateModel()

  @Trace processingKey: string = ''

  async reloadState(): Promise<void> {
    try {
      const btState = PeripheralService.getInterfaceDisabledWithResult(PeripheralInterfaceFeatures.BLUETOOTH)
      const wifiState = PeripheralService.getInterfaceDisabledWithResult(PeripheralInterfaceFeatures.WIFI)
      const ethernetState = await WiredNetworkService.getDisabledWithResult()
      const hdcState = PeripheralService.getInterfaceDisabledWithResult(PeripheralInterfaceFeatures.HDC)
      const networkState = PeripheralService.getInterfaceDisabledWithResult(PeripheralInterfaceFeatures.NETWORK)
      const printerState = PeripheralService.getInterfaceDisabledWithResult(PeripheralInterfaceFeatures.PRINTER)
      const microphoneState = PeripheralService.getInterfaceDisabledWithResult(PeripheralInterfaceFeatures.MICROPHONE)
      const cameraState = PeripheralService.getInterfaceDisabledWithResult(PeripheralInterfaceFeatures.CAMERA)
      const storagePolicy = PeripheralService.getUsbStoragePolicyWithResult()
      this.commitState({
        usbDisabled: PeripheralService.getInterfaceDisabledWithResult(PeripheralInterfaceFeatures.USB).data ?? false,
        btDisabled: btState.data ?? false,
        wifiDisabled: wifiState.data ?? false,
        ethernetDisabled: ethernetState.data ?? false,
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

  async toggleInterface(feature: PeripheralInterfaceFeature, disallow: boolean): Promise<string | null> {
    this.processingKey = feature
    try {
      if (feature === PeripheralInterfaceFeatures.USB) {
        const result = await UsbGlobalPolicyService.setDisabled(disallow)
        if (!result.success) {
          return this.normalizeReason(result.stage, PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED)
        }
        this.updateInterfaceState(feature, disallow)
        return null
      }

      if (feature === PeripheralInterfaceFeatures.ETHERNET) {
        const result = await WiredNetworkService.setDisabledWithResult(disallow)
        if (!result.success) {
          return this.normalizeReason(result.stage, PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED)
        }
        this.updateInterfaceState(feature, disallow)
        return null
      }

      const bluetoothSnapshots: BluetoothConnectedDeviceSnapshot[] =
        feature === PeripheralInterfaceFeatures.BLUETOOTH && disallow
          ? BluetoothRuntimeConnectionStore.captureConnectedDevices()
          : []
      bluetoothSnapshots.forEach((snapshot: BluetoothConnectedDeviceSnapshot) => {
        BluetoothRuntimeConnectionStore.markDisabledDisconnectPending(snapshot.deviceId)
      })
      let result: OperationResult<void>
      try {
        result = PeripheralService.setInterfaceDisabledWithResult(feature, disallow)
      } catch (err) {
        bluetoothSnapshots.forEach((snapshot: BluetoothConnectedDeviceSnapshot) => {
          BluetoothRuntimeConnectionStore.clearDisabledDisconnectPending(snapshot.deviceId)
        })
        throw err as Error
      }

      if (!result.success) {
        bluetoothSnapshots.forEach((snapshot: BluetoothConnectedDeviceSnapshot) => {
          BluetoothRuntimeConnectionStore.clearDisabledDisconnectPending(snapshot.deviceId)
        })
        return this.normalizeReason(result.stage, PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED)
      }
      if (feature === PeripheralInterfaceFeatures.BLUETOOTH && disallow) {
        await BluetoothPolicySnapshotTraceService.appendBluetoothDisabledPolicySnapshot(bluetoothSnapshots)
      } else if (feature === PeripheralInterfaceFeatures.BLUETOOTH) {
        BluetoothRuntimeConnectionStore.clearAllDisabledDisconnectPending()
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
      if (this.state.usbDisabled) {
        return PeripheralReasonCodes.SET_USB_INTERFACE_CONFLICT
      }
      const option = this.resolveUsbStoragePolicyOption(index)
      const result = PeripheralService.setUsbStoragePolicyWithCleanupResult(option.policy)
      if (!result.success) {
        return this.normalizeReason(result.stage, PeripheralReasonCodes.USB_STORAGE_POLICY_FAILED)
      }
      await PeripheralPolicySnapshotTraceService.appendUsbStoragePolicySnapshot(this.toUsbStoragePolicy(option.policy))
      this.commitState({
        usbDisabled: this.state.usbDisabled,
        btDisabled: this.state.btDisabled,
        wifiDisabled: this.state.wifiDisabled,
        ethernetDisabled: this.state.ethernetDisabled,
        hdcDisabled: this.state.hdcDisabled,
        networkDisabled: this.state.networkDisabled,
        printerDisabled: this.state.printerDisabled,
        microphoneDisabled: this.state.microphoneDisabled,
        cameraDisabled: this.state.cameraDisabled,
        usbStoragePolicyIndex: option.index
      })
      return null
    } catch (err) {
      LogUtils.error(TAG, `setUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralReasonCodes.USB_STORAGE_POLICY_FAILED
    } finally {
      this.processingKey = ''
    }
  }

  private updateInterfaceState(feature: PeripheralInterfaceFeature, disallow: boolean): void {
    this.commitState({
      usbDisabled: feature === PeripheralInterfaceFeatures.USB ? disallow : this.state.usbDisabled,
      btDisabled: feature === PeripheralInterfaceFeatures.BLUETOOTH ? disallow : this.state.btDisabled,
      wifiDisabled: feature === PeripheralInterfaceFeatures.WIFI ? disallow : this.state.wifiDisabled,
      ethernetDisabled: feature === PeripheralInterfaceFeatures.ETHERNET ? disallow : this.state.ethernetDisabled,
      hdcDisabled: feature === PeripheralInterfaceFeatures.HDC ? disallow : this.state.hdcDisabled,
      networkDisabled: feature === PeripheralInterfaceFeatures.NETWORK ? disallow : this.state.networkDisabled,
      printerDisabled: feature === PeripheralInterfaceFeatures.PRINTER ? disallow : this.state.printerDisabled,
      microphoneDisabled: feature === PeripheralInterfaceFeatures.MICROPHONE ? disallow : this.state.microphoneDisabled,
      cameraDisabled: feature === PeripheralInterfaceFeatures.CAMERA ? disallow : this.state.cameraDisabled,
      usbStoragePolicyIndex: this.state.usbStoragePolicyIndex
    })
  }

  private commitState(nextState: InterfaceControlStateModel): void {
    this.state.usbDisabled = nextState.usbDisabled
    this.state.btDisabled = nextState.btDisabled
    this.state.wifiDisabled = nextState.wifiDisabled
    this.state.ethernetDisabled = nextState.ethernetDisabled
    this.state.hdcDisabled = nextState.hdcDisabled
    this.state.networkDisabled = nextState.networkDisabled
    this.state.printerDisabled = nextState.printerDisabled
    this.state.microphoneDisabled = nextState.microphoneDisabled
    this.state.cameraDisabled = nextState.cameraDisabled
    this.state.usbStoragePolicyIndex = nextState.usbStoragePolicyIndex
  }

  private getUsbStoragePolicyIndex(policy: edmUsbManager.UsbPolicy): number {
    let option = USB_STORAGE_POLICY_OPTIONS.find((item: UsbStoragePolicyOption) => item.policy === policy)
    return option ? option.index : USB_STORAGE_POLICY_INDEX_READ_WRITE
  }

  private resolveUsbStoragePolicyOption(index: number): UsbStoragePolicyOption {
    let option = USB_STORAGE_POLICY_OPTIONS.find((item: UsbStoragePolicyOption) => item.index === index)
    if (option) {
      return option
    }
    return USB_STORAGE_POLICY_OPTIONS[USB_STORAGE_POLICY_INDEX_READ_WRITE]
  }

  private toUsbStoragePolicy(policy: edmUsbManager.UsbPolicy): UsbStoragePolicy {
    switch (policy) {
      case edmUsbManager.UsbPolicy.READ_ONLY:
        return UsbStoragePolicy.READ_ONLY
      case edmUsbManager.UsbPolicy.DISABLED:
        return UsbStoragePolicy.DISABLED
      case edmUsbManager.UsbPolicy.READ_WRITE:
      default:
        return UsbStoragePolicy.READ_WRITE
    }
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
      case PeripheralReasonCodes.TURN_ON_WIFI_FAILED:
      case PeripheralReasonCodes.TURN_ON_BLUETOOTH_FAILED:
        return fallbackReason
      default:
        return stage || fallbackReason
    }
  }
}

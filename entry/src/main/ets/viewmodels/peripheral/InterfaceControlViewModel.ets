/**
 * 接口管控 ViewModel
 */
import { Observed } from '@kit.ArkUI'
import { PeripheralViewModelBase } from './PeripheralViewModelBase'
import { PeripheralService } from '../../services/PeripheralService'
import { usbManager } from '@kit.MDMKit'

@Observed
export class InterfaceControlViewModel extends PeripheralViewModelBase {
  @Observed usbDisabled: boolean = false
  @Observed btDisabled: boolean = false
  @Observed wifiDisabled: boolean = false
  @Observed hdcDisabled: boolean = false
  @Observed networkDisabled: boolean = false
  @Observed printerDisabled: boolean = false
  @Observed microphoneDisabled: boolean = false
  @Observed cameraDisabled: boolean = false
  @Observed usbStoragePolicyIndex: number = 0
  @Observed syncToken: number = 0
  @Observed processingKey: string = ''

  protected async onInitialize(): Promise<void> { await this.reloadState() }

  async reloadState(): Promise<void> {
    this.isLoading = true
    try {
      this.usbDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_USB).data ?? false
      this.btDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_BLUETOOTH).data ?? false
      this.wifiDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_WIFI).data ?? false
      this.hdcDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_HDC).data ?? false
      this.networkDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_NETWORK).data ?? false
      this.printerDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_PRINTER).data ?? false
      this.microphoneDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_MICROPHONE).data ?? false
      this.cameraDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_CAMERA).data ?? false
      const policy = PeripheralService.getUsbStoragePolicyWithResult().data ?? usbManager.UsbPolicy.READ_WRITE
      this.usbStoragePolicyIndex = policy === usbManager.UsbPolicy.READ_ONLY ? 0 : policy === usbManager.UsbPolicy.READ_WRITE ? 1 : 2
      this.syncToken++
    } finally { this.isLoading = false }
  }

  async toggleInterface(feature: string, disallow: boolean): Promise<boolean> {
    if (!this.ensureAdminReady('切换接口状态')) return false
    this.processingKey = feature
    try { const result = PeripheralService.setInterfaceDisabledWithResult(feature, disallow); if (result.success) await this.reloadState(); return result.success }
    finally { this.processingKey = ''; this.isLoading = false }
  }

  async setUsbStoragePolicy(index: number): Promise<boolean> {
    if (!this.ensureAdminReady('设置 USB 存储策略')) return false
    const policy = index === 0 ? usbManager.UsbPolicy.READ_ONLY : index === 1 ? usbManager.UsbPolicy.READ_WRITE : usbManager.UsbPolicy.DENY
    this.processingKey = 'usb-storage'
    try { const result = PeripheralService.setUsbStoragePolicyWithResult(policy); if (result.success) { this.usbStoragePolicyIndex = index; await this.reloadState() }; return result.success }
    finally { this.processingKey = ''; this.isLoading = false }
  }

  getInterfaceControlKey(feature: string): string { return feature }
  isInterfaceControlProcessing(key: string): boolean { return this.processingKey === key }
  mapUsbStoragePolicyToIndex(policy: usbManager.UsbPolicy): number { return policy === usbManager.UsbPolicy.READ_ONLY ? 0 : policy === usbManager.UsbPolicy.READ_WRITE ? 1 : 2 }
  mapIndexToUsbStoragePolicy(index: number): usbManager.UsbPolicy { return index === 0 ? usbManager.UsbPolicy.READ_ONLY : index === 1 ? usbManager.UsbPolicy.READ_WRITE : usbManager.UsbPolicy.DENY }
  getUsbStoragePolicyLogValue(index: number): string { return ['只读', '读写', '禁用'][index] || '未知' }
}

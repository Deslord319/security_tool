/**
 * 外设管理 ViewModel
 * 参考 LogManageViewModel 模式 - 使用简单类
 */
import { common } from '@kit.AbilityKit'
import { PeripheralService } from '../services/PeripheralService'
import { PeripheralTraceRepository } from '../services/PeripheralTraceRepository'
import { PeripheralConnectionRecordService } from '../services/PeripheralConnectionRecordService'
import {
  PeripheralConnectionRecord,
  PeripheralType,
  formatUsbDeviceId,
  inferPeripheralTypeFromBaseClass,
  parseUsbDeviceId
} from '../models/DataModels'
import { usbManager as edmUsbManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'PeripheralViewModel'
const DOMAIN = 0x0013

export class PeripheralViewModel {
  // 接口管控状态
  usbDisabled: boolean = false
  btDisabled: boolean = false
  wifiDisabled: boolean = false
  hdcDisabled: boolean = false
  networkDisabled: boolean = false
  printerDisabled: boolean = false
  microphoneDisabled: boolean = false
  cameraDisabled: boolean = false
  usbStoragePolicyIndex: number = 0
  
  // 黑白名单数据
  usbWhitelist: edmUsbManager.UsbDeviceId[] = []
  usbBlacklist: edmUsbManager.UsbDeviceType[] = []
  btWhitelist: string[] = []
  
  // 设备连接记录
  deviceRecords: PeripheralConnectionRecord[] = []
  
  // UI 状态
  isLoading: boolean = false
  errorMessage: string | null = null
  
  private traceStorageListenerId: number = -1

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.isLoading = true
    try {
      await this.reloadAllData()
      
      this.traceStorageListenerId = PeripheralTraceRepository.addChangeListener(() => {
        this.handleDataChange()
      })
    } catch (err) {
      this.errorMessage = `初始化失败：${JSON.stringify(err)}`
      hilog.error(DOMAIN, TAG, `Initialize failed: ${JSON.stringify(err)}`)
    } finally {
      this.isLoading = false
    }
  }

  destroy(): void {
    if (this.traceStorageListenerId > 0) {
      PeripheralTraceRepository.removeChangeListener(this.traceStorageListenerId)
      this.traceStorageListenerId = -1
    }
  }

  private handleDataChange(): void {
    this.reloadAllData()
  }

  async reloadAllData(): Promise<void> {
    this.reloadInterfaceState()
    this.reloadWhitelistBlacklist()
    this.reloadDeviceRecords()
  }

  private reloadInterfaceState(): void {
    try {
      this.usbDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_USB).data ?? false
      this.btDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_BLUETOOTH).data ?? false
      this.wifiDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_WIFI).data ?? false
      this.hdcDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_HDC).data ?? false
      this.networkDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_NETWORK).data ?? false
      this.printerDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_PRINTER).data ?? false
      this.microphoneDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_MICROPHONE).data ?? false
      this.cameraDisabled = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_CAMERA).data ?? false
      
      const policy = PeripheralService.getUsbStoragePolicyWithResult().data ?? edmUsbManager.UsbPolicy.READ_WRITE
      this.usbStoragePolicyIndex = policy === edmUsbManager.UsbPolicy.READ_ONLY ? 0 : policy === edmUsbManager.UsbPolicy.READ_WRITE ? 1 : 2
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Reload interface state failed: ${JSON.stringify(err)}`)
    }
  }

  private reloadWhitelistBlacklist(): void {
    try {
      this.usbWhitelist = PeripheralService.getUsbWhitelistWithResult().data ?? []
      this.usbBlacklist = PeripheralService.getUsbBlacklistWithResult().data ?? []
      this.btWhitelist = PeripheralService.getBluetoothWhitelistWithResult().data ?? []
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Reload whitelist/blacklist failed: ${JSON.stringify(err)}`)
    }
  }

  private reloadDeviceRecords(): void {
    try {
      this.deviceRecords = PeripheralConnectionRecordService.queryRecords()
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Reload device records failed: ${JSON.stringify(err)}`)
    }
  }

  async toggleInterface(feature: string, disallow: boolean): Promise<boolean> {
    try {
      const result = PeripheralService.setInterfaceDisabledWithResult(feature, disallow)
      if (result.success) {
        await this.reloadInterfaceState()
        return true
      } else {
        this.errorMessage = result.errorMessage || '操作失败'
        return false
      }
    } catch (err) {
      this.errorMessage = `切换接口失败：${JSON.stringify(err)}`
      return false
    }
  }

  async setUsbStoragePolicy(index: number): Promise<boolean> {
    try {
      const policy = index === 0 ? edmUsbManager.UsbPolicy.READ_ONLY : index === 1 ? edmUsbManager.UsbPolicy.READ_WRITE : edmUsbManager.UsbPolicy.DISABLED
      const result = PeripheralService.setUsbStoragePolicyWithResult(policy)
      if (result.success) {
        this.usbStoragePolicyIndex = index
        return true
      } else {
        this.errorMessage = result.errorMessage || '设置策略失败'
        return false
      }
    } catch (err) {
      this.errorMessage = `设置 USB 存储策略失败：${JSON.stringify(err)}`
      return false
    }
  }

  async addToUsbWhitelist(vendorId: number, productId: number): Promise<boolean> {
    try {
      const result = PeripheralService.addUsbWhitelistWithResult([{ vendorId, productId }])
      if (result.success) {
        await this.reloadWhitelistBlacklist()
        return true
      } else {
        this.errorMessage = result.errorMessage || '添加失败'
        return false
      }
    } catch (err) {
      this.errorMessage = `添加到 USB 白名单失败：${JSON.stringify(err)}`
      return false
    }
  }

  async removeFromUsbWhitelist(device: edmUsbManager.UsbDeviceId): Promise<boolean> {
    try {
      const result = PeripheralService.removeUsbWhitelistWithResult([device])
      if (result.success) {
        await this.reloadWhitelistBlacklist()
        return true
      } else {
        this.errorMessage = result.errorMessage || '移除失败'
        return false
      }
    } catch (err) {
      this.errorMessage = `从 USB 白名单移除失败：${JSON.stringify(err)}`
      return false
    }
  }

  async addToBluetoothWhitelist(mac: string): Promise<boolean> {
    try {
      const result = PeripheralService.addBluetoothWhitelistWithResult([mac])
      if (result.success) {
        await this.reloadWhitelistBlacklist()
        return true
      } else {
        this.errorMessage = result.errorMessage || '添加失败'
        return false
      }
    } catch (err) {
      this.errorMessage = `添加到蓝牙白名单失败：${JSON.stringify(err)}`
      return false
    }
  }

  async removeFromBluetoothWhitelist(mac: string): Promise<boolean> {
    try {
      const result = PeripheralService.removeBluetoothWhitelistWithResult([mac])
      if (result.success) {
        await this.reloadWhitelistBlacklist()
        return true
      } else {
        this.errorMessage = result.errorMessage || '移除失败'
        return false
      }
    } catch (err) {
      this.errorMessage = `从蓝牙白名单移除失败：${JSON.stringify(err)}`
      return false
    }
  }

  async addToUsbBlacklist(baseClass: number, subClass: number, protocol: number): Promise<boolean> {
    try {
      const deviceType: edmUsbManager.UsbDeviceType = { baseClass, subClass, protocol, descriptor: edmUsbManager.Descriptor.INTERFACE }
      const result = PeripheralService.addUsbBlacklistWithResult([deviceType])
      if (result.success) {
        await this.reloadWhitelistBlacklist()
        return true
      } else {
        this.errorMessage = result.errorMessage || '添加失败'
        return false
      }
    } catch (err) {
      this.errorMessage = `添加到 USB 黑名单失败：${JSON.stringify(err)}`
      return false
    }
  }

  async removeFromUsbBlacklist(deviceType: edmUsbManager.UsbDeviceType): Promise<boolean> {
    try {
      const result = PeripheralService.removeUsbBlacklistWithResult([deviceType])
      if (result.success) {
        await this.reloadWhitelistBlacklist()
        return true
      } else {
        this.errorMessage = result.errorMessage || '移除失败'
        return false
      }
    } catch (err) {
      this.errorMessage = `从 USB 黑名单移除失败：${JSON.stringify(err)}`
      return false
    }
  }

  async handlePeripheralPolicyChange(
    deviceId: string,
    deviceType: PeripheralType,
    policyIndex: number
  ): Promise<boolean> {
    try {
      const parsed = parseUsbDeviceId(deviceId)
      if (!parsed) {
        this.errorMessage = '无法识别当前设备标识'
        return false
      }

      const device: edmUsbManager.UsbDeviceId = {
        vendorId: parsed.vendorId,
        productId: parsed.productId
      }
      const targetPolicy = policyIndex === 0 ?
        PeripheralService.USB_DEVICE_POLICY_ALLOW :
        PeripheralService.USB_DEVICE_POLICY_DENY

      const result = PeripheralService.switchUsbDevicePolicyWithResult(device, deviceType, targetPolicy)
      if (result.success) {
        await this.reloadAllData()
        return true
      } else {
        this.errorMessage = result.userMessage?.trim() || result.errorMessage || '修改设备策略失败'
        return false
      }
    } catch (err) {
      this.errorMessage = `修改设备策略失败：${JSON.stringify(err)}`
      return false
    }
  }
}

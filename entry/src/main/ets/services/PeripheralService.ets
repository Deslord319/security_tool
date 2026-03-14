import restrictions from '@ohos.enterprise.restrictions'
import { usbManager } from '@kit.MDMKit'
import { bluetoothManager } from '@kit.MDMKit'
import { networkManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Want } from '@kit.AbilityKit'
import { AppInfo } from '../constants/AppConstants'
import { OperationResult } from '../models/DataModels'
import { EnterpriseAdminService } from './EnterpriseAdminService'

const TAG = 'PeripheralService'
const DOMAIN = 0x0002

// 企业管理员 Want 对象
const ADMIN_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: 'EnterpriseAdminAbility'
}

export class PeripheralService {
  static readonly FEATURE_USB: string = 'usb'
  static readonly FEATURE_BLUETOOTH: string = 'bluetooth'
  static readonly FEATURE_WIFI: string = 'wifi'
  static readonly FEATURE_HDC: string = 'hdc'
  static readonly FEATURE_NETWORK: string = 'network'
  static readonly FEATURE_PRINTER: string = 'printer'
  static readonly FEATURE_MICROPHONE: string = 'microphone'
  static readonly FEATURE_CAMERA: string = 'camera'

  // ========== 接口管控 (restrictions) ==========

  static setInterfaceDisabledWithResult(feature: string, disallow: boolean): OperationResult<void> {
    if (feature === PeripheralService.FEATURE_NETWORK) {
      return PeripheralService.setNetworkInterfaceDisabledWithResult(disallow)
    }

    try {
      restrictions.setDisallowedPolicy(ADMIN_WANT, feature, disallow)
      hilog.info(DOMAIN, TAG, `setInterfaceDisabled: ${feature} = ${disallow}`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('设置接口禁用策略', err as Object)
    }
  }

  static setNetworkInterfaceDisabledWithResult(disallow: boolean): OperationResult<void> {
    try {
      const interfaces: string[] = networkManager.getAllNetworkInterfacesSync(ADMIN_WANT)
      for (let i = 0; i < interfaces.length; i++) {
        networkManager.setNetworkInterfaceDisabledSync(ADMIN_WANT, interfaces[i], disallow)
      }
      hilog.info(DOMAIN, TAG, `setNetworkInterfaceDisabled success: ${disallow}`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setNetworkInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('set network interface status failed', err as Object)
    }
  }

  // 设置接口禁用策略 (feature: 'usb' | 'bluetooth' | 'wifi' | 'hdc')
  static setInterfaceDisabled(feature: string, disallow: boolean): boolean {
    return PeripheralService.setInterfaceDisabledWithResult(feature, disallow).success
  }

  static getInterfaceDisabledWithResult(feature: string): OperationResult<boolean> {
    if (feature === PeripheralService.FEATURE_NETWORK) {
      return PeripheralService.getNetworkInterfaceDisabledWithResult()
    }

    try {
      return {
        success: true,
        data: restrictions.getDisallowedPolicy(ADMIN_WANT, feature)
      } as OperationResult<boolean>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<boolean>('读取接口禁用状态', err as Object, false)
    }
  }

  static getNetworkInterfaceDisabledWithResult(): OperationResult<boolean> {
    try {
      const interfaces: string[] = networkManager.getAllNetworkInterfacesSync(ADMIN_WANT)
      if (interfaces.length === 0) {
        return { success: true, data: false } as OperationResult<boolean>
      }
      let allDisabled: boolean = true
      for (let i = 0; i < interfaces.length; i++) {
        if (!networkManager.isNetworkInterfaceDisabledSync(ADMIN_WANT, interfaces[i])) {
          allDisabled = false
          break
        }
      }
      return {
        success: true,
        data: allDisabled
      } as OperationResult<boolean>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getNetworkInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<boolean>('get network interface status failed', err as Object, false)
    }
  }

  // 获取接口禁用状态
  static getInterfaceDisabled(feature: string): boolean {
    return PeripheralService.getInterfaceDisabledWithResult(feature).data ?? false
  }

  // ========== USB 存储策略 ==========

  static setUsbStoragePolicyWithResult(policy: usbManager.UsbPolicy): OperationResult<void> {
    try {
      usbManager.setUsbStorageDeviceAccessPolicy(ADMIN_WANT, policy)
      hilog.info(DOMAIN, TAG, `setUsbStoragePolicy: ${policy}`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('设置 USB 存储策略', err as Object)
    }
  }

  // 设置 USB 存储设备访问策略
  static setUsbStoragePolicy(policy: usbManager.UsbPolicy): boolean {
    return PeripheralService.setUsbStoragePolicyWithResult(policy).success
  }

  static getUsbStoragePolicyWithResult(): OperationResult<usbManager.UsbPolicy> {
    try {
      return {
        success: true,
        data: usbManager.getUsbStorageDeviceAccessPolicy(ADMIN_WANT)
      } as OperationResult<usbManager.UsbPolicy>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<usbManager.UsbPolicy>(
        '读取 USB 存储策略',
        err as Object,
        usbManager.UsbPolicy.READ_WRITE
      )
    }
  }

  // 获取 USB 存储设备访问策略
  static getUsbStoragePolicy(): usbManager.UsbPolicy {
    return PeripheralService.getUsbStoragePolicyWithResult().data ?? usbManager.UsbPolicy.READ_WRITE
  }

  // ========== USB 白名单 (按 VID/PID) ==========

  static addUsbWhitelistWithResult(devices: usbManager.UsbDeviceId[]): OperationResult<void> {
    try {
      usbManager.addAllowedUsbDevices(ADMIN_WANT, devices)
      hilog.info(DOMAIN, TAG, `addUsbWhitelist: ${devices.length} devices`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `addUsbWhitelist failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('添加 USB 白名单', err as Object)
    }
  }

  // 添加 USB 设备到白名单
  static addUsbWhitelist(devices: usbManager.UsbDeviceId[]): boolean {
    return PeripheralService.addUsbWhitelistWithResult(devices).success
  }

  static removeUsbWhitelistWithResult(devices: usbManager.UsbDeviceId[]): OperationResult<void> {
    try {
      usbManager.removeAllowedUsbDevices(ADMIN_WANT, devices)
      hilog.info(DOMAIN, TAG, `removeUsbWhitelist: ${devices.length} devices`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `removeUsbWhitelist failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('移除 USB 白名单', err as Object)
    }
  }

  // 从白名单移除 USB 设备
  static removeUsbWhitelist(devices: usbManager.UsbDeviceId[]): boolean {
    return PeripheralService.removeUsbWhitelistWithResult(devices).success
  }

  static getUsbWhitelistWithResult(): OperationResult<usbManager.UsbDeviceId[]> {
    try {
      return {
        success: true,
        data: usbManager.getAllowedUsbDevices(ADMIN_WANT)
      } as OperationResult<usbManager.UsbDeviceId[]>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getUsbWhitelist failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<usbManager.UsbDeviceId[]>('读取 USB 白名单', err as Object, [])
    }
  }

  // 获取 USB 白名单
  static getUsbWhitelist(): usbManager.UsbDeviceId[] {
    return PeripheralService.getUsbWhitelistWithResult().data ?? []
  }

  // ========== USB 黑名单 (按设备类型) ==========

  static addUsbBlacklistWithResult(types: usbManager.UsbDeviceType[]): OperationResult<void> {
    try {
      usbManager.addDisallowedUsbDevices(ADMIN_WANT, types)
      hilog.info(DOMAIN, TAG, `addUsbBlacklist: ${types.length} types`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `addUsbBlacklist failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('添加 USB 黑名单', err as Object)
    }
  }

  // 添加 USB 设备类型到黑名单
  static addUsbBlacklist(types: usbManager.UsbDeviceType[]): boolean {
    return PeripheralService.addUsbBlacklistWithResult(types).success
  }

  static removeUsbBlacklistWithResult(types: usbManager.UsbDeviceType[]): OperationResult<void> {
    try {
      usbManager.removeDisallowedUsbDevices(ADMIN_WANT, types)
      hilog.info(DOMAIN, TAG, `removeUsbBlacklist: ${types.length} types`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `removeUsbBlacklist failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('移除 USB 黑名单', err as Object)
    }
  }

  // 从黑名单移除 USB 设备类型
  static removeUsbBlacklist(types: usbManager.UsbDeviceType[]): boolean {
    return PeripheralService.removeUsbBlacklistWithResult(types).success
  }

  static getUsbBlacklistWithResult(): OperationResult<usbManager.UsbDeviceType[]> {
    try {
      return {
        success: true,
        data: usbManager.getDisallowedUsbDevices(ADMIN_WANT)
      } as OperationResult<usbManager.UsbDeviceType[]>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getUsbBlacklist failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<usbManager.UsbDeviceType[]>('读取 USB 黑名单', err as Object, [])
    }
  }

  // 获取 USB 黑名单
  static getUsbBlacklist(): usbManager.UsbDeviceType[] {
    return PeripheralService.getUsbBlacklistWithResult().data ?? []
  }

  // ========== 蓝牙白名单 (按 MAC 地址) ==========

  static addBluetoothWhitelistWithResult(deviceIds: string[]): OperationResult<void> {
    try {
      bluetoothManager.addAllowedBluetoothDevices(ADMIN_WANT, deviceIds)
      hilog.info(DOMAIN, TAG, `addBluetoothWhitelist: ${deviceIds.length} devices`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `addBluetoothWhitelist failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('添加蓝牙白名单', err as Object)
    }
  }

  // 添加蓝牙设备到白名单
  static addBluetoothWhitelist(deviceIds: string[]): boolean {
    return PeripheralService.addBluetoothWhitelistWithResult(deviceIds).success
  }

  static removeBluetoothWhitelistWithResult(deviceIds: string[]): OperationResult<void> {
    try {
      bluetoothManager.removeAllowedBluetoothDevices(ADMIN_WANT, deviceIds)
      hilog.info(DOMAIN, TAG, `removeBluetoothWhitelist: ${deviceIds.length} devices`)
      return { success: true } as OperationResult<void>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `removeBluetoothWhitelist failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<void>('移除蓝牙白名单', err as Object)
    }
  }

  // 从白名单移除蓝牙设备
  static removeBluetoothWhitelist(deviceIds: string[]): boolean {
    return PeripheralService.removeBluetoothWhitelistWithResult(deviceIds).success
  }

  static getBluetoothWhitelistWithResult(): OperationResult<string[]> {
    try {
      return {
        success: true,
        data: bluetoothManager.getAllowedBluetoothDevices(ADMIN_WANT)
      } as OperationResult<string[]>
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getBluetoothWhitelist failed: ${JSON.stringify(err)}`)
      return PeripheralService.buildFailureResult<string[]>('读取蓝牙白名单', err as Object, [])
    }
  }

  // 获取蓝牙白名单
  static getBluetoothWhitelist(): string[] {
    return PeripheralService.getBluetoothWhitelistWithResult().data ?? []
  }

  private static buildFailureResult<T>(action: string, err: Object, fallbackData?: T): OperationResult<T> {
    let code = EnterpriseAdminService.extractErrorCode(err)
    let isAdminMissing = EnterpriseAdminService.isAdminMissingError(err)
    let message = isAdminMissing ?
      '企业管理员未激活，无法执行设备管理操作。' :
      `${action}失败`
    let suggestion = isAdminMissing ?
      `请先在设备执行：${EnterpriseAdminService.buildEnableCommand()}` :
      '请检查权限声明、签名模板和设备策略状态后重试。'
    return {
      success: false,
      data: fallbackData,
      errorCode: code,
      errorMessage: message,
      isAdminMissing: isAdminMissing,
      suggestion: suggestion
    } as OperationResult<T>
  }
}

import restrictions from '@ohos.enterprise.restrictions'
import { usbManager } from '@kit.MDMKit'
import { bluetoothManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'PeripheralService'
const DOMAIN = 0x0002

export class PeripheralService {

  // ========== 接口管控 (restrictions) ==========

  // 设置接口禁用策略 (feature: 'usb' | 'bluetooth' | 'wifi' | 'hdc')
  static setInterfaceDisabled(feature: string, disallow: boolean): boolean {
    try {
      restrictions.setDisallowedPolicy(null, feature, disallow)
      hilog.info(DOMAIN, TAG, `setInterfaceDisabled: ${feature} = ${disallow}`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取接口禁用状态
  static getInterfaceDisabled(feature: string): boolean {
    try {
      return restrictions.getDisallowedPolicy(null, feature)
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getInterfaceDisabled failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // ========== USB 存储策略 ==========

  // 设置 USB 存储设备访问策略
  static setUsbStoragePolicy(policy: usbManager.UsbPolicy): boolean {
    try {
      usbManager.setUsbStorageDeviceAccessPolicy(null, policy)
      hilog.info(DOMAIN, TAG, `setUsbStoragePolicy: ${policy}`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `setUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取 USB 存储设备访问策略
  static getUsbStoragePolicy(): usbManager.UsbPolicy {
    try {
      return usbManager.getUsbStorageDeviceAccessPolicy(null)
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getUsbStoragePolicy failed: ${JSON.stringify(err)}`)
      return usbManager.UsbPolicy.READ_WRITE
    }
  }

  // ========== USB 白名单 (按 VID/PID) ==========

  // 添加 USB 设备到白名单
  static addUsbWhitelist(devices: usbManager.UsbDeviceId[]): boolean {
    try {
      usbManager.addAllowedUsbDevices(null, devices)
      hilog.info(DOMAIN, TAG, `addUsbWhitelist: ${devices.length} devices`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `addUsbWhitelist failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 从白名单移除 USB 设备
  static removeUsbWhitelist(devices: usbManager.UsbDeviceId[]): boolean {
    try {
      usbManager.removeAllowedUsbDevices(null, devices)
      hilog.info(DOMAIN, TAG, `removeUsbWhitelist: ${devices.length} devices`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `removeUsbWhitelist failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取 USB 白名单
  static getUsbWhitelist(): usbManager.UsbDeviceId[] {
    try {
      return usbManager.getAllowedUsbDevices(null)
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getUsbWhitelist failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  // ========== USB 黑名单 (按设备类型) ==========

  // 添加 USB 设备类型到黑名单
  static addUsbBlacklist(types: usbManager.UsbDeviceType[]): boolean {
    try {
      usbManager.addDisallowedUsbDevices(null, types)
      hilog.info(DOMAIN, TAG, `addUsbBlacklist: ${types.length} types`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `addUsbBlacklist failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 从黑名单移除 USB 设备类型
  static removeUsbBlacklist(types: usbManager.UsbDeviceType[]): boolean {
    try {
      usbManager.removeDisallowedUsbDevices(null, types)
      hilog.info(DOMAIN, TAG, `removeUsbBlacklist: ${types.length} types`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `removeUsbBlacklist failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取 USB 黑名单
  static getUsbBlacklist(): usbManager.UsbDeviceType[] {
    try {
      return usbManager.getDisallowedUsbDevices(null)
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getUsbBlacklist failed: ${JSON.stringify(err)}`)
      return []
    }
  }

  // ========== 蓝牙白名单 (按 MAC 地址) ==========

  // 添加蓝牙设备到白名单
  static addBluetoothWhitelist(deviceIds: string[]): boolean {
    try {
      bluetoothManager.addAllowedBluetoothDevices(null, deviceIds)
      hilog.info(DOMAIN, TAG, `addBluetoothWhitelist: ${deviceIds.length} devices`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `addBluetoothWhitelist failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 从白名单移除蓝牙设备
  static removeBluetoothWhitelist(deviceIds: string[]): boolean {
    try {
      bluetoothManager.removeAllowedBluetoothDevices(null, deviceIds)
      hilog.info(DOMAIN, TAG, `removeBluetoothWhitelist: ${deviceIds.length} devices`)
      return true
    } catch (err) {
      hilog.error(DOMAIN, TAG, `removeBluetoothWhitelist failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  // 获取蓝牙白名单
  static getBluetoothWhitelist(): string[] {
    try {
      return bluetoothManager.getAllowedBluetoothDevices(null)
    } catch (err) {
      hilog.error(DOMAIN, TAG, `getBluetoothWhitelist failed: ${JSON.stringify(err)}`)
      return []
    }
  }
}

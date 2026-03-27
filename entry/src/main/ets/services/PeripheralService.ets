import restrictions from '@ohos.enterprise.restrictions'
import { usbManager } from '@kit.MDMKit'
import { bluetoothManager } from '@kit.MDMKit'
import { networkManager } from '@kit.MDMKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Want } from '@kit.AbilityKit'
import { AppInfo } from '../constants/AppConstants'
import { OperationResult, PeripheralType, inferUsbBaseClass } from '../models/DataModels'
import { EnterpriseAdminService } from './EnterpriseAdminService'
import { CommonErrorUtils } from '../utils/CommonErrorUtils'

const TAG = 'PeripheralService'
const DOMAIN = 0x0002

// 企业管理员 Want 对象
const ADMIN_WANT: Want = {
  bundleName: AppInfo.BUNDLE_NAME,
  abilityName: 'EnterpriseAdminAbility'
}

interface UsbConflictSnapshot {
  whitelist: usbManager.UsbDeviceId[]
  blacklist: usbManager.UsbDeviceType[]
  storagePolicy: usbManager.UsbPolicy
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
  static readonly USB_DEVICE_POLICY_ALLOW: string = 'allow'
  static readonly USB_DEVICE_POLICY_DENY: string = 'deny'

  // ========== 接口管控 (restrictions) ==========

  static setInterfaceDisabledWithResult(feature: string, disallow: boolean): OperationResult<void> {
    if (feature === PeripheralService.FEATURE_NETWORK) {
      return PeripheralService.setNetworkInterfaceDisabledWithResult(disallow)
    }

    if (feature === PeripheralService.FEATURE_USB) {
      return PeripheralService.setUsbInterfaceDisabledWithCleanup(disallow)
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

  static switchUsbDevicePolicyWithResult(
    device: usbManager.UsbDeviceId,
    peripheralType: PeripheralType,
    targetPolicy: string
  ): OperationResult<void> {
    let deviceKey = `${device.vendorId.toString(16)}:${device.productId.toString(16)}`
    hilog.info(DOMAIN, TAG,
      `switchUsbDevicePolicy start: device=${deviceKey}, peripheralType=${peripheralType}, target=${targetPolicy}`)

    let usbDisabledResult = PeripheralService.getInterfaceDisabledWithResult(PeripheralService.FEATURE_USB)
    if (!usbDisabledResult.success) {
      hilog.error(DOMAIN, TAG, `switchUsbDevicePolicy failed at read_usb_status: device=${deviceKey}`)
      return PeripheralService.copyFailureAsVoid(usbDisabledResult, 'read_usb_status')
    }

    let usbDisabled = usbDisabledResult.data ?? false
    let storagePolicyResult = PeripheralService.getUsbStoragePolicyWithResult()
    if (!storagePolicyResult.success) {
      hilog.error(DOMAIN, TAG, `switchUsbDevicePolicy failed at read_usb_storage_policy: device=${deviceKey}`)
      return PeripheralService.copyFailureAsVoid(storagePolicyResult, 'read_usb_storage_policy')
    }

    let storagePolicy = storagePolicyResult.data ?? usbManager.UsbPolicy.READ_WRITE
    let whitelistResult = PeripheralService.getUsbWhitelistWithResult()
    if (!whitelistResult.success) {
      hilog.error(DOMAIN, TAG, `switchUsbDevicePolicy failed at read_usb_whitelist: device=${deviceKey}`)
      return PeripheralService.copyFailureAsVoid(whitelistResult, 'read_usb_whitelist')
    }

    let blacklistResult = PeripheralService.getUsbBlacklistWithResult()
    if (!blacklistResult.success) {
      hilog.error(DOMAIN, TAG, `switchUsbDevicePolicy failed at read_usb_blacklist: device=${deviceKey}`)
      return PeripheralService.copyFailureAsVoid(blacklistResult, 'read_usb_blacklist')
    }

    let whitelist = whitelistResult.data ?? []
    let blacklist = blacklistResult.data ?? []
    let isWhitelisted = whitelist.some((item: usbManager.UsbDeviceId) => {
      return item.vendorId === device.vendorId && item.productId === device.productId
    })
    let baseClass = inferUsbBaseClass(peripheralType)
    let matchedBlacklist = blacklist.filter((item: usbManager.UsbDeviceType) => {
      return baseClass > 0 && item.baseClass === baseClass
    })

    hilog.info(DOMAIN, TAG,
      `switchUsbDevicePolicy precheck: device=${deviceKey}, usbDisabled=${usbDisabled}, storagePolicy=${storagePolicy}, whitelisted=${isWhitelisted}, matchedBlacklist=${matchedBlacklist.length}`)

    if (targetPolicy === PeripheralService.USB_DEVICE_POLICY_ALLOW) {
      if (usbDisabled) {
        hilog.warn(DOMAIN, TAG, `switchUsbDevicePolicy blocked by global usb disable: device=${deviceKey}`)
        return PeripheralService.buildUserFailureResult<void>(
          'read_usb_status',
          '当前 USB 功能已被全局禁用，无法设置为允许接入'
        )
      }
      if (peripheralType === PeripheralType.USB_STORAGE && storagePolicy === usbManager.UsbPolicy.DISABLED) {
        hilog.warn(DOMAIN, TAG, `switchUsbDevicePolicy blocked by usb storage disabled: device=${deviceKey}`)
        return PeripheralService.buildUserFailureResult<void>(
          'read_usb_storage_policy',
          '当前 USB 存储设备访问已被禁用，无法设置为允许接入'
        )
      }

      if (matchedBlacklist.length > 0) {
        hilog.info(DOMAIN, TAG, `switchUsbDevicePolicy removing blacklist: device=${deviceKey}, count=${matchedBlacklist.length}`)
        let removeBlackResult = PeripheralService.removeUsbBlacklistWithResult(matchedBlacklist)
        if (!removeBlackResult.success) {
          hilog.error(DOMAIN, TAG, `switchUsbDevicePolicy failed at remove_blacklist: device=${deviceKey}`)
          return PeripheralService.decorateUserFailure(
            removeBlackResult,
            'remove_blacklist',
            '当前设备禁止访问策略清理失败，请稍后重试'
          )
        }
        blacklist = blacklist.filter((item: usbManager.UsbDeviceType) => {
          return matchedBlacklist.findIndex((matched: usbManager.UsbDeviceType) => {
            return matched.baseClass === item.baseClass &&
              matched.subClass === item.subClass &&
              matched.protocol === item.protocol
          }) < 0
        })
      }

      if (blacklist.length > 0) {
        hilog.warn(DOMAIN, TAG, `switchUsbDevicePolicy blocked by remaining blacklist entries: device=${deviceKey}, count=${blacklist.length}`)
        return PeripheralService.buildUserFailureResult<void>(
          'precheck_blacklist_conflict',
          '当前已存在其他 USB 禁止访问策略，请先清理后再设置允许接入'
        )
      }

      hilog.info(DOMAIN, TAG, `switchUsbDevicePolicy adding whitelist: device=${deviceKey}`)
      let addWhiteResult = PeripheralService.addUsbWhitelistWithResult([device])
      if (!addWhiteResult.success) {
        hilog.error(DOMAIN, TAG, `switchUsbDevicePolicy failed at add_whitelist: device=${deviceKey}`)
        return PeripheralService.decoratePolicyConflictResult(
          addWhiteResult,
          'add_whitelist',
          '当前设备无法设置为允许接入，请先检查 USB 全局策略或设备限制策略'
        )
      }

      hilog.info(DOMAIN, TAG, `switchUsbDevicePolicy success: device=${deviceKey}, target=allow`)
      return {
        success: true,
        userMessage: '设备访问策略已更新为允许接入',
        stage: 'completed'
      } as OperationResult<void>
    }

    if (usbDisabled) {
      hilog.warn(DOMAIN, TAG, `switchUsbDevicePolicy blocked by global usb disable: device=${deviceKey}`)
      return PeripheralService.buildUserFailureResult<void>(
        'read_usb_status',
        '当前 USB 功能已被全局禁用，无法设置为禁止访问'
      )
    }

    if (isWhitelisted) {
      hilog.info(DOMAIN, TAG, `switchUsbDevicePolicy removing whitelist: device=${deviceKey}`)
      let removeWhiteResult = PeripheralService.removeUsbWhitelistWithResult([device])
      if (!removeWhiteResult.success) {
        hilog.error(DOMAIN, TAG, `switchUsbDevicePolicy failed at remove_whitelist: device=${deviceKey}`)
        return PeripheralService.decorateUserFailure(
          removeWhiteResult,
          'remove_whitelist',
          '当前设备允许接入策略清理失败，请稍后重试'
        )
      }
      whitelist = whitelist.filter((item: usbManager.UsbDeviceId) => {
        return !(item.vendorId === device.vendorId && item.productId === device.productId)
      })
    }

    if (whitelist.length > 0) {
      hilog.warn(DOMAIN, TAG, `switchUsbDevicePolicy blocked by remaining whitelist entries: device=${deviceKey}, count=${whitelist.length}`)
      return PeripheralService.buildUserFailureResult<void>(
        'precheck_whitelist_conflict',
        '当前已存在其他 USB 允许接入策略，请先清理后再设置禁止访问'
      )
    }

    if (baseClass <= 0) {
      hilog.warn(DOMAIN, TAG, `switchUsbDevicePolicy unsupported deny target: device=${deviceKey}, peripheralType=${peripheralType}`)
      return PeripheralService.buildUserFailureResult<void>(
        'infer_blacklist_type',
        '当前设备类型暂不支持设置为禁止访问'
      )
    }

    hilog.info(DOMAIN, TAG, `switchUsbDevicePolicy adding blacklist: device=${deviceKey}, baseClass=${baseClass}`)
    let addBlackResult = PeripheralService.addUsbBlacklistWithResult([{
      baseClass: baseClass,
      subClass: 0,
      protocol: 0,
      descriptor: usbManager.Descriptor.INTERFACE
    }])
    if (!addBlackResult.success) {
      hilog.error(DOMAIN, TAG, `switchUsbDevicePolicy failed at add_blacklist: device=${deviceKey}`)
      return PeripheralService.decoratePolicyConflictResult(
        addBlackResult,
        'add_blacklist',
        '当前设备无法设置为禁止访问，请先检查 USB 全局策略或设备限制策略'
      )
    }

    hilog.info(DOMAIN, TAG, `switchUsbDevicePolicy success: device=${deviceKey}, target=deny`)
    return {
      success: true,
      userMessage: '设备访问策略已更新为禁止访问',
      stage: 'completed'
    } as OperationResult<void>
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
      hilog.error(DOMAIN, TAG, `setBluetoothPolicy failed: ${JSON.stringify(err)}`)
      if (CommonErrorUtils.extractErrorCode(err as Object) === 9200010) {
        return PeripheralService.buildUserFailureResult<void>(
          'set_usb_storage_policy',
          '系统检测到仍存在 USB 冲突规则，暂时无法完成存储策略设置，请稍后重试'
        )
      }
      return PeripheralService.buildFailureResult<void>('设置 USB 存储策略失败', err as Object)
    }
  }

  private static getUsbConflictSnapshot(): OperationResult<UsbConflictSnapshot> {
    let whitelistResult = PeripheralService.getUsbWhitelistWithResult()
    if (!whitelistResult.success) {
      return {
        success: false,
        errorCode: whitelistResult.errorCode,
        errorMessage: whitelistResult.errorMessage,
        userMessage: '读取 USB 白名单失败，请稍后重试',
        suggestion: whitelistResult.suggestion,
        isAdminMissing: whitelistResult.isAdminMissing,
        stage: 'read_usb_whitelist'
      } as OperationResult<UsbConflictSnapshot>
    }

    let blacklistResult = PeripheralService.getUsbBlacklistWithResult()
    if (!blacklistResult.success) {
      return {
        success: false,
        errorCode: blacklistResult.errorCode,
        errorMessage: blacklistResult.errorMessage,
        userMessage: '读取 USB 黑名单失败，请稍后重试',
        suggestion: blacklistResult.suggestion,
        isAdminMissing: blacklistResult.isAdminMissing,
        stage: 'read_usb_blacklist'
      } as OperationResult<UsbConflictSnapshot>
    }

    let storagePolicyResult = PeripheralService.getUsbStoragePolicyWithResult()
    if (!storagePolicyResult.success) {
      return {
        success: false,
        errorCode: storagePolicyResult.errorCode,
        errorMessage: storagePolicyResult.errorMessage,
        userMessage: '读取 USB 存储策略失败，请稍后重试',
        suggestion: storagePolicyResult.suggestion,
        isAdminMissing: storagePolicyResult.isAdminMissing,
        stage: 'read_usb_storage_policy'
      } as OperationResult<UsbConflictSnapshot>
    }

    const snapshot: UsbConflictSnapshot = {
      whitelist: whitelistResult.data ?? [],
      blacklist: blacklistResult.data ?? [],
      storagePolicy: storagePolicyResult.data ?? usbManager.UsbPolicy.READ_WRITE
    }
    return {
      success: true,
      data: snapshot
    } as OperationResult<UsbConflictSnapshot>
  }

  private static clearUsbPolicyConflicts(
    resetStoragePolicy: boolean,
    snapshot: UsbConflictSnapshot
  ): OperationResult<void> {
    hilog.warn(DOMAIN, TAG,
      `clearUsbPolicyConflicts start: resetStoragePolicy=${resetStoragePolicy}, whitelist=${snapshot.whitelist.length}, blacklist=${snapshot.blacklist.length}, storagePolicy=${snapshot.storagePolicy}`)

    if (snapshot.whitelist.length > 0) {
      hilog.info(DOMAIN, TAG, `clearUsbPolicyConflicts clearing whitelist: count=${snapshot.whitelist.length}`)
      let clearWhitelistResult = PeripheralService.removeUsbWhitelistWithResult(snapshot.whitelist)
      if (!clearWhitelistResult.success) {
        hilog.error(DOMAIN, TAG, 'clearUsbPolicyConflicts failed at clear_whitelist')
        return PeripheralService.decorateUserFailure(
          clearWhitelistResult,
          'clear_usb_whitelist',
          '系统检测到 USB 白名单冲突，但自动清理未完成，请稍后重试'
        )
      }
    }

    if (snapshot.blacklist.length > 0) {
      hilog.info(DOMAIN, TAG, `clearUsbPolicyConflicts clearing blacklist: count=${snapshot.blacklist.length}`)
      let clearBlacklistResult = PeripheralService.removeUsbBlacklistWithResult(snapshot.blacklist)
      if (!clearBlacklistResult.success) {
        hilog.error(DOMAIN, TAG, 'clearUsbPolicyConflicts failed at clear_blacklist')
        return PeripheralService.decorateUserFailure(
          clearBlacklistResult,
          'clear_usb_blacklist',
          '系统检测到 USB 黑名单冲突，但自动清理未完成，请稍后重试'
        )
      }
    }

    if (resetStoragePolicy && snapshot.storagePolicy !== usbManager.UsbPolicy.READ_WRITE) {
      hilog.info(DOMAIN, TAG, `clearUsbPolicyConflicts resetting storage policy from ${snapshot.storagePolicy} to ${usbManager.UsbPolicy.READ_WRITE}`)
      try {
        usbManager.setUsbStorageDeviceAccessPolicy(ADMIN_WANT, usbManager.UsbPolicy.READ_WRITE)
      } catch (err) {
        hilog.error(DOMAIN, TAG, `clearUsbPolicyConflicts failed at reset_storage_policy: ${JSON.stringify(err)}`)
        return PeripheralService.buildUserFailureResult<void>(
          'reset_usb_storage_policy',
          '系统检测到 USB 存储策略冲突，但自动恢复为读写失败，请稍后重试'
        )
      }
    }

    hilog.info(DOMAIN, TAG, 'clearUsbPolicyConflicts success')
    return {
      success: true,
      stage: 'cleanup_completed'
    } as OperationResult<void>
  }

  private static buildFailureResult<T>(action: string, err: Object, fallbackData?: T): OperationResult<T> {
    let code = CommonErrorUtils.extractErrorCode(err)
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

  private static buildUserFailureResult<T>(stage: string, userMessage: string, fallbackData?: T): OperationResult<T> {
    return {
      success: false,
      data: fallbackData,
      userMessage: userMessage,
      errorMessage: userMessage,
      stage: stage
    } as OperationResult<T>
  }

  private static decorateUserFailure<T>(
    result: OperationResult<T>,
    stage: string,
    userMessage: string
  ): OperationResult<T> {
    return {
      success: result.success,
      data: result.data,
      errorCode: result.errorCode,
      errorMessage: result.errorMessage,
      isAdminMissing: result.isAdminMissing,
      suggestion: result.suggestion,
      userMessage: userMessage,
      stage: stage
    } as OperationResult<T>
  }

  private static decoratePolicyConflictResult<T>(
    result: OperationResult<T>,
    stage: string,
    userMessage: string
  ): OperationResult<T> {
    if (result.errorCode === 9200010) {
      return {
        success: result.success,
        data: result.data,
        errorCode: result.errorCode,
        errorMessage: result.errorMessage,
        isAdminMissing: result.isAdminMissing,
        suggestion: result.suggestion,
        userMessage: userMessage,
        stage: stage
      } as OperationResult<T>
    }
    return PeripheralService.decorateUserFailure(result, stage, '当前设备策略更新失败，请稍后重试')
  }

  private static copyFailureAsVoid<T>(result: OperationResult<T>, stage: string): OperationResult<void> {
    return {
      success: result.success,
      errorCode: result.errorCode,
      errorMessage: result.errorMessage,
      userMessage: result.userMessage,
      isAdminMissing: result.isAdminMissing,
      suggestion: result.suggestion,
      stage: stage
    } as OperationResult<void>
  }
}

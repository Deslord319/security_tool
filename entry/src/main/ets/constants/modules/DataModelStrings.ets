import { SharedLabels } from './FirewallSharedLabels'
import { DeviceTypeLabels, FirewallDialogStrings, ResultStrings } from './DialogStrings'

export class DataModelStrings {
  static readonly actionAllow: string = FirewallDialogStrings.ACTION_ALLOW
  static readonly actionDeny: string = '拒绝'
  static readonly unknown: string = SharedLabels.LABEL_UNKNOWN

  static readonly peripheralUsbStorage: string = DeviceTypeLabels.USB_STORAGE
  static readonly peripheralUsbCamera: string = DeviceTypeLabels.USB_CAMERA
  static readonly peripheralUsbPrinter: string = DeviceTypeLabels.USB_PRINTER
  static readonly peripheralUsbHid: string = DeviceTypeLabels.USB_HID
  static readonly peripheralUsbOther: string = 'USB 其他'
  static readonly peripheralBluetooth: string = '蓝牙设备'

  static readonly usbStorageReadWrite: string = '读写'
  static readonly usbStorageReadOnly: string = '只读'
  static readonly usbStorageDisabled: string = '禁止访问'

  static readonly sourceRuntimeEvent: string = '运行时事件'
  static readonly sourceAuditEvent: string = '审计事件'
  static readonly sourcePolicySnapshot: string = '策略快照'
  static readonly sourceUnknown: string = '未知来源'

  static readonly recordActionConnect: string = '连接'
  static readonly recordActionDisconnect: string = '断开'
  static readonly recordActionDiscover: string = '发现'
  static readonly recordActionIntercept: string = '拦截'
  static readonly recordActionUnknown: string = '未知动作'

  static readonly policyHitAllow: string = FirewallDialogStrings.ACTION_ALLOW
  static readonly policyHitDeny: string = FirewallDialogStrings.ACTION_DENY
  static readonly policyHitUnknown: string = SharedLabels.LABEL_UNKNOWN
  static readonly policyCurrentConnection: string = '当前连接'

  static readonly logEventCrash: string = '崩溃日志'
  static readonly logEventFile: string = '文件操作'
  static readonly logEventAccount: string = '用户认证'
  static readonly logEventPermission: string = '权限变更'

  static readonly logResultSuccess: string = ResultStrings.SUCCESS
  static readonly logResultBlocked: string = '已阻止'
  static readonly logResultFailed: string = ResultStrings.FAILED
}

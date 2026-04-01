import { DeviceTypeLabels, FirewallDialogStrings, ResultStrings } from './DialogStrings'

export class DataModelStrings {
  static readonly actionDeny: string = '拒绝'

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

  static readonly policyCurrentConnection: string = '当前连接'

  static readonly logEventCrash: string = '崩溃日志'
  static readonly logEventFile: string = '文件操作'
  static readonly logEventAccount: string = '用户认证'
  static readonly logEventPermission: string = '权限变更'

  static readonly logResultBlocked: string = '已阻止'
}

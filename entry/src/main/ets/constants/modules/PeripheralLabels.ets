/**
 * 外设管理 UI 标签常量
 * 
 * 统一管理外设管理模块中的 UI 标签，包括：
 * - 表格表头
 * - 空状态提示
 * - 操作按钮
 * - 策略标签
 */

// ==================== 设备列表表头 ====================
export class DeviceListHeaders {
  static readonly DEVICE_NAME: string = '设备名称'
  static readonly DEVICE_TYPE: string = '设备类型'
  static readonly CONNECTION_EVENT: string = '连接事件'
  static readonly POLICY: string = '策略'
  static readonly CONNECTION_TIME: string = '连接时间'
  static readonly ACTION: string = '操作'
  static readonly CURRENT_POLICY: string = '当前策略'
  static readonly RECENT_CONNECTION_TIME: string = '最近连接时间'
}

// ==================== 空状态提示 ====================
export class DeviceEmptyStates {
  // 设备连接记录
  static readonly NO_DEVICE_RECORDS: string = '暂无设备连接记录'
  static readonly DEVICE_RECORDS_EMPTY_DESC: string = '重新连接设备后，可在这里查看最新的接入历史。'
  
  // USB 设备策略
  static readonly NO_MANAGEABLE_USB_DEVICES: string = '暂无可管理的 USB 设备记录'
  static readonly USB_DEVICES_EMPTY_DESC: string = '设备接入后会显示在这里，可直接设置允许接入或禁止访问。'
}

// ==================== 操作按钮 ====================
export class DeviceActionButtons {
  static readonly DETAIL: string = '详情'
  static readonly ALLOW: string = '允许'
  static readonly DENY: string = '禁止'
  static readonly READ_ONLY: string = '只读'
  static readonly READ_WRITE: string = '读写'
}

// ==================== USB 策略标签 ====================
export class UsbPolicyLabels {
  static readonly USB_STORAGE_DEVICE: string = 'USB 存储设备'
  static readonly USB_STORAGE_DESCRIPTION: string = '设置 USB 存储设备的访问权限，可选只读、读写或禁止访问。'
}

// ==================== USB 策略结果标签 ====================
export class UsbPolicyResultLabels {
  static readonly USB_DISABLED: string = 'USB 接口禁用'
  static readonly USB_STORAGE_DISABLED: string = 'USB 存储已禁用'
  static readonly USB_STORAGE_READ_ONLY: string = 'USB 存储只读'
  static readonly DEVICE_DENY: string = '命中单设备禁止接入'
  static readonly DEFAULT_ALLOW: string = '默认允许接入'
  static readonly DISCONNECT_EVENT: string = '断开事件'
  static readonly UNSAUDITED: string = '待判定'
  static readonly SNAPSHOT: string = '快照'
}

// ==================== 连接策略标签 ====================
export class ConnectionPolicyLabels {
  static readonly SNAPSHOT_LABEL: string = '快照'
}

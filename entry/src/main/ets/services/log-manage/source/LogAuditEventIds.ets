import { securityAudit } from '@kit.DeviceSecurityKit'
import { LogEventType } from '../../../models/LogModels'
import {
  DEVICE_POWER_AUDIT_EVENT_IDS,
  DEVICE_POWER_OFF_AUDIT_EVENT_ID,
  DEVICE_POWER_ON_AUDIT_EVENT_ID
} from '../../../constants/modules/LogAuditEventConstants'

export { DEVICE_POWER_OFF_AUDIT_EVENT_ID, DEVICE_POWER_ON_AUDIT_EVENT_ID }

interface AuditEventDefinition {
  eventId: number
  description: string
}

const API26_FILE_AUDIT_EVENT_DEFINITIONS: AuditEventDefinition[] = [
  { eventId: securityAudit.NotifyEvent.FILE_CREATE, description: 'FILE_CREATE：文件创建事件' },
  { eventId: securityAudit.NotifyEvent.FILE_OPEN, description: 'FILE_OPEN：文件打开事件' },
  { eventId: securityAudit.NotifyEvent.FILE_CLOSE, description: 'FILE_CLOSE：文件关闭事件' },
  { eventId: securityAudit.NotifyEvent.FILE_DELETE, description: 'FILE_DELETE：文件删除事件' },
  { eventId: securityAudit.NotifyEvent.FILE_RENAME, description: 'FILE_RENAME：文件重命名事件' },
  { eventId: securityAudit.NotifyEvent.FILE_COPY, description: 'FILE_COPY：文件复制事件' },
  { eventId: securityAudit.NotifyEvent.FILE_SETOWNER, description: 'FILE_SETOWNER：文件属主或属组变更事件' },
  { eventId: securityAudit.NotifyEvent.FILE_SETMODE, description: 'FILE_SETMODE：文件权限模式变更事件' },
  { eventId: securityAudit.NotifyEvent.FILE_SETEXTATTR, description: 'FILE_SETEXTATTR：设置文件扩展属性事件' },
  { eventId: securityAudit.NotifyEvent.FILE_DELETEEXTATTR, description: 'FILE_DELETEEXTATTR：删除文件扩展属性事件' },
  { eventId: securityAudit.NotifyEvent.FILE_WRITE, description: 'FILE_WRITE：文件写入事件' }
]

export const API26_FILE_AUDIT_EVENT_IDS: number[] = toEventIds(API26_FILE_AUDIT_EVENT_DEFINITIONS)
export const FILE_AUDIT_EVENT_DESCRIPTIONS_BY_ID: Map<number, string> =
  toDescriptionMap(API26_FILE_AUDIT_EVENT_DEFINITIONS)

export const FILE_AUDIT_EVENT_IDS: number[] = [
  securityAudit.NotifyEvent.FILE,
  securityAudit.NotifyEvent.FILE_INTERCEPTED,
  securityAudit.NotifyEvent.KIA_CREATE,
  securityAudit.NotifyEvent.KIA_READ,
  securityAudit.NotifyEvent.KIA_VARIANT,
  securityAudit.NotifyEvent.KIA_INTERCEPT,
  securityAudit.NotifyEvent.KIA_PRE_OPEN,
  ...API26_FILE_AUDIT_EVENT_IDS
]

export const AUTH_AUDIT_EVENT_IDS: number[] = [
  securityAudit.NotifyEvent.ACCOUNT
]

export const CRASH_AUDIT_EVENT_IDS: number[] = [
  securityAudit.NotifyEvent.PROCESS_CRASH_ABNORMAL
]

export const POWER_AUDIT_EVENT_IDS: number[] = DEVICE_POWER_AUDIT_EVENT_IDS

export const POWER_AUDIT_EVENT_DESCRIPTIONS_BY_ID: Map<number, string> = new Map<number, string>([
  [DEVICE_POWER_ON_AUDIT_EVENT_ID, '设备启动'],
  [DEVICE_POWER_OFF_AUDIT_EVENT_ID, '设备关闭']
])

const AUDIT_EVENT_DEFINITIONS: AuditEventDefinition[] = [
  { eventId: securityAudit.NotifyEvent.DNS, description: 'DNS 审计事件' },
  { eventId: securityAudit.NotifyEvent.NETWORK_INTERCEPTED, description: '网络访问拦截事件' },
  { eventId: securityAudit.NotifyEvent.WIFI_INTERCEPTED, description: 'Wi-Fi 访问拦截事件' },
  { eventId: securityAudit.NotifyEvent.WINDOW, description: '截屏、录屏或投屏事件' },
  { eventId: securityAudit.NotifyEvent.VOLUME, description: '可移除存储插入或移除事件' },
  { eventId: securityAudit.NotifyEvent.SMB_FILE_SEND, description: 'SMB 文件传输事件' },
  { eventId: securityAudit.NotifyEvent.FILE_SHARE, description: '文件分享事件' },
  { eventId: securityAudit.NotifyEvent.DATA_DRAG, description: '数据拖拽事件' },
  { eventId: securityAudit.NotifyEvent.DLP_FILE_ACCESS, description: 'DLP 文件访问事件' },
  { eventId: securityAudit.NotifyEvent.APP, description: '应用程序事件' },
  { eventId: securityAudit.NotifyEvent.EDM, description: '企业设备管理事件' },
  { eventId: securityAudit.NotifyEvent.CS_VERIFY_NULL, description: '未签名代码事件' },
  { eventId: securityAudit.NotifyEvent.CS_VERIFY_ABNORMAL, description: '代码签名校验异常事件' },
  { eventId: securityAudit.NotifyEvent.CERT, description: '证书操作事件' },
  { eventId: securityAudit.NotifyEvent.APP_INSTALL_INTERCEPTED, description: '应用安装拦截事件' },
  { eventId: securityAudit.NotifyEvent.APP_UNINSTALL_INTERCEPTED, description: '应用卸载拦截事件' },
  { eventId: securityAudit.NotifyEvent.APP_UPDATE_INTERCEPTED, description: '应用更新拦截事件' },
  { eventId: securityAudit.NotifyEvent.APP_RECOVER_INTERCEPTED, description: '应用恢复拦截事件' },
  { eventId: securityAudit.NotifyEvent.APP_START_INTERCEPTED, description: '应用启动拦截事件' },
  { eventId: securityAudit.NotifyEvent.PROCESS, description: '进程创建或退出事件' },
  { eventId: securityAudit.NotifyEvent.FS_MOUNT_ABNORMAL, description: '文件系统挂载异常事件' },
  { eventId: securityAudit.NotifyEvent.DRIVER_CS_ABNORMAL, description: '驱动代码签名校验异常事件' },
  { eventId: securityAudit.NotifyEvent.DRIVER_MMAP_ABNORMAL, description: '内核内存映射异常事件' },
  { eventId: securityAudit.NotifyEvent.KERNEL_MEMORY_ABNORMAL, description: '内核内存使用异常事件' },
  { eventId: securityAudit.NotifyEvent.PROCESS_DEBUG_ABNORMAL, description: '进程调试异常事件' },
  { eventId: securityAudit.NotifyEvent.PROCESS_PRIVILEGE_ESCALATION, description: '进程权限提升事件' },
  { eventId: securityAudit.NotifyEvent.PASTEBOARD, description: '剪贴板复制或粘贴事件' },
  { eventId: securityAudit.NotifyEvent.HDC_DEBUG, description: 'HDC 调试事件' },
  { eventId: securityAudit.NotifyEvent.HDC_DEBUG_INTERCEPTED, description: 'HDC 调试拦截事件' },
  { eventId: securityAudit.NotifyEvent.CAMERA, description: '摄像头事件' },
  { eventId: securityAudit.NotifyEvent.PRINTER, description: '打印机事件' },
  { eventId: securityAudit.NotifyEvent.PRINT_INTERCEPTED, description: '打印拦截事件' },
  { eventId: securityAudit.NotifyEvent.USER_SPACE_DATA_TRANSFER, description: '多用户空间数据交换事件' },
  { eventId: securityAudit.NotifyEvent.USER_SPACE_DATA_TRANSFER_POLICY, description: '多用户空间数据交换策略事件' },
  { eventId: securityAudit.NotifyEvent.USB_ACCESS_INTERCEPTED, description: 'USB 访问拦截事件' },
  { eventId: securityAudit.NotifyEvent.SERIAL_PORT_ACCESS, description: '串口访问事件' }
]

export const AUDIT_LOG_EVENT_IDS: number[] = toEventIds(AUDIT_EVENT_DEFINITIONS)
export const AUDIT_EVENT_DESCRIPTIONS_BY_ID: Map<number, string> = toDescriptionMap(AUDIT_EVENT_DEFINITIONS)

export const AUDIT_EVENT_TYPES_BY_ID: Map<number, LogEventType> = new Map<number, LogEventType>()

function registerEventTypes(eventIds: number[], eventType: LogEventType): void {
  for (let eventId of eventIds) {
    AUDIT_EVENT_TYPES_BY_ID.set(eventId, eventType)
  }
}

function toEventIds(definitions: AuditEventDefinition[]): number[] {
  return definitions.map((definition: AuditEventDefinition): number => definition.eventId)
}

function toDescriptionMap(definitions: AuditEventDefinition[]): Map<number, string> {
  let result: Map<number, string> = new Map<number, string>()
  for (const definition of definitions) {
    result.set(definition.eventId, definition.description)
  }
  return result
}

registerEventTypes(FILE_AUDIT_EVENT_IDS, LogEventType.FILE)
registerEventTypes(AUTH_AUDIT_EVENT_IDS, LogEventType.ACCOUNT)
registerEventTypes(CRASH_AUDIT_EVENT_IDS, LogEventType.CRASH)
registerEventTypes(POWER_AUDIT_EVENT_IDS, LogEventType.POWER)
registerEventTypes([securityAudit.NotifyEvent.PERMISSION], LogEventType.PERMISSION)
registerEventTypes(AUDIT_LOG_EVENT_IDS, LogEventType.AUDIT)

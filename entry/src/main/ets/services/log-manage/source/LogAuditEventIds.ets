import { securityAudit } from '@kit.DeviceSecurityKit'
import { LogEventType } from '../../../models/LogModels'

export const FILE_AUDIT_EVENT_IDS: number[] = [
  securityAudit.NotifyEvent.FILE,
  securityAudit.NotifyEvent.FILE_INTERCEPTED,
  securityAudit.NotifyEvent.KIA_CREATE,
  securityAudit.NotifyEvent.KIA_READ,
  securityAudit.NotifyEvent.KIA_VARIANT,
  securityAudit.NotifyEvent.KIA_INTERCEPT
]

export const AUTH_AUDIT_EVENT_IDS: number[] = [
  securityAudit.NotifyEvent.ACCOUNT,
  0x27000004,
  0x27000005
]

export const CRASH_AUDIT_EVENT_IDS: number[] = [
  0x2700000D,
  0x1C001401
]

export const AUDIT_LOG_EVENT_IDS: number[] = [
  securityAudit.NotifyEvent.PASTEBOARD,
  securityAudit.NotifyEvent.WINDOW,
  securityAudit.NotifyEvent.VOLUME,
  securityAudit.NotifyEvent.PRINTER,
  securityAudit.NotifyEvent.PROCESS,
  securityAudit.NotifyEvent.NETWORK_TRAFFIC,
  securityAudit.NotifyEvent.NETWORK_CONN,
  securityAudit.NotifyEvent.CAMERA,
  securityAudit.NotifyEvent.APP,
  securityAudit.NotifyEvent.EDM,
  securityAudit.NotifyEvent.CERT,
  securityAudit.NotifyEvent.DNS,
  securityAudit.NotifyEvent.APP_INSTALL_INTERCEPTED,
  securityAudit.NotifyEvent.APP_UNINSTALL_INTERCEPTED,
  securityAudit.NotifyEvent.APP_UPDATE_INTERCEPTED,
  securityAudit.NotifyEvent.APP_RECOVER_INTERCEPTED,
  securityAudit.NotifyEvent.APP_START_INTERCEPTED,
  securityAudit.NotifyEvent.USB_ACCESS_INTERCEPTED
]

export const AUDIT_EVENT_DESCRIPTIONS_BY_ID: Map<number, string> = new Map<number, string>([
  [securityAudit.NotifyEvent.PASTEBOARD, '剪贴板复制或粘贴事件'],
  [securityAudit.NotifyEvent.WINDOW, '截屏、录屏或投屏事件'],
  [securityAudit.NotifyEvent.VOLUME, '可移除存储插入或移除事件'],
  [securityAudit.NotifyEvent.PRINTER, '打印机事件'],
  [securityAudit.NotifyEvent.PROCESS, '进程创建或退出事件'],
  [securityAudit.NotifyEvent.NETWORK_TRAFFIC, '网络流量事件'],
  [securityAudit.NotifyEvent.NETWORK_CONN, '网络连接事件'],
  [securityAudit.NotifyEvent.CAMERA, '摄像头事件'],
  [securityAudit.NotifyEvent.APP, '应用程序事件'],
  [securityAudit.NotifyEvent.EDM, '企业设备管理事件'],
  [securityAudit.NotifyEvent.CERT, '证书操作事件'],
  [securityAudit.NotifyEvent.DNS, 'DNS 审计事件'],
  [securityAudit.NotifyEvent.APP_INSTALL_INTERCEPTED, '应用安装拦截事件'],
  [securityAudit.NotifyEvent.APP_UNINSTALL_INTERCEPTED, '应用卸载拦截事件'],
  [securityAudit.NotifyEvent.APP_UPDATE_INTERCEPTED, '应用更新拦截事件'],
  [securityAudit.NotifyEvent.APP_RECOVER_INTERCEPTED, '应用恢复拦截事件'],
  [securityAudit.NotifyEvent.APP_START_INTERCEPTED, '应用启动拦截事件'],
  [securityAudit.NotifyEvent.USB_ACCESS_INTERCEPTED, 'USB 访问拦截事件']
])

export const AUDIT_EVENT_TYPES_BY_ID: Map<number, LogEventType> = new Map<number, LogEventType>([
  [securityAudit.NotifyEvent.FILE, LogEventType.FILE],
  [securityAudit.NotifyEvent.FILE_INTERCEPTED, LogEventType.FILE],
  [securityAudit.NotifyEvent.KIA_CREATE, LogEventType.FILE],
  [securityAudit.NotifyEvent.KIA_READ, LogEventType.FILE],
  [securityAudit.NotifyEvent.KIA_VARIANT, LogEventType.FILE],
  [securityAudit.NotifyEvent.KIA_INTERCEPT, LogEventType.FILE],
  [securityAudit.NotifyEvent.ACCOUNT, LogEventType.ACCOUNT],
  [0x27000004, LogEventType.ACCOUNT],
  [0x27000005, LogEventType.ACCOUNT],
  [0x2700000D, LogEventType.CRASH],
  [0x1C001401, LogEventType.CRASH],
  [securityAudit.NotifyEvent.PERMISSION, LogEventType.PERMISSION],
  [securityAudit.NotifyEvent.PASTEBOARD, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.WINDOW, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.VOLUME, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.PRINTER, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.PROCESS, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.NETWORK_TRAFFIC, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.NETWORK_CONN, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.CAMERA, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.APP, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.EDM, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.CERT, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.DNS, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.APP_INSTALL_INTERCEPTED, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.APP_UNINSTALL_INTERCEPTED, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.APP_UPDATE_INTERCEPTED, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.APP_RECOVER_INTERCEPTED, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.APP_START_INTERCEPTED, LogEventType.AUDIT],
  [securityAudit.NotifyEvent.USB_ACCESS_INTERCEPTED, LogEventType.AUDIT]
])

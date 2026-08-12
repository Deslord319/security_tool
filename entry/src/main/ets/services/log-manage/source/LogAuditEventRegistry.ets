import { securityAudit } from '@kit.DeviceSecurityKit'
import { LogEventType } from '../../../models/LogModels'
import {
  DEVICE_POWER_OFF_AUDIT_EVENT_ID,
  DEVICE_POWER_ON_AUDIT_EVENT_ID
} from '../../../constants/modules/LogAuditEventConstants'

export type AuditParserKind = 'file' | 'account' | 'permission' | 'power' | 'audit' | 'crash'
export type AuditFilterPolicy = 'none' | 'user_file_prefix'

export interface AuditEventDefinition {
  eventId: number
  eventType: LogEventType
  defaultEventKey: string
  parserKind: AuditParserKind
  filterPolicy: AuditFilterPolicy
}
function define(
  eventId: number,
  eventType: LogEventType,
  defaultEventKey: string,
  parserKind: AuditParserKind,
  filterPolicy: AuditFilterPolicy = 'none'
): AuditEventDefinition {
  return { eventId, eventType, defaultEventKey, parserKind, filterPolicy }
}

export const LOG_AUDIT_EVENT_DEFINITIONS: AuditEventDefinition[] = [
  define(securityAudit.NotifyEvent.FILE, LogEventType.FILE, 'file.access', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_INTERCEPTED, LogEventType.FILE, 'file.intercepted', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.KIA_CREATE, LogEventType.FILE, 'file.kia_create', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.KIA_READ, LogEventType.FILE, 'file.kia_read', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.KIA_VARIANT, LogEventType.FILE, 'file.kia_variant', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.KIA_INTERCEPT, LogEventType.FILE, 'file.kia_intercept', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.KIA_PRE_OPEN, LogEventType.FILE, 'file.kia_pre_open', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_CREATE, LogEventType.FILE, 'file.create', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_OPEN, LogEventType.FILE, 'file.open', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_CLOSE, LogEventType.FILE, 'file.close', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_DELETE, LogEventType.FILE, 'file.delete', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_RENAME, LogEventType.FILE, 'file.rename', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_COPY, LogEventType.FILE, 'file.copy', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_SETOWNER, LogEventType.FILE, 'file.owner_change', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_SETMODE, LogEventType.FILE, 'file.mode_change', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_SETEXTATTR, LogEventType.FILE, 'file.xattr_set', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_DELETEEXTATTR, LogEventType.FILE, 'file.xattr_delete', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.FILE_WRITE, LogEventType.FILE, 'file.write', 'file', 'user_file_prefix'),
  define(securityAudit.NotifyEvent.ACCOUNT, LogEventType.ACCOUNT, 'account.authentication', 'account'),
  define(securityAudit.NotifyEvent.PERMISSION, LogEventType.PERMISSION, 'permission.change', 'permission'),
  define(securityAudit.NotifyEvent.PROCESS_CRASH_ABNORMAL, LogEventType.CRASH, 'crash.process_abnormal', 'crash'),
  define(DEVICE_POWER_ON_AUDIT_EVENT_ID, LogEventType.POWER, 'device.power_on', 'power'),
  define(DEVICE_POWER_OFF_AUDIT_EVENT_ID, LogEventType.POWER, 'device.power_off', 'power'),
  define(securityAudit.NotifyEvent.DNS, LogEventType.AUDIT, 'network.dns', 'audit'),
  define(securityAudit.NotifyEvent.NETWORK_INTERCEPTED, LogEventType.AUDIT, 'network.intercepted', 'audit'),
  define(securityAudit.NotifyEvent.WIFI_INTERCEPTED, LogEventType.AUDIT, 'network.wifi_intercepted', 'audit'),
  define(securityAudit.NotifyEvent.WINDOW, LogEventType.AUDIT, 'media.window_capture', 'audit'),
  define(securityAudit.NotifyEvent.VOLUME, LogEventType.AUDIT, 'storage.volume', 'audit'),
  define(securityAudit.NotifyEvent.SMB_FILE_SEND, LogEventType.AUDIT, 'data.smb_send', 'audit'),
  define(securityAudit.NotifyEvent.FILE_SHARE, LogEventType.AUDIT, 'data.file_share', 'audit'),
  define(securityAudit.NotifyEvent.DATA_DRAG, LogEventType.AUDIT, 'data.drag', 'audit'),
  define(securityAudit.NotifyEvent.DLP_FILE_ACCESS, LogEventType.AUDIT, 'data.dlp_access', 'audit'),
  define(securityAudit.NotifyEvent.APP, LogEventType.AUDIT, 'app.lifecycle', 'audit'),
  define(securityAudit.NotifyEvent.EDM, LogEventType.AUDIT, 'edm.policy_operation', 'audit'),
  define(securityAudit.NotifyEvent.CS_VERIFY_NULL, LogEventType.AUDIT, 'security.code_signature_missing', 'audit'),
  define(securityAudit.NotifyEvent.CS_VERIFY_ABNORMAL, LogEventType.AUDIT, 'security.code_signature_abnormal', 'audit'),
  define(securityAudit.NotifyEvent.CERT, LogEventType.AUDIT, 'security.certificate', 'audit'),
  define(securityAudit.NotifyEvent.APP_INSTALL_INTERCEPTED, LogEventType.AUDIT, 'app.install_intercepted', 'audit'),
  define(securityAudit.NotifyEvent.APP_UNINSTALL_INTERCEPTED, LogEventType.AUDIT, 'app.uninstall_intercepted', 'audit'),
  define(securityAudit.NotifyEvent.APP_UPDATE_INTERCEPTED, LogEventType.AUDIT, 'app.update_intercepted', 'audit'),
  define(securityAudit.NotifyEvent.APP_RECOVER_INTERCEPTED, LogEventType.AUDIT, 'app.recover_intercepted', 'audit'),
  define(securityAudit.NotifyEvent.APP_START_INTERCEPTED, LogEventType.AUDIT, 'app.start_intercepted', 'audit'),
  define(securityAudit.NotifyEvent.PROCESS, LogEventType.AUDIT, 'process.lifecycle', 'audit'),
  define(securityAudit.NotifyEvent.FS_MOUNT_ABNORMAL, LogEventType.AUDIT, 'security.fs_mount_abnormal', 'audit'),
  define(securityAudit.NotifyEvent.DRIVER_CS_ABNORMAL, LogEventType.AUDIT, 'security.driver_signature_abnormal', 'audit'),
  define(securityAudit.NotifyEvent.DRIVER_MMAP_ABNORMAL, LogEventType.AUDIT, 'security.driver_mmap_abnormal', 'audit'),
  define(securityAudit.NotifyEvent.KERNEL_MEMORY_ABNORMAL, LogEventType.AUDIT, 'security.kernel_memory_abnormal', 'audit'),
  define(securityAudit.NotifyEvent.PROCESS_DEBUG_ABNORMAL, LogEventType.AUDIT, 'process.debug_abnormal', 'audit'),
  define(securityAudit.NotifyEvent.PROCESS_PRIVILEGE_ESCALATION, LogEventType.AUDIT, 'process.privilege_escalation', 'audit'),
  define(securityAudit.NotifyEvent.PASTEBOARD, LogEventType.AUDIT, 'data.clipboard', 'audit'),
  define(securityAudit.NotifyEvent.HDC_DEBUG, LogEventType.AUDIT, 'debug.hdc', 'audit'),
  define(securityAudit.NotifyEvent.HDC_DEBUG_INTERCEPTED, LogEventType.AUDIT, 'debug.hdc_intercepted', 'audit'),
  define(securityAudit.NotifyEvent.CAMERA, LogEventType.AUDIT, 'device.camera', 'audit'),
  define(securityAudit.NotifyEvent.PRINTER, LogEventType.AUDIT, 'device.printer', 'audit'),
  define(securityAudit.NotifyEvent.PRINT_INTERCEPTED, LogEventType.AUDIT, 'device.print_intercepted', 'audit'),
  define(securityAudit.NotifyEvent.USER_SPACE_DATA_TRANSFER, LogEventType.AUDIT, 'data.user_space_transfer', 'audit'),
  define(securityAudit.NotifyEvent.USER_SPACE_DATA_TRANSFER_POLICY, LogEventType.AUDIT, 'data.user_space_transfer_policy', 'audit'),
  define(securityAudit.NotifyEvent.USB_ACCESS_INTERCEPTED, LogEventType.AUDIT, 'device.usb_access_intercepted', 'audit'),
  define(securityAudit.NotifyEvent.SERIAL_PORT_ACCESS, LogEventType.AUDIT, 'device.serial_port_access', 'audit')
]

export function findAuditEventDefinition(eventId: number): AuditEventDefinition | undefined {
  return LOG_AUDIT_EVENT_DEFINITIONS.find((definition: AuditEventDefinition): boolean => definition.eventId === eventId)
}

export function getAuditEventIdsByType(eventType: LogEventType): number[] {
  return LOG_AUDIT_EVENT_DEFINITIONS
    .filter((definition: AuditEventDefinition): boolean => definition.eventType === eventType)
    .map((definition: AuditEventDefinition): number => definition.eventId)
}

export function requiresUserFilePrefix(eventId: number): boolean {
  const definition = findAuditEventDefinition(eventId)
  return definition?.filterPolicy === 'user_file_prefix'
}

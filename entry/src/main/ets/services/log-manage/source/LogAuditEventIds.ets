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
  [securityAudit.NotifyEvent.PERMISSION, LogEventType.PERMISSION]
])

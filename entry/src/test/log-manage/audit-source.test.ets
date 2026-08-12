import { describe, expect, it } from '@ohos/hypium'
import { securityAudit } from '@kit.DeviceSecurityKit'
import { LogEntry, LogEventType, LogField } from '../../main/ets/models/LogModels'
import {
  DEVICE_POWER_OFF_AUDIT_EVENT_ID,
  DEVICE_POWER_ON_AUDIT_EVENT_ID
} from '../../main/ets/constants/modules/LogAuditEventConstants'
import { parseAuditEventToLogEntry } from '../../main/ets/services/log-manage/source/LogAuditEventMapper'
import {
  findAuditEventDefinition,
  getAuditEventIdsByType,
  requiresUserFilePrefix
} from '../../main/ets/services/log-manage/source/LogAuditEventRegistry'

function event(eventId: number, content: string, timestamp: string = '20260402120000'): securityAudit.AuditEvent {
  return {
    eventId,
    timestamp,
    userId: 100,
    content,
    metadata: ''
  } as securityAudit.AuditEvent
}

function fieldValue(entry: LogEntry | undefined, key: string): string {
  const value = entry?.fields?.find((item: LogField): boolean => item.key === key)?.value
  return value === undefined ? '' : `${value}`
}

export default function logAuditSourceTest() {
  describe('LogAuditSource', () => {
    it('should keep event subscription metadata in one registry', 0, () => {
      expect(findAuditEventDefinition(securityAudit.NotifyEvent.FILE_OPEN)?.defaultEventKey).assertEqual('file.open')
      expect(requiresUserFilePrefix(securityAudit.NotifyEvent.FILE_OPEN)).assertTrue()
      expect(getAuditEventIdsByType(LogEventType.POWER).includes(DEVICE_POWER_ON_AUDIT_EVENT_ID)).assertTrue()
      expect(getAuditEventIdsByType(LogEventType.POWER).includes(DEVICE_POWER_OFF_AUDIT_EVENT_ID)).assertTrue()
      expect(getAuditEventIdsByType(LogEventType.AUDIT).includes(securityAudit.NotifyEvent.NETWORK_TRAFFIC)).assertFalse()
      expect(getAuditEventIdsByType(LogEventType.AUDIT).includes(securityAudit.NotifyEvent.NETWORK_CONN)).assertFalse()
    })

    it('should structure file rename fields without exposing raw json as detail', 0, () => {
      const entry = parseAuditEventToLogEntry(event(securityAudit.NotifyEvent.FILE_RENAME,
        '{"event_name":"rename","file_oldpath":"/data/storage/el2/base/files/a.txt",' +
        '"file_newpath":"/data/storage/el2/base/files/b.txt","processName":"demo","pid":321,"outcome":"success"}'))

      expect(entry?.eventKey).assertEqual('file.rename')
      expect(fieldValue(entry, 'change.old_path')).assertEqual('/data/storage/el2/base/files/a.txt')
      expect(fieldValue(entry, 'change.new_path')).assertEqual('/data/storage/el2/base/files/b.txt')
      expect(fieldValue(entry, 'event.outcome')).assertEqual('success')
      expect(entry?.detail.includes('{')).assertFalse()
    })

    it('should structure nested dns object info', 0, () => {
      const entry = parseAuditEventToLogEntry(event(securityAudit.NotifyEvent.DNS,
        '{"objectInfo":{"host":"example.com"},"outcome":"allowed"}'))

      expect(entry?.eventKey).assertEqual('network.dns')
      expect(fieldValue(entry, 'object.domain')).assertEqual('example.com')
      expect(fieldValue(entry, 'event.outcome')).assertEqual('allowed')
    })

    it('should distinguish application and process lifecycle events', 0, () => {
      const app = parseAuditEventToLogEntry(event(securityAudit.NotifyEvent.APP,
        '{"subType":0,"objectInfo":"com.example.demo"}'))
      const process = parseAuditEventToLogEntry(event(securityAudit.NotifyEvent.PROCESS,
        '{"subType":-1,"objectInfo":"demo_process","pid":4321}'))

      expect(app?.eventKey).assertEqual('app.start')
      expect(fieldValue(app, 'object.application')).assertEqual('com.example.demo')
      expect(process?.eventKey).assertEqual('process.exit')
      expect(fieldValue(process, 'object.process_name')).assertEqual('demo_process')
      expect(fieldValue(process, 'edm.operation_type')).assertEqual('')
    })

    it('should structure edm operation and policy object', 0, () => {
      const entry = parseAuditEventToLogEntry(event(securityAudit.NotifyEvent.EDM,
        '{"type":1,"objectInfo":"disallow_usb","caller":{"bundleName":"com.example.admin"},"outcome":"success"}'))

      expect(entry?.eventKey).assertEqual('edm.policy_change')
      expect(fieldValue(entry, 'object.policy')).assertEqual('disallow_usb')
      expect(fieldValue(entry, 'edm.operation_type')).assertEqual('1')
    })

    it('should map subscribed power events and reject unknown ids', 0, () => {
      const powerOn = parseAuditEventToLogEntry(event(DEVICE_POWER_ON_AUDIT_EVENT_ID, '{}'))
      const powerOff = parseAuditEventToLogEntry(event(DEVICE_POWER_OFF_AUDIT_EVENT_ID, '{}'))
      const unknown = parseAuditEventToLogEntry(event(999999, '{}'))

      expect(powerOn?.eventKey).assertEqual('device.power_on')
      expect(powerOff?.eventKey).assertEqual('device.power_off')
      expect(unknown === undefined).assertTrue()
    })

    it('should fallback to now provider when source timestamp is invalid', 0, () => {
      const entry = parseAuditEventToLogEntry(event(securityAudit.NotifyEvent.FILE, '{}', 'invalid'), () => 1712732400000)
      expect(entry?.timestamp).assertEqual(1712732400000)
    })
  })
}

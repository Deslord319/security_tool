import { describe, expect, it } from '@ohos/hypium'
import { securityAudit } from '@kit.DeviceSecurityKit'
import { LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import { LogAuditSource } from '../../main/ets/services/log-manage/source/LogAuditSource'

export default function logAuditSourceTest() {
  describe('LogAuditSource', () => {
    it('should map blocked audit payload into normalized log entry', 0, () => {
      let event = {
        eventId: securityAudit.NotifyEvent.FILE_INTERCEPTED,
        timestamp: '20260402120000',
        userId: 100,
        content: JSON.stringify({
          description: 'blocked file access',
          outcome: 'blocked',
          processName: 'demo-app',
          pid: 123,
          path: '/data/storage/el2/base/files/demo.txt'
        }),
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = LogAuditSource.parseAuditEventForTest(event)

      expect(!!entry).assertTrue()
      expect(entry!.eventType).assertEqual(LogEventType.FILE)
      expect(entry!.result).assertEqual(LogEventResult.BLOCKED)
      expect(entry!.processName).assertEqual('demo-app')
      expect((entry!.filePath ?? '').length > 0).assertTrue()
      expect(entry!.rawOutcome).assertEqual('blocked')
    })

    it('should ignore unknown audit event ids', 0, () => {
      let event = {
        eventId: 999999,
        timestamp: '20260402120000',
        userId: 100,
        content: '{}',
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = LogAuditSource.parseAuditEventForTest(event)

      expect(entry === undefined).assertTrue()
    })
  })
}

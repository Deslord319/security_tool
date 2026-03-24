import { describe, it, expect } from '@ohos/hypium'
import { LogAuditService } from '../../main/ets/services/LogAuditService'
import { LogEventType } from '../../main/ets/models/DataModels'

export default function logAuditServiceTest() {
  describe('LogAuditService', () => {
    it('should expose diagnostics for four final event types', 0, () => {
      LogAuditService.resetDiagnostics()
      let diagnostics = LogAuditService.getDiagnostics()
      expect(diagnostics.byType.size).assertEqual(4)
      expect(diagnostics.byType.get(LogEventType.FILE)?.seenCount).assertEqual(0)
      expect((diagnostics.byType.get(LogEventType.FILE)?.preFilterUnsupportedEventIds || []).length).assertEqual(0)
    })

    it('should keep subscription mode defaults predictable before subscribe', 0, () => {
      expect(LogAuditService.getSubscriptionStatus()).assertFalse()
      expect(LogAuditService.getSubscribeMode()).assertEqual('none')
      expect(LogAuditService.getFallbackReason()).assertEqual('none')
      expect(LogAuditService.getLastSubscribeFailedEventIds().length).assertEqual(0)
    })

    it('should reserve FILE diagnostics for user file filtering counters', 0, () => {
      let diagnostics = LogAuditService.getDiagnostics()
      let fileDiag = diagnostics.byType.get(LogEventType.FILE)
      expect(fileDiag !== undefined).assertTrue()
      expect(fileDiag?.droppedNoPathCount).assertEqual(0)
      expect(fileDiag?.droppedPrefixMismatchCount).assertEqual(0)
    })
  })
}

import { describe, it, expect } from '@ohos/hypium'
import { LogAuditService } from '../../main/ets/services/LogAuditService'

export default function logAuditServiceTest() {
  describe('LogAuditService', () => {
    it('should expose stable initial subscription status', 0, () => {
      expect(LogAuditService.getSubscriptionStatus()).assertFalse()
      expect(LogAuditService.getLastSubscribeErrorCode()).assertUndefined()
      expect(LogAuditService.getLastSubscribeFailedEventIds().length).assertEqual(0)
    })

    it('should return a defensive copy for failed subscribe ids', 0, () => {
      let failedIds = LogAuditService.getLastSubscribeFailedEventIds()
      failedIds.push(999)
      expect(LogAuditService.getLastSubscribeFailedEventIds().length).assertEqual(0)
    })
  })
}

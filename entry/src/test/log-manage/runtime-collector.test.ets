import { describe, it, expect } from '@ohos/hypium'
import { LogRuntimeCollectorService } from '../../main/ets/services/LogRuntimeCollectorService'

export default function logRuntimeCollectorServiceTest() {
  describe('LogRuntimeCollectorService', () => {
    it('should expose runtime status shape', 0, () => {
      let status = LogRuntimeCollectorService.getStatus()
      expect(typeof status.running === 'boolean').assertTrue()
      expect(typeof status.subscribed === 'boolean').assertTrue()
    })

    it('should be idle before explicit start', 0, () => {
      let status = LogRuntimeCollectorService.getStatus()
      expect(status.running).assertFalse()
    })

    it('should only report collecting when running and subscribed are both true', 0, () => {
      let status = LogRuntimeCollectorService.getStatus()
      expect(LogRuntimeCollectorService.isCollecting()).assertEqual(status.running && status.subscribed)
    })
  })
}

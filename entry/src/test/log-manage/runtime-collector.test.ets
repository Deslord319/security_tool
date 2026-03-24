import { describe, it, expect } from '@ohos/hypium'
import { LogRuntimeCollectorService } from '../../main/ets/services/LogRuntimeCollectorService'
import { LogEventType } from '../../main/ets/models/DataModels'

export default function logRuntimeCollectorServiceTest() {
  describe('LogRuntimeCollectorService', () => {
    it('should expose runtime status shape', 0, () => {
      let status = LogRuntimeCollectorService.getStatus()
      expect(typeof status.running === 'boolean').assertTrue()
      expect(typeof status.subscribed === 'boolean').assertTrue()
    })

    it('should merge crash diagnostics into runtime diagnostics snapshot', 0, () => {
      let diagnostics = LogRuntimeCollectorService.getDiagnostics()
      expect(diagnostics.byType.size).assertEqual(4)
      expect(diagnostics.byType.get(LogEventType.CRASH) !== undefined).assertTrue()
      expect(diagnostics.byType.get(LogEventType.FILE) !== undefined).assertTrue()
    })
  })
}

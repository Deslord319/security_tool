import { describe, expect, it } from '@ohos/hypium'
import hiAppEvent from '@ohos.hiviewdfx.hiAppEvent'
import { LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import { mapCrashInfoToLogEntry } from '../../main/ets/services/log-manage/source/LogCrashEventMapper'

export default function logCrashSourceTest() {
  describe('LogCrashSource', () => {
    it('should map crash event into failed crash log entry', 0, () => {
      let info = {
        name: hiAppEvent.event.APP_CRASH,
        params: {
          bundleName: 'demo.bundle',
          reason: 'native crash',
          pid: 321,
          uid: 100
        }
      } as hiAppEvent.AppEventInfo

      let entry = mapCrashInfoToLogEntry(info)
      let expectedOutcome = info.name === hiAppEvent.event.APP_FREEZE ? 'freeze' : 'crash'

      expect(entry.eventType).assertEqual(LogEventType.CRASH)
      expect(entry.result).assertEqual(LogEventResult.FAILED)
      expect((entry.processName ?? '').length >= 0).assertTrue()
      expect(entry.rawOutcome).assertEqual(expectedOutcome)
      expect(entry.detail.indexOf('native crash') >= 0).assertTrue()
    })

    it('should fallback to event name when crash detail fields are missing', 0, () => {
      let info = {
        name: hiAppEvent.event.APP_FREEZE,
        params: {}
      } as hiAppEvent.AppEventInfo

      let entry = mapCrashInfoToLogEntry(info)

      expect(entry.rawOutcome).assertEqual('freeze')
      expect(entry.detail).assertEqual(hiAppEvent.event.APP_FREEZE)
    })
  })
}

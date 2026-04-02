import { describe, expect, it } from '@ohos/hypium'
import hiAppEvent from '@ohos.hiviewdfx.hiAppEvent'
import { LogEventResult, LogEventType } from '../../main/ets/models/DataModels'
import { LogCrashSource } from '../../main/ets/services/log-manage/source/LogCrashSource'

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

      let entry = LogCrashSource.mapCrashInfoForTest(info)

      expect(entry.eventType).assertEqual(LogEventType.CRASH)
      expect(entry.result).assertEqual(LogEventResult.FAILED)
      expect(entry.processName).assertEqual('demo.bundle')
      expect(entry.rawOutcome).assertEqual('crash')
      expect(entry.detail.indexOf('native crash') >= 0).assertTrue()
    })

    it('should fallback to event name when crash detail fields are missing', 0, () => {
      let info = {
        name: hiAppEvent.event.APP_FREEZE,
        params: {}
      } as hiAppEvent.AppEventInfo

      let entry = LogCrashSource.mapCrashInfoForTest(info)

      expect(entry.rawOutcome).assertEqual('freeze')
      expect(entry.detail).assertEqual(hiAppEvent.event.APP_FREEZE)
    })
  })
}

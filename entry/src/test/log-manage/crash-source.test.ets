import { describe, expect, it } from '@ohos/hypium'
import hiAppEvent from '@ohos.hiviewdfx.hiAppEvent'
import {
  LogEventType
} from '../../main/ets/models/LogModels'
import { mapCrashInfoToLogEntry } from '../../main/ets/services/log-manage/source/LogCrashEventMapper'

export default function logCrashSourceTest() {
  describe('LogCrashSource', () => {
    it('should map crash event into crash log entry without result inference', 0, () => {
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

      expect(entry.eventType).assertEqual(LogEventType.CRASH)
      expect((entry.processName ?? '').length >= 0).assertTrue()
      expect(entry.rawOutcome).assertEqual(undefined)
      expect(entry.detail.indexOf('native crash') >= 0).assertTrue()
    })

    it('should fallback to event name when crash detail fields are missing', 0, () => {
      let info = {
        name: hiAppEvent.event.APP_FREEZE,
        params: {}
      } as hiAppEvent.AppEventInfo

      let entry = mapCrashInfoToLogEntry(info)

      expect(entry.rawOutcome).assertEqual(undefined)
      expect(entry.detail).assertEqual(hiAppEvent.event.APP_FREEZE)
    })

    it('should prefer source event timestamp when params carry milliseconds', 0, () => {
      let info = {
        name: hiAppEvent.event.APP_CRASH,
        params: {
          timestamp: 1712732400000,
          reason: 'native crash'
        }
      } as hiAppEvent.AppEventInfo

      let entry = mapCrashInfoToLogEntry(info, () => 123)

      expect(entry.timestamp).assertEqual(1712732400000)
    })

    it('should normalize seconds-based source timestamps before fallback', 0, () => {
      let info = {
        name: hiAppEvent.event.APP_CRASH,
        params: {
          eventTime: '1712732400',
          reason: 'native crash'
        }
      } as hiAppEvent.AppEventInfo

      let entry = mapCrashInfoToLogEntry(info, () => 456)

      expect(entry.timestamp).assertEqual(1712732400000)
    })
  })
}

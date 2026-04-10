import { describe, expect, it } from '@ohos/hypium'
import {
  resolveAuditSourceTimestamp,
  resolveCrashSourceTimestamp
} from '../../main/ets/services/log-manage/source/LogTimestampResolver'

export default function logTimestampResolverTest() {
  describe('LogTimestampResolver', () => {
    it('should normalize crash timestamps from millis, seconds, and ISO string inputs', 0, () => {
      let millis = resolveCrashSourceTimestamp([1712732400000], () => 1)
      let seconds = resolveCrashSourceTimestamp(['1712732400'], () => 1)
      let iso = resolveCrashSourceTimestamp(['2026-04-10T12:00:00Z'], () => 1)

      expect(millis).assertEqual(1712732400000)
      expect(seconds).assertEqual(1712732400000)
      expect(iso > 0).assertTrue()
    })

    it('should fallback when crash source timestamp is missing or invalid', 0, () => {
      let fallback = resolveCrashSourceTimestamp([undefined, '', 'bad-value'], () => 123456)

      expect(fallback).assertEqual(123456)
    })

    it('should parse strict audit timestamps and reject invalid dates', 0, () => {
      let parsed = resolveAuditSourceTimestamp('20260402120000', () => 1)
      let fallback = resolveAuditSourceTimestamp('20261302120000', () => 789)

      expect(parsed).assertEqual(new Date(2026, 3, 2, 12, 0, 0).getTime())
      expect(fallback).assertEqual(789)
    })
  })
}

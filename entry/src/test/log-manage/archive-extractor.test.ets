import { describe, expect, it } from '@ohos/hypium'
import { LogArchiveExtractor } from '../../main/ets/services/log-manage/import/LogArchiveExtractor'

export default function logArchiveExtractorTest() {
  describe('LogArchiveExtractor', () => {
    it('should reject non zip outer archives before filesystem work', 0, async () => {
      let result = await LogArchiveExtractor.extract('/tmp/logs.gz', '/tmp/out')

      expect(result.success).assertFalse()
      expect(result.code).assertEqual('invalid_archive')
      expect(result.files.length).assertEqual(0)
    })
  })
}

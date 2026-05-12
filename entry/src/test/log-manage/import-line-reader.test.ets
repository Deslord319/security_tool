import { describe, expect, it } from '@ohos/hypium'
import { LogImportLineReader } from '../../main/ets/services/log-manage/import/LogImportLineReader'

export default function logImportLineReaderTest() {
  describe('LogImportLineReader', () => {
    it('should keep utf8 characters split across chunks', 0, () => {
      let result = LogImportLineReader.decodeUtf8ChunksForTest([
        new Uint8Array([0xE4, 0xB8, 0xAD, 0xE6]),
        new Uint8Array([0x96, 0x87])
      ])

      expect(result).assertEqual('中文')
    })
  })
}

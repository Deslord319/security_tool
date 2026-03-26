import { describe, it, expect } from '@ohos/hypium'
import { LogPathUtils } from '../../main/ets/utils/LogPathUtils'

export default function logPathUtilsTest() {
  describe('LogPathUtils', () => {
    it('should normalize uri suffixes and trailing separators', 0, () => {
      let normalized = LogPathUtils.normalizePathCandidate(' file://docs/storage/Users/currentUser/report.csv?token=1 ')
      expect(normalized).assertEqual('file://docs/storage/Users/currentUser/report.csv')
    })

    it('should extract file path from raw audit text', 0, () => {
      let path = LogPathUtils.extractPathFromRawText('open file file://media/Photo/test.png, result=allow')
      expect(path).assertEqual('file://media/Photo/test.png')
    })

    it('should build prefixes from base paths and environment dirs', 0, () => {
      let prefixes = LogPathUtils.buildFileFilterPrefixes(['file://media/'], ['/storage/Users/currentUser/Desktop'])
      expect(prefixes.includes('file://media/')).assertTrue()
      expect(prefixes.includes('/storage/Users/currentUser/Desktop/')).assertTrue()
    })

    it('should match normalized candidate against allowed prefixes', 0, () => {
      let matched = LogPathUtils.hasAllowedPrefix('/storage/Users/currentUser/Documents/report.txt', [
        '/storage/Users/currentUser/Documents/'
      ])
      expect(matched).assertTrue()
    })
  })
}

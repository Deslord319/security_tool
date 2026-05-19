import { describe, it, expect } from '@ohos/hypium'
import { LogPathUtils } from '../../main/ets/utils/LogPathUtils'

export default function logPathUtilsTest() {
  describe('LogPathUtils', () => {
    it('should normalize uri suffixes and trailing separators', 0, () => {
      let normalized = LogPathUtils.normalizePathCandidate(' file://docs/storage/Users/currentUser/report.csv?token=1 ')
      expect(normalized).assertEqual('file://docs/storage/Users/currentUser/report.csv')
    })

    it('should extract file path from raw audit text', 0, () => {
      let path = LogPathUtils.extractRawAuditPath(undefined, ['open file file://media/Photo/test.png, result=allow'])
      expect(path).assertEqual('file://media/Photo/test.png')
    })

    it('should build hmdfs account files prefix with dynamic user id', 0, () => {
      let prefix = LogPathUtils.buildHmdfsAccountFilesPrefix(100)
      expect(prefix).assertEqual('/data/service/el2/100/hmdfs/account/files/')
    })

    it('should remap hmdfs docs audit paths into user directory paths', 0, () => {
      let normalized = LogPathUtils.normalizePathCandidate(
        '/data/service/el2/100/hmdfs/account/files/Docs/Download/oh-kia-samples/probe.txt'
      )
      expect(normalized).assertEqual('/storage/Users/currentUser/Download/oh-kia-samples/probe.txt')
    })

    it('should preserve spaces in structured hmdfs audit path candidates', 0, () => {
      let normalized = LogPathUtils.normalizePathCandidate(
        '/data/service/el2/100/hmdfs/account/files/Docs/Download/新建 文本文档.txt',
        true
      )
      expect(normalized).assertEqual('/storage/Users/currentUser/Download/新建 文本文档.txt')
    })

    it('should remap generic hmdfs account files path into current user path', 0, () => {
      let normalized = LogPathUtils.normalizePathCandidate(
        '/data/service/el2/100/hmdfs/account/files/Shared/report.txt'
      )
      expect(normalized).assertEqual('/storage/Users/currentUser/Shared/report.txt')
    })

    it('should prefer structured candidate before scanning raw texts', 0, () => {
      let path = LogPathUtils.extractRawAuditPath(' file://docs/storage/Users/currentUser/audit.csv ', [
        'fallback /storage/Users/currentUser/ignored.txt'
      ])
      expect(path).assertEqual('file://docs/storage/Users/currentUser/audit.csv')
    })
  })
}

import { describe, expect, it } from '@ohos/hypium'
import { LogEventType } from '../../main/ets/models/DataModels'
import { ImportedLogFile } from '../../main/ets/services/log-manage/import/LogImportRule'
import { KernelLogImportRule } from '../../main/ets/services/log-manage/import/KernelLogImportRule'

function createFile(content: string, relativePath: string = 'remoteLog/hilog/hilog_kmsg.1'): ImportedLogFile {
  return {
    fileName: relativePath.substring(relativePath.lastIndexOf('/') + 1),
    relativePath,
    normalizedPath: relativePath,
    content
  }
}

export default function kernelImportRuleTest() {
  describe('KernelLogImportRule', () => {
    it('should only handle hilog kmsg files', 0, () => {
      let rule = new KernelLogImportRule()

      expect(rule.canHandle(createFile('', 'remoteLog/hilog/hilog_kmsg.985.20260429-122746'))).assertTrue()
      expect(rule.canHandle(createFile('', 'remoteLog/hilog/hilog_kmsg.985.20260429-122746.gz'))).assertTrue()
      expect(rule.canHandle(createFile('', 'remoteLog/hilog/hilog.985.20260429-122746.gz'))).assertFalse()
      expect(rule.canHandle(createFile('', 'remoteLog/cmd_output/hilog_kmsg.1'))).assertFalse()
    })

    it('should map retained kernel rules into kernel log entries', 0, async () => {
      let content = [
        '05-09 16:03:52.300 <3> [6.050299] -;[6] pid=1 tid=2 comm=proc [hmseh:10] avc: denied permissive=0 path="/data/a"',
        '05-09 16:03:52.301 <3> [6.050300] -;[6] pid=1 tid=2 comm=proc [binderfs_write:20] translate_binder failed err=E_HM_PERM',
        '05-09 16:03:52.302 <3> [6.050301] -;[6] pid=1 tid=2 comm=proc [hmdec:30] set rule',
        '05-09 16:03:52.303 <3> [6.050302] -;[6] pid=1 tid=2 comm=proc [fs_devfs:40] devfs event'
      ].join('\n')

      let result = await new KernelLogImportRule().parse(createFile(content))

      expect(result.entries.length).assertEqual(4)
      expect(result.entries[0].eventType).assertEqual(LogEventType.KERNEL)
      expect(result.entries[0].rawEventName).assertEqual('kernel_hmseh_denied')
      expect(result.entries[1].rawEventName).assertEqual('kernel_binder_perm_failed')
      expect(result.entries[2].rawEventName).assertEqual('kernel_hmdec_rule')
      expect(result.entries[3].rawEventName).assertEqual('kernel_fs_devfs_dec')
    })

    it('should drop rows without comm and excluded hmseh path', 0, async () => {
      let content = [
        '05-09 16:03:52.300 <3> [6.050299] -;[6] pid=1 tid=2 [hmseh:10] avc: denied permissive=0 path="/data/a"',
        '05-09 16:03:52.301 <3> [6.050300] -;[6] pid=1 tid=2 comm=proc [hmseh:10] avc: denied permissive=0 path="/sys/power/last_sr"',
        '05-09 16:03:52.302 <3> [6.050301] -;[6] pid=1 tid=2 comm=proc [hmseh:10] avc: denied permissive=0 path="/data/b"'
      ].join('\n')

      let result = await new KernelLogImportRule().parse(createFile(content))

      expect(result.entries.length).assertEqual(1)
      expect(result.droppedCount).assertEqual(2)
    })
  })
}

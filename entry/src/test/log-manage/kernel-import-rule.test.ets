import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { LogEventType } from '../../main/ets/models/LogModels'
import { ImportedLogFile } from '../../main/ets/services/log-manage/import/LogImportRule'
import { KernelLogImportRule } from '../../main/ets/services/log-manage/import/KernelLogImportRule'

let testContents: Map<string, string> = new Map<string, string>()

function createFile(relativePath: string = 'remoteLog/hilog/hilog_kmsg.1', content?: string): ImportedLogFile {
  let path = `kernel_import_rule_${relativePath.replace(/\//g, '_')}_${Date.now()}_${Math.floor(Math.random() * 100000)}`
  if (content !== undefined) {
    testContents.set(path, content)
  }
  return {
    path,
    fileName: relativePath.substring(relativePath.lastIndexOf('/') + 1),
    relativePath,
    normalizedPath: relativePath
  }
}

export default function kernelImportRuleTest() {
  describe('KernelLogImportRule', () => {
    beforeEach(() => {
      testContents = new Map<string, string>()
      KernelLogImportRule.setLineReaderForTest(async (file: ImportedLogFile, onLine: (line: string, lineNumber: number) => Promise<void>): Promise<void> => {
        let content = testContents.get(file.path) ?? ''
        let lines = content.split(/\r?\n/)
        for (let index = 0; index < lines.length; index++) {
          await onLine(lines[index], index + 1)
        }
      })
    })

    afterEach(() => {
      KernelLogImportRule.resetTestPorts()
    })

    it('should only handle hilog kmsg files', 0, () => {
      let rule = new KernelLogImportRule()

      expect(rule.canHandle(createFile('remoteLog/hilog/hilog_kmsg.985.20260429-122746'))).assertTrue()
      expect(rule.canHandle(createFile('remoteLog/hilog/hilog_kmsg.985.20260429-122746.gz'))).assertTrue()
      expect(rule.canHandle(createFile('remoteLog/hilog/hilog.985.20260429-122746.gz'))).assertFalse()
      expect(rule.canHandle(createFile('remoteLog/cmd_output/hilog_kmsg.1'))).assertFalse()
    })

    it('should build unique temporary gunzip targets', 0, () => {
      let first = KernelLogImportRule.buildGunzipTargetPathForTest('/data/log/hilog/hilog_kmsg.1.gz')
      let second = KernelLogImportRule.buildGunzipTargetPathForTest('/data/log/hilog/hilog_kmsg.1.gz')

      expect(first === second).assertFalse()
      expect(first.indexOf('/data/log/hilog/hilog_kmsg.1.import_') >= 0).assertTrue()
      expect(first.endsWith('.txt')).assertTrue()
    })

    it('should map retained kernel rules into kernel log entries', 0, async () => {
      let content = [
        '05-09 16:03:52.300 <3> [6.050299] -;[6] pid=1 tid=2 comm=proc [hmseh:10] avc: denied permissive=0 path="/data/a"',
        '05-09 16:03:52.301 <3> [6.050300] -;[6] pid=1 tid=2 comm=proc [binderfs_write:20] translate_binder failed err=E_HM_PERM',
        '05-09 16:03:52.302 <3> [6.050301] -;[6] pid=1 tid=2 comm=proc [hmdec:30] set rule',
        '05-09 16:03:52.303 <3> [6.050302] -;[6] pid=1 tid=2 comm=proc [fs_devfs:40] devfs event'
      ].join('\n')

      let result = await new KernelLogImportRule().parse(createFile('remoteLog/hilog/hilog_kmsg.1', content))

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

      let result = await new KernelLogImportRule().parse(createFile('remoteLog/hilog/hilog_kmsg.1', content))

      expect(result.entries.length).assertEqual(1)
      expect(result.droppedCount).assertEqual(2)
    })
  })
}

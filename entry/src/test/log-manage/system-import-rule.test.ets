import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { LogEventType } from '../../main/ets/models/LogModels'
import { ImportedLogFile } from '../../main/ets/services/log-manage/import/LogImportRule'
import { SystemLogImportRule } from '../../main/ets/services/log-manage/import/SystemLogImportRule'

let testContents: Map<string, string> = new Map<string, string>()

function createFile(relativePath: string, content?: string): ImportedLogFile {
  let path = `system_import_rule_${relativePath.replace(/\//g, '_')}_${Date.now()}_${Math.floor(Math.random() * 100000)}`
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

export default function systemImportRuleTest() {
  describe('SystemLogImportRule', () => {
    beforeEach(() => {
      testContents = new Map<string, string>()
      SystemLogImportRule.setLineReaderForTest(async (file: ImportedLogFile, onLine: (line: string, lineNumber: number) => Promise<void>): Promise<void> => {
        let content = testContents.get(file.path) ?? ''
        let lines = content.split(/\r?\n/)
        for (let index = 0; index < lines.length; index++) {
          await onLine(lines[index], index + 1)
        }
      })
    })

    afterEach(() => {
      SystemLogImportRule.resetTestPorts()
    })

    it('should only handle system log whitelist paths', 0, () => {
      let rule = new SystemLogImportRule()

      expect(rule.canHandle(createFile('remoteLog/eventlog/SERVICE_TIMEOUT_WARNING-1764-20260509160526.log'))).assertTrue()
      expect(rule.canHandle(createFile('remoteLog/eventlog/WINDOW_EXCEPTION_DETECTION-3661-20260509160357.log'))).assertTrue()
      expect(rule.canHandle(createFile('remoteLog/hisi_logs/hisi_diaginfo.log'))).assertTrue()
      expect(rule.canHandle(createFile('remoteLog/f2fs-tools/fsck.log'))).assertTrue()
      expect(rule.canHandle(createFile('remoteLog/memory/proc_meminfo_20260429111231.txt'))).assertTrue()
      expect(rule.canHandle(createFile('remoteLog/memory_leak/memleak-native-demo-sample.txt'))).assertTrue()
      expect(rule.canHandle(createFile('remoteLog/updater/updater_log'))).assertTrue()
      expect(rule.canHandle(createFile('remoteLog/log/HSLd.log'))).assertTrue()
      expect(rule.canHandle(createFile('remoteLog/hilog/hilog.260.20260509-160326.gz'))).assertFalse()
      expect(rule.canHandle(createFile('remoteLog/eventlog/random.log'))).assertFalse()
    })

    it('should parse service timeout and window exception as one-file events without result inference', 0, async () => {
      let serviceContent = [
        'EVENTNAME = SERVICE_TIMEOUT_WARNING',
        'TIMESTAMP = 2026/05/09-16:05:26:448',
        'PROCESS_NAME = media_service',
        'MSG = timeout timer: av_codec::demuxer_setdatasource'
      ].join('\n')
      let windowContent = [
        'EVENTNAME = WINDOW_EXCEPTION_DETECTION',
        'TIMESTAMP = 2026/05/09-16:03:57:071',
        'PROCESS_NAME = windowmanager',
        'MSG = ZOrderCheck err check wallpaperWhenLocked'
      ].join('\n')

      let serviceResult = await new SystemLogImportRule().parse(createFile(
        'remoteLog/eventlog/SERVICE_TIMEOUT_WARNING-1764-20260509160526.log',
        serviceContent
      ))
      let windowResult = await new SystemLogImportRule().parse(createFile(
        'remoteLog/eventlog/WINDOW_EXCEPTION_DETECTION-3661-20260509160357.log',
        windowContent
      ))

      expect(serviceResult.entries.length).assertEqual(1)
      expect(serviceResult.entries[0].eventType).assertEqual(LogEventType.SYSTEM)
      expect(serviceResult.entries[0].rawEventName).assertEqual('system_service_timeout')
      expect(serviceResult.entries[0].filePath).assertEqual('remoteLog/eventlog/SERVICE_TIMEOUT_WARNING-1764-20260509160526.log')
      expect(windowResult.entries.length).assertEqual(1)
      expect(windowResult.entries[0].rawEventName).assertEqual('system_window_exception')
    })

    it('should split hisi and f2fs logs into block events', 0, async () => {
      let hisiContent = [
        'Time [2026-05-09 10:00:00.000]',
        'soc diagnostic warning',
        'Time [2026-05-09 10:01:00.000]',
        'soc diagnostic ok'
      ].join('\n')
      let fsckContent = [
        '=== 2026/05/09 10:00:00 ===',
        'fsck completed',
        '=== 2026/05/09 10:02:00 ===',
        'fsck failed ret:1'
      ].join('\n')

      let hisiResult = await new SystemLogImportRule().parse(createFile('remoteLog/hisi_logs/hisi_diaginfo.log', hisiContent))
      let fsckResult = await new SystemLogImportRule().parse(createFile('remoteLog/f2fs-tools/fsck.log', fsckContent))

      expect(hisiResult.entries.length).assertEqual(2)
      expect(hisiResult.entries[0].rawEventName).assertEqual('system_hisi_diag')
      expect(fsckResult.entries.length).assertEqual(2)
      expect(fsckResult.entries[0].rawEventName).assertEqual('system_fsck')
      expect(fsckResult.entries[1].rawEventName).assertEqual('system_fsck')
    })

    it('should parse key line files one entry per matched line', 0, async () => {
      let content = [
        'I normal updater info line',
        'Start verify package',
        'PerformAction ret:0',
        'PerformAction ret:2',
        '----',
        'W Warning updater mode recovery'
      ].join('\n')

      let result = await new SystemLogImportRule().parse(createFile('remoteLog/updater/updater_log', content))

      expect(result.entries.length).assertEqual(4)
      expect(result.entries[0].rawEventName).assertEqual('system_updater_log')
      expect(result.entries[2].rawEventName).assertEqual('system_updater_log')
      expect(result.entries[3].rawEventName).assertEqual('system_updater_log')
    })

    it('should normalize second based fallback timestamps to milliseconds', 0, () => {
      expect(SystemLogImportRule.normalizeEpochMillis(1778489523)).assertEqual(1778489523000)
      expect(SystemLogImportRule.normalizeEpochMillis(1778489523000)).assertEqual(1778489523000)
    })

    it('should parse key line timestamps without year using fallback year', 0, () => {
      let fallback = new Date(2026, 4, 11, 16, 52, 3, 0).getTime()
      let parsed = SystemLogImportRule.parseTimestampFromText(
        '03-13 12:31:59.908 Updater 599 I utils_ext.cpp 568 : updater mode',
        fallback
      )
      let crossYear = SystemLogImportRule.parseTimestampFromText(
        '12-31 23:59:59.001 Updater 599 E update failed',
        new Date(2026, 0, 1, 0, 1, 0, 0).getTime()
      )

      expect(parsed).assertEqual(new Date(2026, 2, 13, 12, 31, 59, 908).getTime())
      expect(crossYear).assertEqual(new Date(2025, 11, 31, 23, 59, 59, 1).getTime())
    })

    it('should keep updater and installer key lines with valid event timestamps', 0, async () => {
      let updaterResult = await new SystemLogImportRule().parse(createFile(
        'remoteLog/updater/updater_log',
        '03-13 12:31:59.908 Updater 599 I utils_ext.cpp 568 : updater mode'
      ))
      let installerResult = await new SystemLogImportRule().parse(createFile(
        'remoteLog/log/sys_installer.log',
        '03-16 16:30:44.773 SysInstaller 27555 I action_processer.cpp 78 : Start verify'
      ))

      expect(updaterResult.entries.length).assertEqual(1)
      expect(updaterResult.entries[0].rawEventName).assertEqual('system_updater_log')
      expect(updaterResult.entries[0].timestamp > 1700000000000).assertTrue()
      expect(installerResult.entries.length).assertEqual(1)
      expect(installerResult.entries[0].rawEventName).assertEqual('system_installer')
      expect(installerResult.entries[0].timestamp > 1700000000000).assertTrue()
    })

    it('should keep useful memory leak reports and drop low value files', 0, async () => {
      let useful = [
        'Timestamp:2026-05-09 10:00:00.000',
        'Pid:123',
        'processName:demo',
        'LOGGER_MEMCHECK report'
      ].join('\n')
      let lowValue = [
        'short',
        'empty'
      ].join('\n')

      let usefulResult = await new SystemLogImportRule().parse(createFile(
        'remoteLog/memory_leak/memleak-native-demo-sample.txt',
        useful
      ))
      let lowValueResult = await new SystemLogImportRule().parse(createFile(
        'remoteLog/memory_leak/memleak-kernel-gpu.txt',
        lowValue
      ))

      expect(usefulResult.entries.length).assertEqual(1)
      expect(usefulResult.entries[0].rawEventName).assertEqual('system_memory_leak')
      expect(lowValueResult.entries.length).assertEqual(0)
    })

    it('should dedupe by content and timestamp without source path', 0, async () => {
      let content = [
        'EVENTNAME = SERVICE_TIMEOUT_WARNING',
        'TIMESTAMP = 2026/05/09-16:05:26:448',
        'PROCESS_NAME = media_service',
        'MSG = timeout timer'
      ].join('\n')
      let shifted = content.replace('16:05:26:448', '16:05:27:448')

      let first = await new SystemLogImportRule().parse(createFile(
        'remoteLog/eventlog/SERVICE_TIMEOUT_WARNING-1764-20260509160526.log',
        content
      ))
      let sameContentDifferentSource = await new SystemLogImportRule().parse(createFile(
        'other/eventlog/SERVICE_TIMEOUT_WARNING-1764-20260509160526.log',
        content
      ))
      let differentTimestamp = await new SystemLogImportRule().parse(createFile(
        'remoteLog/eventlog/SERVICE_TIMEOUT_WARNING-1764-20260509160527.log',
        shifted
      ))

      expect(first.entries[0].id).assertEqual(sameContentDifferentSource.entries[0].id)
      expect(first.entries[0].id === differentTimestamp.entries[0].id).assertFalse()
    })
  })
}

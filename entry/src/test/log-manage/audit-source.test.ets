import { describe, expect, it } from '@ohos/hypium'
import { securityAudit } from '@kit.DeviceSecurityKit'
import {
  LogDetailTableRow,
  LogEventResult,
  LogEventType,
  LogEntry
} from '../../main/ets/models/DataModels'
import {
  formatLogTimestamp,
  getLogEventResultLabel
} from '../../main/ets/viewmodels/log-manage/presentation/LogPresentationMapper'
import { parseAuditEventToLogEntry } from '../../main/ets/services/log-manage/source/LogAuditEventMapper'

interface AuditLogEntryWithDetailRows extends LogEntry {
  detailRows?: LogDetailTableRow[]
}

interface AuditMetadata {
  version: string
  userId: number
  deviceId: string
  timestamp: string
  seqNum: number
}

interface AccountCaller {
  userName: string
  userId: number
}

interface AccountAuditContent {
  type: number
  subType: number
  caller: AccountCaller
  bootTime: string
  wallTime: string
  outcome: string
  sourceInfo: string
  targetInfo: string
  extra: string
}

interface PermissionEntry {
  PermissionName: string
  PermissionState: string
}

interface PermissionExtra {
  pid: number
  uid: number
  bundleName: string
  tokenId: number
  pname: string
  startTime: string
  timestamp: string
  existingPermissions: PermissionEntry[]
  newPermission: PermissionEntry
}

interface PermissionAuditContent {
  type: number
  subType: number
  caller: string
  bootTime: string
  wallTime: string
  outcome: string
  sourceInfo: string
  targetInfo: string
  extra: string
}

interface FileAuditContent {
  event_name: string
  outcome: string
  processName: string
  pid: number
  uid: number
  path: string
}

export default function logAuditSourceTest() {
  describe('LogAuditSource', () => {
    it('should map blocked audit payload into normalized log entry', 0, () => {
      let event = {
        eventId: securityAudit.NotifyEvent.FILE_INTERCEPTED,
        timestamp: '20260402120000',
        userId: 100,
        content: JSON.stringify({
          description: 'blocked file access',
          outcome: 'blocked',
          processName: 'demo-app',
          pid: 123,
          path: '/data/storage/el2/base/files/demo.txt'
        }),
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)

      expect(!!entry).assertTrue()
      expect(entry!.eventType).assertEqual(LogEventType.FILE)
      expect(entry!.result).assertEqual(LogEventResult.BLOCKED)
      expect(entry!.processName).assertEqual('demo-app')
      expect((entry!.filePath ?? '').length > 0).assertTrue()
      expect(entry!.rawOutcome).assertEqual('blocked')
    })

    it('should map account audit payload into detail rows', 0, () => {
      const timestamp = '20260413143936'
      const accountContent: AccountAuditContent = {
        type: 0,
        subType: 0,
        caller: {
          userName: '111',
          userId: 100
        },
        bootTime: '81308595782',
        wallTime: '1776062376163368595',
        outcome: 'Success',
        sourceInfo: '',
        targetInfo: '',
        extra: ''
      }
      const accountMetadata: AuditMetadata = {
        version: '',
        userId: 100,
        deviceId: '5b3b4c74ded54969',
        timestamp,
        seqNum: 0
      }
      let event = {
        eventId: securityAudit.NotifyEvent.ACCOUNT,
        timestamp,
        userId: 100,
        content: JSON.stringify(accountContent),
        metadata: JSON.stringify(accountMetadata)
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)
      let rows = getDetailRows(entry)

      expect(!!entry).assertTrue()
      expect(rows.length).assertEqual(5)
      expect(getRowValue(rows, 'account.userName')).assertEqual('111')
      expect(getRowValue(rows, 'account.userId')).assertEqual('100')
      expect(getRowValue(rows, 'account.result')).assertEqual(getLogEventResultLabel(LogEventResult.SUCCESS))
      expect(getRowValue(rows, 'account.timestamp')).assertEqual(formatLogTimestamp(entry!.timestamp))
      expect(getRowValue(rows, 'account.eventId')).assertEqual(`${securityAudit.NotifyEvent.ACCOUNT}`)
    })

    it('should map permission audit payload into detail rows', 0, () => {
      const timestamp = '20260413143936'
      const permissionExistingPermissions: PermissionEntry[] = [
        {
          PermissionName: 'ohos.permission.MICROPHONE',
          PermissionState: 'PERMISSION_DENIED'
        },
        {
          PermissionName: 'ohos.permission.READ_PASTEBOARD',
          PermissionState: 'PERMISSION_GRANTED'
        }
      ]
      const newPermission: PermissionEntry = {
        PermissionName: 'ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY',
        PermissionState: 'STATE_CHANGE_GRANTED'
      }
      const permissionExtra: PermissionExtra = {
        pid: 8938,
        uid: 20020149,
        bundleName: 'cn.wps.office.hap',
        tokenId: 537076660,
        pname: 'cn.wps.office.hap',
        startTime: '1775814935372142968',
        timestamp: '1775821626432797000',
        existingPermissions: permissionExistingPermissions,
        newPermission
      }
      const permissionContent: PermissionAuditContent = {
        type: 0,
        subType: 0,
        caller: '',
        bootTime: '6714060688281',
        wallTime: '1775821626432832030',
        outcome: '',
        sourceInfo: '',
        targetInfo: '',
        extra: JSON.stringify(permissionExtra)
      }
      const permissionMetadata: AuditMetadata = {
        version: '',
        userId: 100,
        deviceId: '5b3b4c74ded54969',
        timestamp,
        seqNum: 0
      }
      let event = {
        eventId: securityAudit.NotifyEvent.PERMISSION,
        timestamp,
        userId: 100,
        content: JSON.stringify(permissionContent),
        metadata: JSON.stringify(permissionMetadata)
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)
      let rows = getDetailRows(entry)

      expect(!!entry).assertTrue()
      expect(rows.length).assertEqual(7)
      expect(getRowValue(rows, 'permission.bundleName')).assertEqual('cn.wps.office.hap')
      expect(getRowValue(rows, 'permission.pid')).assertEqual('8938')
      expect(getRowValue(rows, 'permission.uid')).assertEqual('20020149')
      expect(getRowValue(rows, 'permission.newPermissionName')).assertEqual('ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY')
      expect(getRowValue(rows, 'permission.newPermissionState')).assertEqual('STATE_CHANGE_GRANTED')
      expect(getRowValue(rows, 'permission.timestamp')).assertEqual(formatLogTimestamp(entry!.timestamp))
      expect(getRowValue(rows, 'permission.eventId')).assertEqual(`${securityAudit.NotifyEvent.PERMISSION}`)
    })

    it('should map file audit payload into detail rows', 0, () => {
      const timestamp = '20260413143936'
      const fileContent: FileAuditContent = {
        event_name: 'file_write',
        outcome: 'blocked',
        processName: 'demo-app',
        pid: 123,
        uid: 100,
        path: '/data/storage/el2/base/files/demo.txt'
      }
      let event = {
        eventId: securityAudit.NotifyEvent.FILE,
        timestamp,
        userId: 100,
        content: JSON.stringify(fileContent),
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)
      let rows = getDetailRows(entry)

      expect(!!entry).assertTrue()
      expect(rows.length).assertEqual(8)
      expect(getRowValue(rows, 'file.operation')).assertEqual('file_write')
      expect(getRowValue(rows, 'file.filePath')).assertEqual('/data/storage/el2/base/files/demo.txt')
      expect(getRowValue(rows, 'file.processName')).assertEqual('demo-app')
      expect(getRowValue(rows, 'file.pid')).assertEqual('123')
      expect(getRowValue(rows, 'file.uid')).assertEqual('100')
      expect(getRowValue(rows, 'file.result')).assertEqual(getLogEventResultLabel(LogEventResult.BLOCKED))
      expect(getRowValue(rows, 'file.timestamp')).assertEqual(formatLogTimestamp(entry!.timestamp))
      expect(getRowValue(rows, 'file.eventId')).assertEqual(`${securityAudit.NotifyEvent.FILE}`)
    })

    it('should ignore unknown audit event ids', 0, () => {
      let event = {
        eventId: 999999,
        timestamp: '20260402120000',
        userId: 100,
        content: '{}',
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)

      expect(entry === undefined).assertTrue()
    })

    it('should fallback to now provider when audit timestamp is invalid', 0, () => {
      let event = {
        eventId: securityAudit.NotifyEvent.FILE,
        timestamp: '20261302120000',
        userId: 100,
        content: JSON.stringify({
          description: 'blocked file access',
          outcome: 'blocked'
        }),
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event, () => 1712732400000)

      expect(!!entry).assertTrue()
      expect(entry!.timestamp).assertEqual(1712732400000)
    })
  })
}

function getDetailRows(entry?: LogEntry): LogDetailTableRow[] {
  return (entry as AuditLogEntryWithDetailRows | undefined)?.detailRows ?? []
}

function getRowValue(rows: LogDetailTableRow[], key: string): string {
  const row = rows.find((item: LogDetailTableRow) => item.key === key)
  return row ? row.value : ''
}

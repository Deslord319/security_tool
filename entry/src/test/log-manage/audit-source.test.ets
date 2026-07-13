import { describe, expect, it } from '@ohos/hypium'
import { securityAudit } from '@kit.DeviceSecurityKit'
import {
  LogDetailTableRow,
  LogEventType,
  LogEntry
} from '../../main/ets/models/LogModels'
import {
  formatLogTimestamp
} from '../../main/ets/viewmodels/log-manage/presentation/LogPresentationMapper'
import { parseAuditEventToLogEntry } from '../../main/ets/services/log-manage/source/LogAuditEventMapper'
import {
  API26_VERIFIED_FILE_AUDIT_EVENT_IDS,
  AUDIT_EVENT_DESCRIPTIONS_BY_ID,
  AUDIT_EVENT_TYPES_BY_ID,
  AUDIT_LOG_EVENT_IDS,
  AUTH_AUDIT_EVENT_IDS,
  CRASH_AUDIT_EVENT_IDS,
  FILE_AUDIT_EVENT_DESCRIPTIONS_BY_ID,
  FILE_AUDIT_EVENT_IDS
} from '../../main/ets/services/log-manage/source/LogAuditEventIds'

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

interface EdmCaller {
  abilityName: string
  bundleName: string
}

interface EdmAuditContent {
  caller: EdmCaller
  extra?: string
  objectInfo: string
  outcome: string
  subType: number
  targettInfo?: string
  type: number
}

interface EdmObjectInfoRemarkCase {
  objectInfo: string
  remark: string
}

interface EdmOperationTypeRemarkCase {
  operationType: number
  remark: string
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
      expect(rows.length).assertEqual(4)
      expect(getRowValue(rows, 'account.userName')).assertEqual('111')
      expect(getRowValue(rows, 'account.userId')).assertEqual('100')
      expect(getRowValue(rows, 'account.timestamp')).assertEqual(formatLogTimestamp(entry!.timestamp))
      expect(getRowValue(rows, 'account.eventId')).assertEqual(`${securityAudit.NotifyEvent.ACCOUNT}`)
    })

    it('should map authentication audit event ids into account log entries', 0, () => {
      const timestamp = '20260415162544'
      let successEvent = {
        eventId: AUTH_AUDIT_EVENT_IDS[1],
        timestamp,
        userId: 100,
        content: JSON.stringify({
          OPERATION_TIME: '2026-04-15 16:25:44',
          CALLER_NAME: 'com.huawei.securitytool',
          AUTH_TYPE: 1,
          AUTH_RESULT: 0,
          AUTH_TIME_SPAN: 197,
          AUTH_FINISH_REASON: 'SimpleAuthContext InvokeResultCallback'
        }),
        metadata: ''
      } as securityAudit.AuditEvent
      let failedEvent = {
        eventId: AUTH_AUDIT_EVENT_IDS[2],
        timestamp,
        userId: 100,
        content: JSON.stringify({
          HAPPEN_TIME: '2026-04-15 16:25:45.001',
          PNAMEID: 'com.ohos.sceneboard',
          AUTH_TYPE: 1,
          RESULT_CODE_LIST: [1]
        }),
        metadata: ''
      } as securityAudit.AuditEvent

      let successEntry = parseAuditEventToLogEntry(successEvent)
      let failedEntry = parseAuditEventToLogEntry(failedEvent)
      let successRows = getDetailRows(successEntry)

      expect(!!successEntry).assertTrue()
      expect(successEntry!.eventType).assertEqual(LogEventType.ACCOUNT)
      expect(successEntry!.processName).assertEqual('com.huawei.securitytool')
      expect(getRowValue(successRows, 'account.callerName')).assertEqual('com.huawei.securitytool')
      expect(getRowValue(successRows, 'account.authType')).assertEqual('1')
      expect(getRowValue(successRows, 'account.authResultRaw')).assertEqual('0')
      expect(getRowValue(successRows, 'account.operationTime')).assertEqual('2026-04-15 16:25:44')
      expect(!!failedEntry).assertTrue()
      expect(failedEntry!.eventType).assertEqual(LogEventType.ACCOUNT)
      expect(failedEntry!.processName).assertEqual('com.ohos.sceneboard')
    })

    it('should map crash audit event ids into crash log entries', 0, () => {
      const timestamp = '20260415162544'
      let appCrashEvent = {
        eventId: CRASH_AUDIT_EVENT_IDS[0],
        timestamp,
        userId: 100,
        content: JSON.stringify({
          eventName: 'app_crash',
          processName: 'com.example.demo',
          pid: 2345,
          uid: 20020123,
          message: 'application crash'
        }),
        metadata: ''
      } as securityAudit.AuditEvent
      let systemCrashEvent = {
        eventId: CRASH_AUDIT_EVENT_IDS[1],
        timestamp,
        userId: 100,
        content: JSON.stringify({
          EVENT_NAME: 'system_crash',
          process_name: 'foundation',
          pid: 3456,
          uid: 1000
        }),
        metadata: ''
      } as securityAudit.AuditEvent

      let appCrashEntry = parseAuditEventToLogEntry(appCrashEvent)
      let systemCrashEntry = parseAuditEventToLogEntry(systemCrashEvent)
      let appRows = getDetailRows(appCrashEntry)

      expect(!!appCrashEntry).assertTrue()
      expect(appCrashEntry!.eventType).assertEqual(LogEventType.CRASH)
      expect(appCrashEntry!.processName).assertEqual('com.example.demo')
      expect(getRowValue(appRows, 'crash.eventName')).assertEqual('app_crash')
      expect(getRowValue(appRows, 'crash.pid')).assertEqual('2345')
      expect(getRowValue(appRows, 'crash.eventId')).assertEqual(`${CRASH_AUDIT_EVENT_IDS[0]}`)
      expect(!!systemCrashEntry).assertTrue()
      expect(systemCrashEntry!.eventType).assertEqual(LogEventType.CRASH)
      expect(systemCrashEntry!.processName).assertEqual('foundation')
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
      expect(rows.length).assertEqual(7)
      expect(getRowValue(rows, 'file.operation')).assertEqual('file_write')
      expect(getRowValue(rows, 'file.filePath')).assertEqual('/data/storage/el2/base/files/demo.txt')
      expect(getRowValue(rows, 'file.processName')).assertEqual('demo-app')
      expect(getRowValue(rows, 'file.pid')).assertEqual('123')
      expect(getRowValue(rows, 'file.uid')).assertEqual('100')
      expect(getRowValue(rows, 'file.timestamp')).assertEqual(formatLogTimestamp(entry!.timestamp))
      expect(getRowValue(rows, 'file.eventId')).assertEqual(`${securityAudit.NotifyEvent.FILE}`)
    })

    it('should use renamed target path as primary file detail path and keep old path', 0, () => {
      const timestamp = '20260519141917'
      let event = {
        eventId: securityAudit.NotifyEvent.FILE,
        timestamp,
        userId: 100,
        content: JSON.stringify({
          event_name: 'file_rename',
          processName: 'com.huawei.hmos.filemanager',
          pid: 21556,
          uid: 20020023,
          file_path: '',
          file_oldpath: '/data/service/el2/100/hmdfs/account/files/Docs/Download/新建 文本文档.txt',
          file_newpath: '/data/service/el2/100/hmdfs/account/files/Docs/Download/333.txt'
        }),
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)
      let rows = getDetailRows(entry)

      expect(!!entry).assertTrue()
      expect(entry!.filePath).assertEqual('/storage/Users/currentUser/Download/333.txt')
      expect(getRowValue(rows, 'file.operation')).assertEqual('file_rename')
      expect(getRowValue(rows, 'file.filePath')).assertEqual('/storage/Users/currentUser/Download/333.txt')
      expect(getRowValue(rows, 'file.oldPath')).assertEqual('/storage/Users/currentUser/Download/新建 文本文档.txt')
      expect(getRowValue(rows, 'file.newPath')).assertEqual('/storage/Users/currentUser/Download/333.txt')
    })

    it('should include verified API26 file audit events in file subscription scope', 0, () => {
      const verifiedIds: number[] = [
        0x1C001104,
        0x1C001106,
        0x1C001109,
        0x1C00110A,
        0x1C00110B,
        0x1C00110C,
        0x1C00110D
      ]

      expect(API26_VERIFIED_FILE_AUDIT_EVENT_IDS.length).assertEqual(verifiedIds.length)
      for (const eventId of verifiedIds) {
        expect(API26_VERIFIED_FILE_AUDIT_EVENT_IDS.includes(eventId)).assertTrue()
        expect(FILE_AUDIT_EVENT_IDS.includes(eventId)).assertTrue()
        expect(AUDIT_EVENT_TYPES_BY_ID.get(eventId)).assertEqual(LogEventType.FILE)
      }
    })

    it('should expose verified API26 file audit event descriptions', 0, () => {
      expect(FILE_AUDIT_EVENT_DESCRIPTIONS_BY_ID.get(0x1C001104)).assertEqual('FILE_CREATE：文件创建事件')
      expect(FILE_AUDIT_EVENT_DESCRIPTIONS_BY_ID.get(0x1C001106)).assertEqual('FILE_CLOSE：文件关闭事件')
      expect(FILE_AUDIT_EVENT_DESCRIPTIONS_BY_ID.get(0x1C001109)).assertEqual('FILE_COPY：文件复制事件')
      expect(FILE_AUDIT_EVENT_DESCRIPTIONS_BY_ID.get(0x1C00110A)).assertEqual('FILE_SETOWNER：文件属主或属组变更事件')
      expect(FILE_AUDIT_EVENT_DESCRIPTIONS_BY_ID.get(0x1C00110B)).assertEqual('FILE_SETMODE：文件权限模式变更事件')
      expect(FILE_AUDIT_EVENT_DESCRIPTIONS_BY_ID.get(0x1C00110C)).assertEqual('FILE_SETEXTATTR：设置文件扩展属性事件')
      expect(FILE_AUDIT_EVENT_DESCRIPTIONS_BY_ID.get(0x1C00110D)).assertEqual('FILE_DELETEEXTATTR：删除文件扩展属性事件')
    })

    it('should map FILE_SETMODE description and new mode detail rows', 0, () => {
      let event = {
        eventId: 0x1C00110B,
        timestamp: '20260626103000',
        userId: 100,
        content: JSON.stringify({
          event_name: 'file_chmod',
          file_path: '/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/03_renamed.txt',
          file_newmode: '600'
        }),
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)
      let rows = getDetailRows(entry)

      expect(!!entry).assertTrue()
      expect(entry!.eventType).assertEqual(LogEventType.FILE)
      expect(getRowValue(rows, 'file.description')).assertEqual('FILE_SETMODE：文件权限模式变更事件')
      expect(getRowValue(rows, 'file.operation')).assertEqual('file_chmod')
      expect(getRowValue(rows, 'file.filePath')).assertEqual('/storage/Users/currentUser/Download/security_audit_probe_20260626/03_renamed.txt')
      expect(getRowValue(rows, 'file.newMode')).assertEqual('600')
    })

    it('should map FILE_SETOWNER new owner detail rows when fields exist', 0, () => {
      let event = {
        eventId: 0x1C00110A,
        timestamp: '20260626103100',
        userId: 100,
        content: JSON.stringify({
          event_name: 'file_chown',
          file_path: '/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/03_renamed.txt',
          file_newuid: 20001006,
          file_newgid: 1006
        }),
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)
      let rows = getDetailRows(entry)

      expect(!!entry).assertTrue()
      expect(getRowValue(rows, 'file.description')).assertEqual('FILE_SETOWNER：文件属主或属组变更事件')
      expect(getRowValue(rows, 'file.newUid')).assertEqual('20001006')
      expect(getRowValue(rows, 'file.newGid')).assertEqual('1006')
    })

    it('should map xattr name detail rows for verified API26 xattr file events', 0, () => {
      let setEvent = {
        eventId: 0x1C00110C,
        timestamp: '20260626103200',
        userId: 100,
        content: JSON.stringify({
          event_name: 'file_setxattr',
          file_path: '/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/03_renamed.txt',
          file_xattrname: 'user.security_audit_probe'
        }),
        metadata: ''
      } as securityAudit.AuditEvent
      let deleteEvent = {
        eventId: 0x1C00110D,
        timestamp: '20260626103300',
        userId: 100,
        content: JSON.stringify({
          event_name: 'file_removexattr',
          file_path: '/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/03_renamed.txt',
          file_xattrname: 'user.security_audit_probe'
        }),
        metadata: ''
      } as securityAudit.AuditEvent

      let setRows = getDetailRows(parseAuditEventToLogEntry(setEvent))
      let deleteRows = getDetailRows(parseAuditEventToLogEntry(deleteEvent))

      expect(getRowValue(setRows, 'file.description')).assertEqual('FILE_SETEXTATTR：设置文件扩展属性事件')
      expect(getRowValue(setRows, 'file.xattrName')).assertEqual('user.security_audit_probe')
      expect(getRowValue(deleteRows, 'file.description')).assertEqual('FILE_DELETEEXTATTR：删除文件扩展属性事件')
      expect(getRowValue(deleteRows, 'file.xattrName')).assertEqual('user.security_audit_probe')
    })

    it('should map FILE_COPY description and keep target path as primary path', 0, () => {
      let event = {
        eventId: 0x1C001109,
        timestamp: '20260626103400',
        userId: 100,
        content: JSON.stringify({
          event_name: 'file_copyfile',
          file_oldpath: '/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/01_create.txt',
          file_newpath: '/data/service/el2/100/hmdfs/account/files/Docs/Download/security_audit_probe_20260626/02_copy.txt'
        }),
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)
      let rows = getDetailRows(entry)

      expect(!!entry).assertTrue()
      expect(entry!.filePath).assertEqual('/storage/Users/currentUser/Download/security_audit_probe_20260626/02_copy.txt')
      expect(getRowValue(rows, 'file.description')).assertEqual('FILE_COPY：文件复制事件')
      expect(getRowValue(rows, 'file.oldPath')).assertEqual('/storage/Users/currentUser/Download/security_audit_probe_20260626/01_create.txt')
      expect(getRowValue(rows, 'file.newPath')).assertEqual('/storage/Users/currentUser/Download/security_audit_probe_20260626/02_copy.txt')
    })

    it('should map general notify events into audit log entries with raw json', 0, () => {
      const timestamp = '20260415162544'
      let event = {
        eventId: securityAudit.NotifyEvent.APP,
        timestamp,
        userId: 100,
        content: JSON.stringify({
          eventName: 'application_event',
          bundleName: 'com.example.demo'
        }),
        metadata: JSON.stringify({
          seqNum: 12,
          source: 'security_audit'
        })
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)
      let rows = getDetailRows(entry)
      let rawJson = getRowValue(rows, 'audit.rawJson')

      expect(!!entry).assertTrue()
      expect(entry!.eventType).assertEqual(LogEventType.AUDIT)
      expect(AUDIT_LOG_EVENT_IDS.includes(securityAudit.NotifyEvent.APP)).assertTrue()
      expect(rows.length).assertEqual(2)
      expect(getRowValue(rows, 'audit.description')).assertEqual('应用程序事件')
      expect(rawJson.indexOf('"eventId"') >= 0).assertTrue()
      expect(rawJson.indexOf(`${securityAudit.NotifyEvent.APP}`) >= 0).assertTrue()
      expect(rawJson.indexOf('application_event') >= 0).assertTrue()
      expect(rawJson.indexOf('security_audit') >= 0).assertTrue()
    })

    it('should append confirmed EDM object info remark rows for known device management events', 0, () => {
      const cases: EdmObjectInfoRemarkCase[] = [
        { objectInfo: 'disable_usb', remark: 'USB 接口管理' },
        { objectInfo: 'usb_read_only', remark: 'USB 存储访问策略' },
        { objectInfo: 'disabled_bluetooth', remark: '蓝牙管理' },
        { objectInfo: 'disable_wifi', remark: 'Wi-Fi 管理' },
        { objectInfo: 'disabled_printer', remark: '打印机管理' },
        { objectInfo: 'disable_microphone', remark: '麦克风管理' },
        { objectInfo: 'disable_camera', remark: '摄像头管理' },
        { objectInfo: 'disabled_hdc', remark: 'HDC 管理' },
        { objectInfo: 'disallowed_tethering', remark: '网络共享管理' },
        { objectInfo: 'get_network_interfaces', remark: '有线网络接口查询' },
        { objectInfo: 'disallowed_usb_devices', remark: 'USB 禁止设备类型策略' },
        { objectInfo: 'allowed_usb_devices', remark: 'USB 设备信任列表' },
        { objectInfo: 'set_switch_status', remark: '设备开关状态管理' }
      ]

      cases.forEach((item: EdmObjectInfoRemarkCase) => {
        const timestamp = '20260629171820'
        const content: EdmAuditContent = {
          caller: {
            abilityName: 'EnterpriseAdminAbility',
            bundleName: 'com.huawei.securitytool'
          },
          extra: '',
          objectInfo: item.objectInfo,
          outcome: '0',
          subType: 0,
          targettInfo: '',
          type: 1
        }
        const metadata: AuditMetadata = {
          version: '',
          userId: 100,
          deviceId: '5b3b4c74ded54969',
          timestamp,
          seqNum: 0
        }
        let event = {
          eventId: securityAudit.NotifyEvent.EDM,
          timestamp,
          userId: 100,
          content: JSON.stringify(content),
          metadata: JSON.stringify(metadata)
        } as securityAudit.AuditEvent

        let entry = parseAuditEventToLogEntry(event)
        let rows = getDetailRows(entry)

        expect(!!entry).assertTrue()
        expect(entry!.eventType).assertEqual(LogEventType.AUDIT)
        expect(getRowValue(rows, 'audit.description')).assertEqual('企业设备管理事件')
        expect(getRowValue(rows, 'audit.edm.objectInfo')).assertEqual(item.objectInfo)
        expect(getRowValue(rows, 'audit.edm.objectRemark')).assertEqual(item.remark)
        expect(getRowValue(rows, 'audit.edm.operationType')).assertEqual('type=1')
        expect(getRowValue(rows, 'audit.edm.operationTypeRemark')).assertEqual('设置/变更策略状态')
        expect(entry!.detail).assertEqual(`${item.remark} | 设置/变更策略状态`)
        expect(getRowValue(rows, 'audit.rawJson').indexOf(item.objectInfo) >= 0).assertTrue()
      })
    })

    it('should append EDM operation type remark rows for confirmed type values', 0, () => {
      const cases: EdmOperationTypeRemarkCase[] = [
        { operationType: 0, remark: '读取/查询策略状态' },
        { operationType: 1, remark: '设置/变更策略状态' }
      ]

      cases.forEach((item: EdmOperationTypeRemarkCase, index: number) => {
        const timestamp = `2026062917210${index}`
        const content: EdmAuditContent = {
          caller: {
            abilityName: 'EnterpriseAdminAbility',
            bundleName: 'com.huawei.securitytool'
          },
          objectInfo: 'disable_wifi',
          outcome: '0',
          subType: 0,
          type: item.operationType
        }
        let event = {
          eventId: securityAudit.NotifyEvent.EDM,
          timestamp,
          userId: 100,
          content: JSON.stringify(content),
          metadata: ''
        } as securityAudit.AuditEvent

        let entry = parseAuditEventToLogEntry(event)
        let rows = getDetailRows(entry)

        expect(!!entry).assertTrue()
        expect(getRowValue(rows, 'audit.description')).assertEqual('企业设备管理事件')
        expect(getRowValue(rows, 'audit.edm.operationType')).assertEqual(`type=${item.operationType}`)
        expect(getRowValue(rows, 'audit.edm.operationTypeRemark')).assertEqual(item.remark)
        expect(entry!.detail).assertEqual(`Wi-Fi 管理 | ${item.remark}`)
      })
    })

    it('should append only EDM object info row when object info has no confirmed remark', 0, () => {
      const timestamp = '20260629172000'
      const content: EdmAuditContent = {
        caller: {
          abilityName: 'EnterpriseAdminAbility',
          bundleName: 'com.huawei.securitytool'
        },
        objectInfo: 'disallowed_permissive_usb_devices',
        outcome: '0',
        subType: 0,
        type: 0
      }
      let event = {
        eventId: securityAudit.NotifyEvent.EDM,
        timestamp,
        userId: 100,
        content: JSON.stringify(content),
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)
      let rows = getDetailRows(entry)

      expect(!!entry).assertTrue()
      expect(getRowValue(rows, 'audit.description')).assertEqual('企业设备管理事件')
      expect(getRowValue(rows, 'audit.edm.objectInfo')).assertEqual('disallowed_permissive_usb_devices')
      expect(getRowValue(rows, 'audit.edm.objectRemark')).assertEqual('')
      expect(getRowValue(rows, 'audit.edm.operationType')).assertEqual('type=0')
      expect(getRowValue(rows, 'audit.edm.operationTypeRemark')).assertEqual('读取/查询策略状态')
      expect(entry!.detail).assertEqual('disallowed_permissive_usb_devices | 读取/查询策略状态')
      expect(getRowValue(rows, 'audit.rawJson').indexOf('disallowed_permissive_usb_devices') >= 0).assertTrue()
    })

    it('should not append EDM operation type remark row for unknown type values', 0, () => {
      const timestamp = '20260629172200'
      const content: EdmAuditContent = {
        caller: {
          abilityName: 'EnterpriseAdminAbility',
          bundleName: 'com.huawei.securitytool'
        },
        objectInfo: 'disable_wifi',
        outcome: '0',
        subType: 0,
        type: 9
      }
      let event = {
        eventId: securityAudit.NotifyEvent.EDM,
        timestamp,
        userId: 100,
        content: JSON.stringify(content),
        metadata: ''
      } as securityAudit.AuditEvent

      let entry = parseAuditEventToLogEntry(event)
      let rows = getDetailRows(entry)

      expect(!!entry).assertTrue()
      expect(getRowValue(rows, 'audit.edm.operationType')).assertEqual('type=9')
      expect(getRowValue(rows, 'audit.edm.operationTypeRemark')).assertEqual('')
      expect(entry!.detail).assertEqual('Wi-Fi 管理 | type=9')
    })

    it('should exclude high frequency network events from audit log subscription', 0, () => {
      expect(AUDIT_LOG_EVENT_IDS.includes(securityAudit.NotifyEvent.NETWORK_TRAFFIC)).assertFalse()
      expect(AUDIT_LOG_EVENT_IDS.includes(securityAudit.NotifyEvent.NETWORK_CONN)).assertFalse()
      expect(AUDIT_EVENT_TYPES_BY_ID.has(securityAudit.NotifyEvent.NETWORK_TRAFFIC)).assertFalse()
      expect(AUDIT_EVENT_TYPES_BY_ID.has(securityAudit.NotifyEvent.NETWORK_CONN)).assertFalse()
      expect(AUDIT_EVENT_DESCRIPTIONS_BY_ID.has(securityAudit.NotifyEvent.NETWORK_TRAFFIC)).assertFalse()
      expect(AUDIT_EVENT_DESCRIPTIONS_BY_ID.has(securityAudit.NotifyEvent.NETWORK_CONN)).assertFalse()
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

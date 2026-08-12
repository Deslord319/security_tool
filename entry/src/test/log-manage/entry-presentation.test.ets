import { describe, expect, it } from '@ohos/hypium'
import { LogEntry, LogEventType } from '../../main/ets/models/LogModels'
import {
  buildLogDetailViewData,
  buildLogListItemViewData
} from '../../main/ets/presentation/log-manage/LogEntryPresentationMapper'

function createEntry(): LogEntry {
  return {
    id: 'entry-1',
    timestamp: 1712732400000,
    eventType: LogEventType.AUDIT,
    eventKey: 'edm.policy_change',
    detail: 'edm.policy_change | disallow_usb',
    processName: 'edm_service',
    pid: 100,
    uid: 200,
    sourceEventId: 0x1C001109,
    fields: [
      { key: 'object.policy', value: 'disallow_usb' },
      { key: 'edm.operation_type', value: 1 },
      { key: 'actor.application', value: 'com.example.admin' }
    ]
  }
}

export default function logEntryPresentationTest() {
  describe('LogEntryPresentationMapper', () => {
    it('should build concise list content from semantic fields', 0, () => {
      const item = buildLogListItemViewData(createEntry())
      expect(item.eventLabel).assertEqual('企业策略变更')
      expect(item.title).assertEqual('禁止 USB')
      expect(item.context?.includes('com.example.admin')).assertTrue()
      expect(item.title.includes('{')).assertFalse()
    })

    it('should group detail fields and format known values', 0, () => {
      const detail = buildLogDetailViewData(createEntry())
      const overview = detail.sections.find((section): boolean => section.id === 'overview')
      const object = detail.sections.find((section): boolean => section.id === 'object')
      const technical = detail.sections.find((section): boolean => section.id === 'technical')

      expect(detail.title).assertEqual('企业策略变更')
      expect(overview?.fields[0].value).assertEqual('设置/变更策略状态')
      expect(object?.fields[0].value).assertEqual('禁止 USB')
      expect(technical?.fields.some((field): boolean => field.label === '源事件 ID')).assertTrue()
    })

    it('should provide a stable fallback for unknown event keys', 0, () => {
      const entry = createEntry()
      entry.eventKey = 'unknown.custom'
      entry.fields = []
      entry.processName = undefined
      entry.pid = undefined
      const item = buildLogListItemViewData(entry)
      expect(item.eventLabel).assertEqual('未知日志事件')
      expect(item.title).assertEqual('未知日志事件')
    })
  })
}

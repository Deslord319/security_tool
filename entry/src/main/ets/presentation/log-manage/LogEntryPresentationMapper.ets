import { LogEntry, LogField } from '../../models/LogModels'
import { formatStandardDateTime } from '../../utils/DateTimeFormatUtils'
import { getLogEventTypeLabel } from './LogPresentationMapper'
import { getLogEventDisplayDefinition } from './LogEventDisplayRegistry'
import {
  LogDetailSection,
  LogDetailViewData,
  LogDisplayField,
  LogListItemViewData
} from './LogEntryPresentationModels'

interface FieldDisplayDefinition {
  label: string
  sectionId: string
  sectionTitle: string
  fullWidth: boolean
}

const FIELD_DEFINITIONS: Map<string, FieldDisplayDefinition> = new Map<string, FieldDisplayDefinition>([
  ['event.action', field('操作', 'overview', '事件概览')],
  ['event.outcome', field('结果', 'overview', '事件概览')],
  ['event.risk_level', field('风险等级', 'overview', '事件概览')],
  ['event.duration', field('耗时', 'overview', '事件概览')],
  ['event.auth_type', field('认证方式', 'overview', '事件概览')],
  ['event.category', field('事件类别', 'overview', '事件概览')],
  ['event.crash_type', field('崩溃类型', 'overview', '事件概览')],
  ['event.summary', field('摘要', 'overview', '事件概览', true)],
  ['event.reason', field('原因', 'overview', '事件概览', true)],
  ['event.error_name', field('错误名称', 'overview', '事件概览')],
  ['event.error_message', field('错误消息', 'overview', '事件概览', true)],
  ['event.top_stack', field('Top stack', 'overview', '事件概览', true)],
  ['object.application', field('应用', 'object', '操作对象')],
  ['object.bundle_name', field('应用包名', 'object', '操作对象', true)],
  ['object.process_name', field('进程', 'object', '操作对象')],
  ['object.file_path', field('文件路径', 'object', '操作对象', true)],
  ['object.file_size', field('文件大小', 'object', '操作对象')],
  ['object.file_mode', field('文件权限', 'object', '操作对象')],
  ['object.user_name', field('用户名', 'object', '操作对象')],
  ['object.user_id', field('用户 ID', 'object', '操作对象')],
  ['object.domain', field('域名', 'object', '操作对象', true)],
  ['object.device', field('设备', 'object', '操作对象')],
  ['object.policy', field('策略对象', 'object', '操作对象', true)],
  ['actor.application', field('调用应用', 'actor', '操作主体')],
  ['actor.bundle_name', field('调用应用包名', 'actor', '操作主体', true)],
  ['actor.process_name', field('执行进程', 'actor', '操作主体')],
  ['change.old_path', field('原文件路径', 'change', '影响与变更', true)],
  ['change.new_path', field('新文件路径', 'change', '影响与变更', true)],
  ['change.new_mode', field('新文件权限', 'change', '影响与变更')],
  ['change.permission_name', field('权限名称', 'change', '影响与变更', true)],
  ['change.permission_state', field('权限状态', 'change', '影响与变更')],
  ['change.owner_uid', field('原属主 UID', 'change', '影响与变更')],
  ['change.owner_gid', field('原属组 GID', 'change', '影响与变更')],
  ['change.new_owner_uid', field('新属主 UID', 'change', '影响与变更')],
  ['change.new_owner_gid', field('新属组 GID', 'change', '影响与变更')],
  ['change.xattr_name', field('扩展属性名', 'change', '影响与变更')],
  ['edm.operation_type', field('操作类型', 'overview', '事件概览')],
  ['technical.rule_id', field('规则 ID', 'technical', '技术信息')],
  ['technical.source_file', field('来源文件', 'technical', '技术信息', true)],
  ['technical.line_number', field('行号', 'technical', '技术信息')],
  ['technical.string_id', field('STRINGID', 'technical', '技术信息', true)]
])

const SECTION_ORDER: string[] = ['overview', 'object', 'actor', 'change', 'technical']

function field(label: string, sectionId: string, sectionTitle: string, fullWidth: boolean = false): FieldDisplayDefinition {
  return { label, sectionId, sectionTitle, fullWidth }
}

export function buildLogListItemViewData(entry: LogEntry): LogListItemViewData {
  const definition = getLogEventDisplayDefinition(entry.eventKey)
  const primary = firstFieldValue(entry, definition.primaryKeys) || entry.filePath || entry.processName || definition.title
  const contexts: string[] = []
  for (const key of definition.contextKeys) appendDistinct(contexts, getFieldValue(entry, key))
  appendDistinct(contexts, entry.processName && entry.processName !== primary ? entry.processName : undefined)
  if (entry.pid !== undefined && contexts.length < 2) appendDistinct(contexts, `PID ${entry.pid}`)
  return {
    eventLabel: definition.title,
    title: primary,
    context: contexts.length > 0 ? contexts.slice(0, 2).join(' · ') : undefined
  }
}

export function buildLogDetailViewData(entry: LogEntry): LogDetailViewData {
  const eventDefinition = getLogEventDisplayDefinition(entry.eventKey)
  const sections = buildSections(entry)
  return {
    title: eventDefinition.title,
    typeLabel: getLogEventTypeLabel(entry.eventType),
    timestamp: formatStandardDateTime(entry.timestamp),
    sections
  }
}

function buildSections(entry: LogEntry): LogDetailSection[] {
  const sectionMap = new Map<string, LogDetailSection>()
  for (const sourceField of entry.fields || []) {
    const definition = FIELD_DEFINITIONS.get(sourceField.key)
    if (!definition) continue
    appendDisplayField(sectionMap, definition.sectionId, definition.sectionTitle, {
      key: sourceField.key,
      label: definition.label,
      value: formatFieldValue(sourceField),
      fullWidth: definition.fullWidth
    })
  }
  appendCommonTechnicalFields(sectionMap, entry)
  return SECTION_ORDER
    .map((id: string): LogDetailSection | undefined => sectionMap.get(id))
    .filter((section: LogDetailSection | undefined): boolean => section !== undefined) as LogDetailSection[]
}

function appendCommonTechnicalFields(sectionMap: Map<string, LogDetailSection>, entry: LogEntry): void {
  if (entry.processName && !hasDisplayedField(sectionMap, 'actor.process_name') && !hasDisplayedField(sectionMap, 'object.process_name')) {
    appendTechnical(sectionMap, 'common.process_name', '进程名称', entry.processName)
  }
  if (entry.pid !== undefined) appendTechnical(sectionMap, 'common.pid', 'PID', `${entry.pid}`)
  if (entry.uid !== undefined) appendTechnical(sectionMap, 'common.uid', 'UID', `${entry.uid}`)
  if (entry.remoteAddr) appendTechnical(sectionMap, 'common.remote_addr', '远端地址', entry.remoteAddr, true)
  if (entry.sourceEventId !== undefined) appendTechnical(sectionMap, 'common.event_id', '源事件 ID', formatEventId(entry.sourceEventId))
  if (entry.rawEventName) appendTechnical(sectionMap, 'common.event_name', '事件标识', entry.rawEventName)
}

function appendTechnical(
  sectionMap: Map<string, LogDetailSection>,
  key: string,
  label: string,
  value: string,
  fullWidth: boolean = false
): void {
  appendDisplayField(sectionMap, 'technical', '技术信息', { key, label, value, fullWidth })
}

function appendDisplayField(
  sectionMap: Map<string, LogDetailSection>,
  sectionId: string,
  sectionTitle: string,
  displayField: LogDisplayField
): void {
  let section = sectionMap.get(sectionId)
  if (!section) {
    section = { id: sectionId, title: sectionTitle, fields: [] }
    sectionMap.set(sectionId, section)
  }
  if (!section.fields.some((item: LogDisplayField): boolean => item.key === displayField.key)) {
    section.fields.push(displayField)
  }
}

function hasDisplayedField(sectionMap: Map<string, LogDetailSection>, key: string): boolean {
  for (const section of sectionMap.values()) {
    if (section.fields.some((item: LogDisplayField): boolean => item.key === key)) return true
  }
  return false
}

function firstFieldValue(entry: LogEntry, keys: string[]): string | undefined {
  for (const key of keys) {
    const value = getFieldValue(entry, key)
    if (value) return value
  }
  return undefined
}

function getFieldValue(entry: LogEntry, key: string): string | undefined {
  const source = (entry.fields || []).find((field: LogField): boolean => field.key === key)
  return source ? formatFieldValue(source) : undefined
}

function formatFieldValue(source: LogField): string {
  if (source.key === 'object.file_size' && typeof source.value === 'number') return formatFileSize(source.value)
  if ((source.key === 'object.file_mode' || source.key === 'change.new_mode') && typeof source.value === 'number') {
    return `0${source.value.toString(8)}`
  }
  if (source.key === 'edm.operation_type') {
    if (`${source.value}` === '0') return '读取/查询策略状态'
    if (`${source.value}` === '1') return '设置/变更策略状态'
    return `type=${source.value}`
  }
  if (source.key === 'object.policy') return formatEdmPolicy(`${source.value}`)
  if (source.key === 'event.duration' && typeof source.value === 'number') return `${source.value} ms`
  return `${source.value}`
}

function formatEdmPolicy(value: string): string {
  const labels = new Map<string, string>([
    ['disallow_add_local_account', '禁止添加本地账号'],
    ['disallow_modify_datetime', '禁止修改系统时间'],
    ['disallow_print', '禁止打印'],
    ['disallow_hdc', '禁止 HDC 调试'],
    ['disallow_usb', '禁止 USB'],
    ['disallow_bluetooth', '禁止蓝牙'],
    ['disallow_wifi', '禁止 WLAN']
  ])
  return labels.get(value) || value
}

function formatFileSize(value: number): string {
  if (value < 1024) return `${value} B`
  if (value < 1024 * 1024) return `${(value / 1024).toFixed(1)} KB`
  return `${(value / (1024 * 1024)).toFixed(1)} MB`
}

function formatEventId(eventId: number): string {
  return `0x${eventId.toString(16).toUpperCase()}`
}

function appendDistinct(values: string[], value?: string): void {
  const normalized = (value || '').trim()
  if (normalized.length > 0 && !values.includes(normalized)) values.push(normalized)
}

import { LogEntry, LogField } from '../../models/LogModels'
import { formatStandardDateTime } from '../../utils/DateTimeFormatUtils'
import { getLogEventTypeLabel } from './LogPresentationMapper'
import { getLogEventDisplayDefinition } from './LogEventDisplayRegistry'
import { AppStrings } from '../../constants/AppStrings'
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

interface FieldDisplayRegistration {
  labelResource: string
  literalLabel?: string
  sectionId: string
  sectionTitleResource: string
  fullWidth: boolean
}

/**
 * 字段展示定义注册表：注册项只保存资源名与展示键，字段标签与分组标题经
 * AppStrings 从 string.json 的 log_field_* / log_section_* 资源按当前
 * locale 解析，不在模块顶层常量中读取文案门面。
 */
const FIELD_DEFINITIONS: Map<string, FieldDisplayRegistration> = new Map<string, FieldDisplayRegistration>([
  ['event.action', field('log_field_event_action', 'overview', 'log_section_overview')],
  ['event.outcome', field('log_field_event_outcome', 'overview', 'log_section_overview')],
  ['event.risk_level', field('log_field_event_risk_level', 'overview', 'log_section_overview')],
  ['event.duration', field('log_field_event_duration', 'overview', 'log_section_overview')],
  ['event.auth_type', field('log_field_event_auth_type', 'overview', 'log_section_overview')],
  ['event.category', field('log_field_event_category', 'overview', 'log_section_overview')],
  ['event.crash_type', field('log_field_event_crash_type', 'overview', 'log_section_overview')],
  ['event.summary', field('log_field_event_summary', 'overview', 'log_section_overview', true)],
  ['event.reason', field('log_field_event_reason', 'overview', 'log_section_overview', true)],
  ['event.error_name', field('log_field_event_error_name', 'overview', 'log_section_overview')],
  ['event.error_message', field('log_field_event_error_message', 'overview', 'log_section_overview', true)],
  ['event.top_stack', defineLiteral('Top stack', 'overview', 'log_section_overview', true)],
  ['object.application', field('log_field_object_application', 'object', 'log_section_object')],
  ['object.bundle_name', field('log_field_object_bundle_name', 'object', 'log_section_object', true)],
  ['object.process_name', field('log_field_object_process_name', 'object', 'log_section_object')],
  ['object.file_path', field('log_field_object_file_path', 'object', 'log_section_object', true)],
  ['object.file_size', field('log_field_object_file_size', 'object', 'log_section_object')],
  ['object.file_mode', field('log_field_object_file_mode', 'object', 'log_section_object')],
  ['object.user_name', field('log_field_object_user_name', 'object', 'log_section_object')],
  ['object.user_id', field('log_field_object_user_id', 'object', 'log_section_object')],
  ['object.domain', field('log_field_object_domain', 'object', 'log_section_object', true)],
  ['object.device', field('log_field_object_device', 'object', 'log_section_object')],
  ['object.policy', field('log_field_object_policy', 'object', 'log_section_object', true)],
  ['actor.application', field('log_field_actor_application', 'actor', 'log_section_actor')],
  ['actor.bundle_name', field('log_field_actor_bundle_name', 'actor', 'log_section_actor', true)],
  ['actor.process_name', field('log_field_actor_process_name', 'actor', 'log_section_actor')],
  ['change.old_path', field('log_field_change_old_path', 'change', 'log_section_change', true)],
  ['change.new_path', field('log_field_change_new_path', 'change', 'log_section_change', true)],
  ['change.new_mode', field('log_field_change_new_mode', 'change', 'log_section_change')],
  ['change.permission_name', field('log_field_change_permission_name', 'change', 'log_section_change', true)],
  ['change.permission_state', field('log_field_change_permission_state', 'change', 'log_section_change')],
  ['change.owner_uid', field('log_field_change_owner_uid', 'change', 'log_section_change')],
  ['change.owner_gid', field('log_field_change_owner_gid', 'change', 'log_section_change')],
  ['change.new_owner_uid', field('log_field_change_new_owner_uid', 'change', 'log_section_change')],
  ['change.new_owner_gid', field('log_field_change_new_owner_gid', 'change', 'log_section_change')],
  ['change.xattr_name', field('log_field_change_xattr_name', 'change', 'log_section_change')],
  ['edm.operation_type', field('log_field_edm_operation_type', 'overview', 'log_section_overview')],
  ['technical.rule_id', field('log_field_technical_rule_id', 'technical', 'log_section_technical')],
  ['technical.source_file', field('log_field_technical_source_file', 'technical', 'log_section_technical', true)],
  ['technical.line_number', field('log_field_technical_line_number', 'technical', 'log_section_technical')],
  ['technical.string_id', defineLiteral('STRINGID', 'technical', 'log_section_technical', true)]
])

const SECTION_ORDER: string[] = ['overview', 'object', 'actor', 'change', 'technical']

function field(labelResource: string, sectionId: string, sectionTitleResource: string, fullWidth: boolean = false): FieldDisplayRegistration {
  return { labelResource, sectionId, sectionTitleResource, fullWidth }
}

function defineLiteral(label: string, sectionId: string, sectionTitleResource: string, fullWidth: boolean): FieldDisplayRegistration {
  return { labelResource: '', literalLabel: label, sectionId, sectionTitleResource, fullWidth }
}

function resolveFieldDefinition(registration: FieldDisplayRegistration): FieldDisplayDefinition {
  return {
    label: registration.literalLabel !== undefined && registration.literalLabel.length > 0 ?
      registration.literalLabel :
      AppStrings.get(registration.labelResource),
    sectionId: registration.sectionId,
    sectionTitle: AppStrings.get(registration.sectionTitleResource),
    fullWidth: registration.fullWidth
  }
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
    const registration = FIELD_DEFINITIONS.get(sourceField.key)
    if (!registration) continue
    const definition = resolveFieldDefinition(registration)
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
    appendTechnical(sectionMap, 'common.process_name', AppStrings.get('log_field_common_process_name'), entry.processName)
  }
  if (entry.pid !== undefined) appendTechnical(sectionMap, 'common.pid', 'PID', `${entry.pid}`)
  if (entry.uid !== undefined) appendTechnical(sectionMap, 'common.uid', 'UID', `${entry.uid}`)
  if (entry.remoteAddr) appendTechnical(sectionMap, 'common.remote_addr', AppStrings.get('log_field_common_remote_addr'), entry.remoteAddr, true)
  if (entry.sourceEventId !== undefined) appendTechnical(sectionMap, 'common.event_id', AppStrings.get('log_field_common_event_id'), formatEventId(entry.sourceEventId))
  if (entry.rawEventName) appendTechnical(sectionMap, 'common.event_name', AppStrings.get('log_field_common_event_name'), entry.rawEventName)
}

function appendTechnical(
  sectionMap: Map<string, LogDetailSection>,
  key: string,
  label: string,
  value: string,
  fullWidth: boolean = false
): void {
  appendDisplayField(sectionMap, 'technical', AppStrings.get('log_section_technical'), { key, label, value, fullWidth })
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
    if (`${source.value}` === '0') return AppStrings.get('log_edm_operation_type_read')
    if (`${source.value}` === '1') return AppStrings.get('log_edm_operation_type_set')
    return `type=${source.value}`
  }
  if (source.key === 'object.policy') return formatEdmPolicy(`${source.value}`)
  if (source.key === 'event.duration' && typeof source.value === 'number') return `${source.value} ms`
  return `${source.value}`
}

function formatEdmPolicy(value: string): string {
  const labelResources = new Map<string, string>([
    ['disallow_add_local_account', 'log_edm_policy_disallow_add_local_account'],
    ['disallow_modify_datetime', 'log_edm_policy_disallow_modify_datetime'],
    ['disallow_print', 'log_edm_policy_disallow_print'],
    ['disallow_hdc', 'log_edm_policy_disallow_hdc'],
    ['disallow_usb', 'log_edm_policy_disallow_usb'],
    ['disallow_bluetooth', 'log_edm_policy_disallow_bluetooth'],
    ['disallow_wifi', 'log_edm_policy_disallow_wifi']
  ])
  const labelResource = labelResources.get(value)
  return labelResource ? AppStrings.get(labelResource) : value
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

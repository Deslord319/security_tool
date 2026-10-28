import { AppStrings } from '../../constants/AppStrings'

interface LogEventDisplayDefinition {
  title: string
  primaryKeys: string[]
  contextKeys: string[]
}

interface LogEventDisplayRegistration {
  titleResource: string
  primaryKeys: string[]
  contextKeys: string[]
}

/**
 * 事件显示名称注册表：注册项只保存资源名与展示键，事件标题经 AppStrings
 * 从 string.json 的 log_event_* 资源按当前 locale 解析，不在模块顶层常量
 * 中读取文案门面。
 */
const DEFINITIONS: Map<string, LogEventDisplayRegistration> = new Map<string, LogEventDisplayRegistration>([
  ['file.access', define('log_event_file_access', ['object.file_path'], ['actor.process_name'])],
  ['file.intercepted', define('log_event_file_intercepted', ['object.file_path'], ['actor.process_name', 'event.outcome'])],
  ['file.create', define('log_event_file_create', ['object.file_path'], ['actor.process_name'])],
  ['file.open', define('log_event_file_open', ['object.file_path'], ['actor.process_name'])],
  ['file.close', define('log_event_file_close', ['object.file_path'], ['actor.process_name'])],
  ['file.delete', define('log_event_file_delete', ['object.file_path'], ['actor.process_name'])],
  ['file.rename', define('log_event_file_rename', ['change.new_path', 'object.file_path'], ['change.old_path', 'actor.process_name'])],
  ['file.copy', define('log_event_file_copy', ['change.new_path', 'object.file_path'], ['change.old_path', 'actor.process_name'])],
  ['file.write', define('log_event_file_write', ['object.file_path'], ['actor.process_name'])],
  ['file.owner_change', define('log_event_file_owner_change', ['object.file_path'], ['actor.process_name'])],
  ['file.mode_change', define('log_event_file_mode_change', ['object.file_path'], ['change.new_mode', 'actor.process_name'])],
  ['file.xattr_set', define('log_event_file_xattr_set', ['object.file_path'], ['change.xattr_name', 'actor.process_name'])],
  ['file.xattr_delete', define('log_event_file_xattr_delete', ['object.file_path'], ['change.xattr_name', 'actor.process_name'])],
  ['account.authentication', define('log_event_account_authentication', ['object.user_name'], ['event.outcome', 'actor.process_name'])],
  ['permission.change', define('log_event_permission_change', ['change.permission_name'], ['object.bundle_name', 'change.permission_state'])],
  ['device.power_on', define('log_event_device_power_on', [], [])],
  ['device.power_off', define('log_event_device_power_off', [], [])],
  ['crash.runtime', define('log_event_crash_runtime', ['object.process_name'], ['event.reason'])],
  ['crash.process_abnormal', define('log_event_crash_process_abnormal', ['object.process_name'], ['event.reason'])],
  ['crash.app_freeze', define('log_event_crash_app_freeze', ['object.process_name'], ['event.reason'])],
  ['crash.javascript', define('log_event_crash_javascript', ['object.process_name'], ['event.reason'])],
  ['crash.native', define('log_event_crash_native', ['object.process_name'], ['event.reason'])],
  ['app.lifecycle', define('log_event_app_lifecycle', ['object.application', 'object.bundle_name'], ['actor.process_name'])],
  ['app.start', define('log_event_app_start', ['object.application', 'object.bundle_name'], ['actor.process_name'])],
  ['app.exit', define('log_event_app_exit', ['object.application', 'object.bundle_name'], ['actor.process_name'])],
  ['process.lifecycle', define('log_event_process_lifecycle', ['object.process_name'], ['actor.process_name'])],
  ['process.create', define('log_event_process_create', ['object.process_name'], ['actor.process_name'])],
  ['process.exit', define('log_event_process_exit', ['object.process_name'], ['actor.process_name'])],
  ['network.dns', define('log_event_network_dns', ['object.domain'], ['actor.process_name', 'event.outcome'])],
  ['network.intercepted', define('log_event_network_intercepted', ['object.domain'], ['actor.process_name', 'event.outcome'])],
  ['network.wifi_intercepted', define('log_event_network_wifi_intercepted', ['object.domain'], ['actor.process_name', 'event.outcome'])],
  ['edm.policy_read', define('log_event_edm_policy_read', ['object.policy'], ['actor.application'])],
  ['edm.policy_change', define('log_event_edm_policy_change', ['object.policy'], ['actor.application'])],
  ['edm.policy_operation', define('log_event_edm_policy_operation', ['object.policy'], ['actor.application'])],
  ['process.debug_abnormal', define('log_event_process_debug_abnormal', ['object.process_name'], ['event.risk_level'])],
  ['process.privilege_escalation', define('log_event_process_privilege_escalation', ['object.process_name', 'object.file_path'], ['event.risk_level'])],
  ['device.camera', define('log_event_device_camera', ['object.application', 'object.device'], ['event.action'])],
  ['device.printer', define('log_event_device_printer', ['object.application', 'object.device'], ['event.action'])],
  ['device.print_intercepted', define('log_event_device_print_intercepted', ['object.application', 'object.device'], ['event.outcome'])],
  ['data.clipboard', define('log_event_data_clipboard', ['object.application'], ['event.action'])],
  ['debug.hdc', define('log_event_debug_hdc', ['object.application'], ['event.action'])],
  ['debug.hdc_intercepted', define('log_event_debug_hdc_intercepted', ['object.application'], ['event.outcome'])]
])

function define(titleResource: string, primaryKeys: string[], contextKeys: string[]): LogEventDisplayRegistration {
  return { titleResource, primaryKeys, contextKeys }
}

function resolveDisplay(registration: LogEventDisplayRegistration): LogEventDisplayDefinition {
  return {
    title: AppStrings.get(registration.titleResource),
    primaryKeys: registration.primaryKeys,
    contextKeys: registration.contextKeys
  }
}

export function getLogEventDisplayDefinition(eventKey: string): LogEventDisplayDefinition {
  const exact = DEFINITIONS.get(eventKey)
  if (exact) return resolveDisplay(exact)
  if (eventKey.startsWith('system.')) return resolveDisplay(define('log_event_system_fallback', ['event.summary'], ['event.category']))
  if (eventKey.startsWith('kernel.')) return resolveDisplay(define('log_event_kernel_fallback', ['object.file_path', 'object.process_name'], ['event.category']))
  if (eventKey.startsWith('file.kia_')) return resolveDisplay(define('log_event_file_kia_fallback', ['object.file_path'], ['actor.process_name']))
  if (eventKey.startsWith('app.') && eventKey.endsWith('_intercepted')) return resolveDisplay(define('log_event_app_intercepted_fallback', ['object.application', 'object.bundle_name'], ['event.outcome']))
  if (eventKey.startsWith('security.')) return resolveDisplay(define('log_event_security_fallback', ['object.process_name', 'object.file_path'], ['event.risk_level']))
  if (eventKey.startsWith('data.')) return resolveDisplay(define('log_event_data_fallback', ['object.file_path', 'object.application'], ['event.action']))
  if (eventKey.startsWith('device.')) return resolveDisplay(define('log_event_device_fallback', ['object.device', 'object.application'], ['event.action']))
  if (eventKey.startsWith('media.')) return resolveDisplay(define('log_event_media_fallback', ['object.application'], ['event.action']))
  if (eventKey.startsWith('storage.')) return resolveDisplay(define('log_event_storage_fallback', ['object.device'], ['event.action']))
  return resolveDisplay(define('log_event_unknown', [], []))
}

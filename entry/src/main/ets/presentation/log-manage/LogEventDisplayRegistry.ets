interface LogEventDisplayDefinition {
  title: string
  primaryKeys: string[]
  contextKeys: string[]
}
const DEFINITIONS: Map<string, LogEventDisplayDefinition> = new Map<string, LogEventDisplayDefinition>([
  ['file.access', define('文件访问', ['object.file_path'], ['actor.process_name'])],
  ['file.intercepted', define('文件访问被拦截', ['object.file_path'], ['actor.process_name', 'event.outcome'])],
  ['file.create', define('文件创建', ['object.file_path'], ['actor.process_name'])],
  ['file.open', define('文件打开', ['object.file_path'], ['actor.process_name'])],
  ['file.close', define('文件关闭', ['object.file_path'], ['actor.process_name'])],
  ['file.delete', define('文件删除', ['object.file_path'], ['actor.process_name'])],
  ['file.rename', define('文件重命名', ['change.new_path', 'object.file_path'], ['change.old_path', 'actor.process_name'])],
  ['file.copy', define('文件复制', ['change.new_path', 'object.file_path'], ['change.old_path', 'actor.process_name'])],
  ['file.write', define('文件写入', ['object.file_path'], ['actor.process_name'])],
  ['file.owner_change', define('文件属主变更', ['object.file_path'], ['actor.process_name'])],
  ['file.mode_change', define('文件权限模式变更', ['object.file_path'], ['change.new_mode', 'actor.process_name'])],
  ['file.xattr_set', define('设置文件扩展属性', ['object.file_path'], ['change.xattr_name', 'actor.process_name'])],
  ['file.xattr_delete', define('删除文件扩展属性', ['object.file_path'], ['change.xattr_name', 'actor.process_name'])],
  ['account.authentication', define('账户认证', ['object.user_name'], ['event.outcome', 'actor.process_name'])],
  ['permission.change', define('权限变更', ['change.permission_name'], ['object.bundle_name', 'change.permission_state'])],
  ['device.power_on', define('设备启动', [], [])],
  ['device.power_off', define('设备关闭', [], [])],
  ['crash.runtime', define('应用崩溃', ['object.process_name'], ['event.reason'])],
  ['crash.process_abnormal', define('进程异常崩溃', ['object.process_name'], ['event.reason'])],
  ['crash.app_freeze', define('应用冻结', ['object.process_name'], ['event.reason'])],
  ['crash.javascript', define('JavaScript 崩溃', ['object.process_name'], ['event.reason'])],
  ['crash.native', define('Native 崩溃', ['object.process_name'], ['event.reason'])],
  ['app.lifecycle', define('应用程序事件', ['object.application', 'object.bundle_name'], ['actor.process_name'])],
  ['app.start', define('应用启动', ['object.application', 'object.bundle_name'], ['actor.process_name'])],
  ['app.exit', define('应用退出', ['object.application', 'object.bundle_name'], ['actor.process_name'])],
  ['process.lifecycle', define('进程事件', ['object.process_name'], ['actor.process_name'])],
  ['process.create', define('进程创建', ['object.process_name'], ['actor.process_name'])],
  ['process.exit', define('进程退出', ['object.process_name'], ['actor.process_name'])],
  ['network.dns', define('DNS 查询', ['object.domain'], ['actor.process_name', 'event.outcome'])],
  ['network.intercepted', define('网络访问拦截', ['object.domain'], ['actor.process_name', 'event.outcome'])],
  ['network.wifi_intercepted', define('Wi-Fi 访问拦截', ['object.domain'], ['actor.process_name', 'event.outcome'])],
  ['edm.policy_read', define('企业策略查询', ['object.policy'], ['actor.application'])],
  ['edm.policy_change', define('企业策略变更', ['object.policy'], ['actor.application'])],
  ['edm.policy_operation', define('企业策略操作', ['object.policy'], ['actor.application'])],
  ['process.debug_abnormal', define('进程调试异常', ['object.process_name'], ['event.risk_level'])],
  ['process.privilege_escalation', define('进程权限提升', ['object.process_name', 'object.file_path'], ['event.risk_level'])],
  ['device.camera', define('摄像头事件', ['object.application', 'object.device'], ['event.action'])],
  ['device.printer', define('打印机事件', ['object.application', 'object.device'], ['event.action'])],
  ['device.print_intercepted', define('打印操作拦截', ['object.application', 'object.device'], ['event.outcome'])],
  ['data.clipboard', define('剪贴板事件', ['object.application'], ['event.action'])],
  ['debug.hdc', define('HDC 调试', ['object.application'], ['event.action'])],
  ['debug.hdc_intercepted', define('HDC 调试拦截', ['object.application'], ['event.outcome'])]
])

function define(title: string, primaryKeys: string[], contextKeys: string[]): LogEventDisplayDefinition {
  return { title, primaryKeys, contextKeys }
}

export function getLogEventDisplayDefinition(eventKey: string): LogEventDisplayDefinition {
  const exact = DEFINITIONS.get(eventKey)
  if (exact) return exact
  if (eventKey.startsWith('system.')) return define('系统日志', ['event.summary'], ['event.category'])
  if (eventKey.startsWith('kernel.')) return define('内核安全事件', ['object.file_path', 'object.process_name'], ['event.category'])
  if (eventKey.startsWith('file.kia_')) return define('文件安全事件', ['object.file_path'], ['actor.process_name'])
  if (eventKey.startsWith('app.') && eventKey.endsWith('_intercepted')) return define('应用操作拦截', ['object.application', 'object.bundle_name'], ['event.outcome'])
  if (eventKey.startsWith('security.')) return define('安全异常事件', ['object.process_name', 'object.file_path'], ['event.risk_level'])
  if (eventKey.startsWith('data.')) return define('数据操作事件', ['object.file_path', 'object.application'], ['event.action'])
  if (eventKey.startsWith('device.')) return define('设备安全事件', ['object.device', 'object.application'], ['event.action'])
  if (eventKey.startsWith('media.')) return define('屏幕媒体事件', ['object.application'], ['event.action'])
  if (eventKey.startsWith('storage.')) return define('存储设备事件', ['object.device'], ['event.action'])
  return define('未知日志事件', [], [])
}

/**
 * 通用对话框字符串常量
 *
 * 统一管理所有对话框组件中的硬编码文字，包括：
 * - 加载状态文本
 * - 空状态提示
 */

export class LoadingStrings {
  static readonly LOADING: string = '加载中...'
  static readonly LOADING_USERS: string = '正在加载用户列表...'
  static readonly LOADING_RULES: string = '正在加载规则...'
  static readonly APPLYING_MODE: string = '正在应用防火墙模式...'
}

export class EmptyStateStrings {
  static readonly NO_USERS: string = '暂无可选用户'
  static readonly NO_RECORDS: string = '暂无连接记录'
  static readonly NO_RULES: string = '暂无自定义规则'
  static readonly NO_DEVICES: string = '暂无可管理的设备'
  static readonly NO_RESULTS: string = '未找到相关结果'
}

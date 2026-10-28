/**
 * 通用对话框字符串资源门面
 *
 * 文案唯一来源为 resources/{base,en_US}/element/string.json 中的 common_* 资源，
 * 经 AppStrings 资源管理器按当前 locale 解析。单元测试环境（AppStrings 未
 * 初始化）下门面返回资源名；相关断言必须经门面构造，不得断言字面量。
 */
import { AppStrings } from '../AppStrings'

export class LoadingStrings {
  static get LOADING(): string {
    return AppStrings.get('common_loading')
  }

  static get LOADING_USERS(): string {
    return AppStrings.get('common_loading_users')
  }

  static get LOADING_RULES(): string {
    return AppStrings.get('common_loading_rules')
  }

  static get APPLYING_MODE(): string {
    return AppStrings.get('common_applying_mode')
  }
}

export class EmptyStateStrings {

  static get NO_RECORDS(): string {
    return AppStrings.get('common_empty_no_records')
  }



  static get NO_RESULTS(): string {
    return AppStrings.get('common_empty_no_results')
  }
}

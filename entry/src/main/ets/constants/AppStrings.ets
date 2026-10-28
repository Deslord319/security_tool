/**
 * 文案资源统一取值器
 *
 * 所有用户可见文案的唯一来源是 resources/{base,en_US}/element/string.json。
 * 逻辑层（Service / ViewModel / 页面经共享组件传递的文案）不直接持有 $r 资源对象，
 * 而是经各模块 *Strings 门面类调用本类按资源名取值，保证文案在 ArkUI 组件之外
 * （弹窗、系统认证参数、@Concurrent 调用方等）也能以 string 使用。
 *
 * 使用约束：
 * - EntryAbility.onCreate 中必须先调用 init(context)，再加载页面或执行业务逻辑；
 * - @Concurrent 任务池函数运行在独立 worker，本类静态上下文对其不可见；
 *   任务内文案必须在主线程先取好值，再作为参数传入任务；
 * - 未初始化（本地单测环境）或资源缺失时返回资源名本身，保证单元测试断言稳定，
 *   相关断言必须经 *Strings 门面构造，不得断言中文或英文字面量。
 */
import { common } from '@kit.AbilityKit'
import { LogUtils } from '../utils/LogUtils'

const TAG = 'AppStrings'

export class AppStrings {
  private static context: common.Context | null = null

  static init(context: common.Context): void {
    AppStrings.context = context
  }

  static get(name: string): string {
    let context = AppStrings.context
    if (context === null) {
      return name
    }
    try {
      return context.resourceManager.getStringByNameSync(name)
    } catch (err) {
      LogUtils.error(TAG, `get string failed | name=${name}, err=${JSON.stringify(err)}`)
      return name
    }
  }

  static format(name: string, ...args: Array<string | number>): string {
    let context = AppStrings.context
    if (context === null) {
      return args.length > 0 ? `${name}(${args.join(', ')})` : name
    }
    try {
      return context.resourceManager.getStringByNameSync(name, ...args)
    } catch (err) {
      LogUtils.error(TAG, `format string failed | name=${name}, err=${JSON.stringify(err)}`)
      return args.length > 0 ? `${name}(${args.join(', ')})` : name
    }
  }
}

/**
 * 统一日志工具类
 * 
 * 简化日志调用，固定 DOMAIN，只需传入 TAG 和消息
 * 
 * 使用示例:
 * ```ets
 * LogUtils.info('MyTag', '消息内容')
 * LogUtils.error('MyTag', '错误内容')
 * ```
 */
import { hilog } from '@kit.PerformanceAnalysisKit'

/**
 * 固定 DOMAIN 值
 * 所有日志使用同一个 DOMAIN，通过 TAG 区分模块
 */
const DOMAIN = 0x0000

export class LogUtils {
  /**
   * 输出 INFO 级别日志
   * @param tag 标签（通常是类名或模块名）
   * @param message 日志内容
   */
  static info(tag: string, message: string): void {
    hilog.info(DOMAIN, tag, message)
  }
  
  /**
   * 输出 WARN 级别日志
   * @param tag 标签
   * @param message 日志内容
   */
  static warn(tag: string, message: string): void {
    hilog.warn(DOMAIN, tag, message)
  }
  
  /**
   * 输出 ERROR 级别日志
   * @param tag 标签
   * @param message 日志内容
   */
  static error(tag: string, message: string): void {
    hilog.error(DOMAIN, tag, message)
  }
  
  /**
   * 输出 DEBUG 级别日志
   * @param tag 标签
   * @param message 日志内容
   */
  static debug(tag: string, message: string): void {
    hilog.debug(DOMAIN, tag, message)
  }
}

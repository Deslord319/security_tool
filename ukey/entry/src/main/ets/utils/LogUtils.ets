import { hilog } from '@kit.PerformanceAnalysisKit'

const LOG_DOMAIN = 0x0001

export class LogUtils {
  static info(tag: string, format: string, ...args: Object[]): void {
    hilog.info(LOG_DOMAIN, tag, format, ...args)
  }

  static warn(tag: string, format: string, ...args: Object[]): void {
    hilog.warn(LOG_DOMAIN, tag, format, ...args)
  }

  static error(tag: string, format: string, ...args: Object[]): void {
    hilog.error(LOG_DOMAIN, tag, format, ...args)
  }
}

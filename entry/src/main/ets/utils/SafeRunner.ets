import { LogUtils } from './LogUtils'
import { ErrorLike } from '../types/LooseValueTypes'

export class SafeRunner {
  static run<T, F>(tag: string, op: string, fn: () => T, onError: (err: ErrorLike) => F): T | F {
    try {
      return fn()
    } catch (err) {
      const error = err as ErrorLike
      LogUtils.error(tag, `${op} failed: ${JSON.stringify(error)}`)
      return onError(error)
    }
  }

  static async runAsync<T, F>(
    tag: string,
    op: string,
    fn: () => Promise<T>,
    onError: (err: ErrorLike) => F
  ): Promise<T | F> {
    try {
      return await fn()
    } catch (err) {
      const error = err as ErrorLike
      LogUtils.error(tag, `${op} failed: ${JSON.stringify(error)}`)
      return onError(error)
    }
  }
}

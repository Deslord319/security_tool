import { LogUtils } from '../utils/LogUtils'
import { AbilityConstant, AbilityStage } from '@kit.AbilityKit'

const TAG = 'EntryAbilityStage'

/**
 * 应用级关闭统一拦截（对齐 logbox ST-RUNTIME-001 桌面运行时基线）：
 * Dock 退出、系统关闭请求等应用级终止在此处理——一律隐藏窗口保持常驻，
 * 状态栏托盘与后台采集不中断；真正的进程退出仅由系统关机或强制停止完成。
 * 窗口级关闭仍由 EntryAbility.onPrepareToTerminate 隐藏处理。
 */
export default class EntryAbilityStage extends AbilityStage {
  async onPrepareTerminationAsync(): Promise<AbilityConstant.PrepareTermination> {
    LogUtils.info(TAG, 'application close intercepted | keep resident with tray alive')
    return AbilityConstant.PrepareTermination.CANCEL
  }
}

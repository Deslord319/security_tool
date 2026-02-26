/**
 * OpenHarmony 测试运行器
 * 负责初始化测试环境并执行测试用例
 */
import { TestRunner, abilityDelegatorRegistry } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG = 'OpenHarmonyTestRunner'
const DOMAIN = 0x0000

async function onAbilityCreateCallback(): Promise<void> {
  hilog.info(DOMAIN, TAG, 'onAbilityCreateCallback')
}

async function addAbilityMonitorCallback(err: Error): Promise<void> {
  hilog.info(DOMAIN, TAG, 'addAbilityMonitorCallback: %{public}s', JSON.stringify(err) ?? '')
}

export default class OpenHarmonyTestRunner implements TestRunner {
  constructor() {
  }

  onPrepare(): void {
    hilog.info(DOMAIN, TAG, 'onPrepare')
  }

  async onRun(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onRun start')

    let abilityDelegatorArguments = abilityDelegatorRegistry.getArguments()
    let abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator()

    let testAbilityName = abilityDelegatorArguments.parameters['-p'] + '.TestAbility'
    hilog.info(DOMAIN, TAG, 'testAbilityName: %{public}s', testAbilityName)

    let lMonitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: testAbilityName,
      onAbilityCreate: onAbilityCreateCallback
    }
    abilityDelegator.addAbilityMonitor(lMonitor, addAbilityMonitorCallback)

    let cmd = 'aa start -a TestAbility -b ' + abilityDelegatorArguments.bundleName
    hilog.info(DOMAIN, TAG, 'cmd: %{public}s', cmd)

    await abilityDelegator.executeShellCommand(cmd, 5000)

    hilog.info(DOMAIN, TAG, 'onRun end')
  }
}

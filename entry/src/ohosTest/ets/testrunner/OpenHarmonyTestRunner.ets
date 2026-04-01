/**
 * OpenHarmony test runner.
 */
import { TestRunner, abilityDelegatorRegistry } from '@kit.TestKit'
import { TestLogUtils } from '../utils/TestLogUtils'

const TAG = 'OpenHarmonyTestRunner'

async function onAbilityCreateCallback(): Promise<void> {
  TestLogUtils.info(TAG, 'onAbilityCreateCallback')
}

async function addAbilityMonitorCallback(err: Error): Promise<void> {
  TestLogUtils.info(TAG, 'addAbilityMonitorCallback: %{public}s', JSON.stringify(err) ?? '')
}

export default class OpenHarmonyTestRunner implements TestRunner {
  constructor() {
  }

  onPrepare(): void {
    TestLogUtils.info(TAG, 'onPrepare')
  }

  async onRun(): Promise<void> {
    TestLogUtils.info(TAG, 'onRun start')

    let abilityDelegatorArguments = abilityDelegatorRegistry.getArguments()
    let abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator()

    let testAbilityName = abilityDelegatorArguments.parameters['-p'] + '.TestAbility'
    TestLogUtils.info(TAG, 'testAbilityName: %{public}s', testAbilityName)

    let lMonitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: testAbilityName,
      onAbilityCreate: onAbilityCreateCallback
    }
    abilityDelegator.addAbilityMonitor(lMonitor, addAbilityMonitorCallback)

    let cmd = 'aa start -a TestAbility -b ' + abilityDelegatorArguments.bundleName
    TestLogUtils.info(TAG, 'cmd: %{public}s', cmd)

    await abilityDelegator.executeShellCommand(cmd, 5000)

    TestLogUtils.info(TAG, 'onRun end')
  }
}

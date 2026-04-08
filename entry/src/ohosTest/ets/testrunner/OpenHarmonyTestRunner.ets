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

    const args = abilityDelegatorRegistry.getArguments()
    let abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator()
    const testAbilityName = 'TestAbility'

    TestLogUtils.info(TAG, 'testAbilityName: %{public}s', testAbilityName)

    let lMonitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: testAbilityName,
      onAbilityCreate: onAbilityCreateCallback
    }
    abilityDelegator.addAbilityMonitor(lMonitor, addAbilityMonitorCallback)

    TestLogUtils.info(TAG, 'start ability: %{public}s/%{public}s', args.bundleName, testAbilityName)
    abilityDelegator.startAbility({
      bundleName: args.bundleName,
      abilityName: testAbilityName
    }, (_err, _data) => {
    })

    TestLogUtils.info(TAG, 'onRun end')
  }
}

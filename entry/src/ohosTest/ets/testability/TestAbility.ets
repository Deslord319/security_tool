/**
 * Test ability used by ohosTest.
 */
import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { Hypium } from '@ohos/hypium'
import { window } from '@kit.ArkUI'
import testsuite from '../test/List.test'
import { TestLogUtils } from '../utils/TestLogUtils'

const TAG = 'TestAbility'

export default class TestAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    TestLogUtils.info(TAG, 'TestAbility onCreate')
  }

  onDestroy(): void {
    TestLogUtils.info(TAG, 'TestAbility onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    TestLogUtils.info(TAG, 'TestAbility onWindowStageCreate')

    windowStage.loadContent('testrunner/pages/Index', (err) => {
      if (err.code) {
        TestLogUtils.error(TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err) ?? '')
        return
      }
      TestLogUtils.info(TAG, 'Succeeded in loading content.')
    })

    TestLogUtils.info(TAG, 'start run testcase!!!')

    // Run the test suite through Hypium.
    const abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator()
    const abilityDelegatorArguments = abilityDelegatorRegistry.getArguments()

    Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite)
  }

  onWindowStageDestroy(): void {
    TestLogUtils.info(TAG, 'TestAbility onWindowStageDestroy')
  }

  onForeground(): void {
    TestLogUtils.info(TAG, 'TestAbility onForeground')
  }

  onBackground(): void {
    TestLogUtils.info(TAG, 'TestAbility onBackground')
  }
}

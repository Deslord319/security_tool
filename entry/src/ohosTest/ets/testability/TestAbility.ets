/**
 * TestAbility - 测试专用 Ability
 * 用于执行 ohosTest 测试用例
 */
import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { abilityDelegatorRegistry } from '@kit.TestKit'
import { Hypium } from '@ohos/hypium'
import { window } from '@kit.ArkUI'
import testsuite from '../test/List.test'

const TAG = 'TestAbility'
const DOMAIN = 0x0000

export default class TestAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onCreate')
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onDestroy')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onWindowStageCreate')

    windowStage.loadContent('testrunner/pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err) ?? '')
        return
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading content.')
    })

    hilog.info(DOMAIN, TAG, 'start run testcase!!!')

    // 使用 Hypium 框架正确执行测试
    const abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator()
    const abilityDelegatorArguments = abilityDelegatorRegistry.getArguments()

    Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite)
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onWindowStageDestroy')
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onForeground')
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'TestAbility onBackground')
  }
}

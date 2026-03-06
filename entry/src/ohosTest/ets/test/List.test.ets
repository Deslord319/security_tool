import { abilityDelegatorRegistry } from '@kit.TestKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import abilityTest from './common/Ability.test'
import routeActionTest from './simple/RouteAction.test'

export default function testsuite() {
  const args = abilityDelegatorRegistry.getArguments()
  const mode = args?.parameters?.['mode']
  const argsText = JSON.stringify(args) ?? ''

  hilog.info(0x0000, 'ListTest', 'mode=%{public}s args=%{public}s', mode ?? '', argsText)

  if (mode === 'route_action' || argsText.indexOf('route_action') >= 0 || argsText.indexOf('scenario_id') >= 0) {
    routeActionTest()
    return
  }

  // Keep a minimal smoke case for non-route invocations.
  abilityTest()
}

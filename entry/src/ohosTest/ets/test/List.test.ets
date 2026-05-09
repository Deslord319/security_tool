import { abilityDelegatorRegistry } from '@kit.TestKit'
import { TestLogUtils } from '../utils/TestLogUtils'
import abilityTest from './common/Ability.test'
import peripheralConnectionRecordContractTest from './peripheral/connection-record-contract.test'
import routeActionTest from './simple/RouteAction.test'
import themeMenuPopupTest from './theme/theme-menu-popup.test'
import firewallSubrouteStateTest from './firewall/subroute-state.test'

export default function testsuite() {
  const args = abilityDelegatorRegistry.getArguments()
  const mode = args?.parameters?.['mode']
  const argsText = JSON.stringify(args) ?? ''

  TestLogUtils.info('ListTest', 'mode=%{public}s args=%{public}s', mode ?? '', argsText)

  if (mode === 'route_action' || argsText.indexOf('route_action') >= 0 || argsText.indexOf('scenario_id') >= 0) {
    routeActionTest()
    return
  }

  if (mode === 'peripheral_contract' || argsText.indexOf('peripheral_contract') >= 0) {
    peripheralConnectionRecordContractTest()
    return
  }

  if (mode === 'theme_menu' || argsText.indexOf('theme_menu') >= 0) {
    themeMenuPopupTest()
    return
  }

  if (mode === 'firewall_subroute' || argsText.indexOf('firewall_subroute') >= 0) {
    firewallSubrouteStateTest()
    return
  }

  // Keep the default device-side suite to a single stable smoke case.
  abilityTest()
}

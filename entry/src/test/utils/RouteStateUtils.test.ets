import { describe, expect, it } from '@ohos/hypium'
import { RouteIds } from '../../main/ets/constants/RouteIds'
import {
  rememberFirewallRoute,
  resolveNavigationRoute,
  resolveSidebarSelectedRoute
} from '../../main/ets/utils/RouteStateUtils'

export default function routeStateUtilsTest() {
  describe('RouteStateUtils', () => {
    it('should keep firewall selected when current route is rules page', 0, () => {
      expect(resolveSidebarSelectedRoute(RouteIds.FIREWALL_RULES)).assertEqual(RouteIds.FIREWALL)
      expect(resolveSidebarSelectedRoute(RouteIds.IDENTITY)).assertEqual(RouteIds.IDENTITY)
    })

    it('should restore last firewall sub route from module entry', 0, () => {
      expect(resolveNavigationRoute(RouteIds.FIREWALL, RouteIds.FIREWALL_RULES)).assertEqual(RouteIds.FIREWALL_RULES)
      expect(resolveNavigationRoute(RouteIds.FIREWALL, RouteIds.FIREWALL)).assertEqual(RouteIds.FIREWALL)
      expect(resolveNavigationRoute(RouteIds.LOG_MANAGE, RouteIds.FIREWALL_RULES)).assertEqual(RouteIds.LOG_MANAGE)
    })

    it('should update last firewall route only for firewall pages', 0, () => {
      let lastRoute = rememberFirewallRoute(RouteIds.FIREWALL, RouteIds.FIREWALL_RULES)
      expect(lastRoute).assertEqual(RouteIds.FIREWALL_RULES)

      lastRoute = rememberFirewallRoute(lastRoute, RouteIds.IDENTITY)
      expect(lastRoute).assertEqual(RouteIds.FIREWALL_RULES)

      lastRoute = rememberFirewallRoute(lastRoute, RouteIds.FIREWALL)
      expect(lastRoute).assertEqual(RouteIds.FIREWALL)
    })
  })
}

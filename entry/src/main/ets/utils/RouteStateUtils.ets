import { RouteIds } from '../constants/RouteIds'

export function isFirewallRoute(route: string): boolean {
  return route === RouteIds.FIREWALL || route === RouteIds.FIREWALL_RULES
}

export function rememberFirewallRoute(currentLastRoute: string, nextRoute: string): string {
  return isFirewallRoute(nextRoute) ? nextRoute : currentLastRoute
}

export function resolveNavigationRoute(targetRoute: string, lastFirewallRoute: string): string {
  if (targetRoute === RouteIds.FIREWALL && isFirewallRoute(lastFirewallRoute)) {
    return lastFirewallRoute
  }
  return targetRoute
}

export function resolveSidebarSelectedRoute(currentRoute: string): string {
  return currentRoute === RouteIds.FIREWALL_RULES ? RouteIds.FIREWALL : currentRoute
}

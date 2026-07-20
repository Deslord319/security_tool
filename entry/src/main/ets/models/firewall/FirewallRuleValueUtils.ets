import { netFirewall } from '@kit.NetworkKit'
import { FIREWALL_PORT_MIN } from './FirewallModels'

export class FirewallRuleValueUtils {
  static normalizePortParams(
    source?: netFirewall.NetFirewallPortParams[]
  ): netFirewall.NetFirewallPortParams[] | undefined {
    if (!source || source.length === 0) {
      return undefined
    }
    let result: netFirewall.NetFirewallPortParams[] = []
    source.forEach((item: netFirewall.NetFirewallPortParams) => {
      let startPort = FirewallRuleValueUtils.normalizeNumber(item.startPort)
      let endPort = FirewallRuleValueUtils.normalizeNumber(item.endPort)
      if (startPort === undefined && endPort === undefined) {
        return
      }
      let resolvedStartPort = startPort ?? endPort ?? FIREWALL_PORT_MIN
      let resolvedEndPort = endPort ?? startPort ?? resolvedStartPort
      result.push({ startPort: resolvedStartPort, endPort: resolvedEndPort })
    })
    if (result.length === 0) {
      return undefined
    }
    return FirewallRuleValueUtils.sortAndDedupPortParams(result)
  }

  static sortAndDedupPortParams(ports: netFirewall.NetFirewallPortParams[]): netFirewall.NetFirewallPortParams[] {
    let sorted = ports.slice().sort((left: netFirewall.NetFirewallPortParams, right: netFirewall.NetFirewallPortParams): number => {
      let startDiff = (left.startPort ?? 0) - (right.startPort ?? 0)
      if (startDiff !== 0) {
        return startDiff
      }
      return (left.endPort ?? left.startPort ?? 0) - (right.endPort ?? right.startPort ?? 0)
    })
    let deduped: netFirewall.NetFirewallPortParams[] = []
    sorted.forEach((item: netFirewall.NetFirewallPortParams) => {
      let previous = deduped[deduped.length - 1]
      if (previous &&
        previous.startPort === item.startPort &&
        previous.endPort === item.endPort) {
        return
      }
      deduped.push(item)
    })
    return deduped
  }

  private static normalizeNumber(value?: number): number | undefined {
    return value !== undefined && Number.isFinite(value) ? value : undefined
  }
}

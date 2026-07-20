import { netFirewall } from '@kit.NetworkKit'
import { FIREWALL_IPV4_MASK_MAX } from '../../../models/firewall/FirewallModels'
import { FirewallRuleValueUtils } from '../../../models/firewall/FirewallRuleValueUtils'

export class FirewallRulePresentationMapper {
  static formatIpParams(params?: netFirewall.NetFirewallIpParams[]): string {
    if (!params || params.length === 0) {
      return ''
    }
    let ip = params[0]
    if (typeof ip.startIp === 'string' && typeof ip.endIp === 'string' &&
      ip.startIp.trim().length > 0 && ip.endIp.trim().length > 0) {
      return `${ip.startIp.trim()}-${ip.endIp.trim()}`
    }
    if (typeof ip.address !== 'string' || ip.address.trim().length === 0) {
      return ''
    }
    let address = ip.address.trim()
    let mask = ip.mask !== undefined && Number.isFinite(ip.mask) ? ip.mask : undefined
    return mask === undefined || mask >= FIREWALL_IPV4_MASK_MAX ? address : `${address}/${mask}`
  }

  static formatPortParams(params?: netFirewall.NetFirewallPortParams[]): string {
    let normalized = FirewallRuleValueUtils.normalizePortParams(params)
    if (!normalized || normalized.length === 0) {
      return ''
    }
    return normalized.map((port: netFirewall.NetFirewallPortParams): string => {
      let startPort = port.startPort ?? 0
      let endPort = port.endPort ?? startPort
      return startPort === endPort ? `${startPort}` : `${startPort}-${endPort}`
    }).join(',')
  }
}

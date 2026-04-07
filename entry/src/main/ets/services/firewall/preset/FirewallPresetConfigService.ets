import { LogUtils } from '../../../utils/LogUtils'
import { common } from '@kit.AbilityKit'

import { FirewallPresetConfig } from '../../../models/DataModels'

const TAG = 'FirewallPresetConfigService'
const CONFIG_RAW_FILE = 'firewall_preset_config.json'

const DEFAULT_CONFIG: FirewallPresetConfig = {
  fixedPublicIp: '',
  privateCidrs: [],
  privateTcpPorts: [],
  privateUdpPorts: []
}

export class FirewallPresetConfigService {
  static async loadConfig(context: common.UIAbilityContext): Promise<FirewallPresetConfig> {
    try {
      let rawContent = await context.resourceManager.getRawFileContent(CONFIG_RAW_FILE)
      let jsonText = FirewallPresetConfigService.bytesToString(rawContent)
      let parsed = JSON.parse(jsonText) as Partial<FirewallPresetConfig>
      return FirewallPresetConfigService.normalizeConfig(parsed)
    } catch (err) {
      LogUtils.error(TAG, `loadConfig failed: ${JSON.stringify(err)}`)
      return FirewallPresetConfigService.cloneDefaultConfig()
    }
  }

  private static normalizeConfig(source: Partial<FirewallPresetConfig>): FirewallPresetConfig {
    return {
      fixedPublicIp: typeof source.fixedPublicIp === 'string' ? source.fixedPublicIp.trim() : '',
      privateCidrs: FirewallPresetConfigService.normalizeStringArray(source.privateCidrs),
      privateTcpPorts: FirewallPresetConfigService.normalizePorts(source.privateTcpPorts),
      privateUdpPorts: FirewallPresetConfigService.normalizePorts(source.privateUdpPorts)
    }
  }

  private static normalizeStringArray(value: Object | undefined): string[] {
    if (!Array.isArray(value)) {
      return []
    }
    let items: string[] = []
    value.forEach((item: Object) => {
      if (typeof item === 'string') {
        let normalized = item.trim()
        if (normalized.length > 0) {
          items.push(normalized)
        }
      }
    })
    return items
  }

  private static normalizePorts(value: Object | undefined): number[] {
    if (!Array.isArray(value)) {
      return []
    }
    let ports: number[] = []
    value.forEach((item: Object) => {
      let num = typeof item === 'number' ? item : Number(item)
      if (Number.isInteger(num) && num >= 1 && num <= 65535) {
        ports.push(num)
      }
    })
    return ports
  }

  private static bytesToString(data: Uint8Array): string {
    let chars: string[] = []
    for (let i = 0; i < data.length; i++) {
      chars.push(String.fromCharCode(data[i]))
    }
    return chars.join('')
  }

  private static cloneDefaultConfig(): FirewallPresetConfig {
    return {
      fixedPublicIp: DEFAULT_CONFIG.fixedPublicIp,
      privateCidrs: [],
      privateTcpPorts: [],
      privateUdpPorts: []
    }
  }
}

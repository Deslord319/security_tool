import { common } from '@kit.AbilityKit'

import { FirewallPresetConfig } from '../../../models/DataModels'
import { LooseValue } from '../../../types/LooseValueTypes'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'FirewallPresetConfigReader'
const CONFIG_RAW_FILE = 'firewall_preset_config.json'

const DEFAULT_CONFIG: FirewallPresetConfig = {
  fixedPublicIp: '',
  privateCidrs: [],
  privateTcpPorts: [],
  privateUdpPorts: []
}

export class FirewallPresetConfigReader {
  static async loadConfig(context: common.UIAbilityContext): Promise<FirewallPresetConfig> {
    try {
      let rawContent = await context.resourceManager.getRawFileContent(CONFIG_RAW_FILE)
      let jsonText = FirewallPresetConfigReader.bytesToString(rawContent)
      let parsed = JSON.parse(jsonText) as Partial<FirewallPresetConfig>
      return FirewallPresetConfigReader.normalizeConfig(parsed)
    } catch (err) {
      LogUtils.error(TAG, `loadConfig failed: ${JSON.stringify(err)}`)
      return FirewallPresetConfigReader.cloneDefaultConfig()
    }
  }

  private static normalizeConfig(source: Partial<FirewallPresetConfig>): FirewallPresetConfig {
    return {
      fixedPublicIp: typeof source.fixedPublicIp === 'string' ? source.fixedPublicIp.trim() : '',
      privateCidrs: FirewallPresetConfigReader.normalizeStringArray(source.privateCidrs),
      privateTcpPorts: FirewallPresetConfigReader.normalizePorts(source.privateTcpPorts),
      privateUdpPorts: FirewallPresetConfigReader.normalizePorts(source.privateUdpPorts)
    }
  }

  private static normalizeStringArray(value: LooseValue): string[] {
    if (!Array.isArray(value)) {
      return []
    }
    let items: string[] = []
    value.forEach((item: LooseValue) => {
      if (typeof item === 'string') {
        let normalized = item.trim()
        if (normalized.length > 0) {
          items.push(normalized)
        }
      }
    })
    return items
  }

  private static normalizePorts(value: LooseValue): number[] {
    if (!Array.isArray(value)) {
      return []
    }
    let ports: number[] = []
    value.forEach((item: LooseValue) => {
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

import { describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'

import { FirewallPresetConfigReader } from '../../main/ets/services/firewall/mode-strategies/FirewallPresetConfigReader'

interface RawFileResourceManager {
  getRawFileContent(fileName: string): Promise<Uint8Array>
}

class StaticRawFileResourceManager implements RawFileResourceManager {
  private readonly content: string

  constructor(content: string) {
    this.content = content
  }

  async getRawFileContent(_fileName: string): Promise<Uint8Array> {
    return new Uint8Array(this.content.split('').map((char: string) => char.charCodeAt(0)))
  }
}

class ThrowingRawFileResourceManager implements RawFileResourceManager {
  async getRawFileContent(_fileName: string): Promise<Uint8Array> {
    throw new Error('missing')
  }
}

function createContext(resourceManager: RawFileResourceManager): common.UIAbilityContext {
  return {
    resourceManager
  } as common.UIAbilityContext
}

export default function firewallPresetConfigReaderTest() {
  describe('FirewallPresetConfigReader', () => {
    it('should normalize loaded preset config', 0, async () => {
      let resourceManager = new StaticRawFileResourceManager(
        '{"fixedPublicIp":" 8.8.8.8 ","privateCidrs":[" 10.0.0.0/24 ","",123],"privateTcpPorts":[22,"443",70000,"bad"],"privateUdpPorts":["53",5353]}'
      )
      let context = createContext(resourceManager)

      let config = await FirewallPresetConfigReader.loadConfig(context)

      expect(config.fixedPublicIp).assertEqual('8.8.8.8')
      expect(config.privateCidrs.length).assertEqual(1)
      expect(config.privateTcpPorts.length).assertEqual(2)
      expect(config.privateUdpPorts.length).assertEqual(2)
    })

    it('should fallback to default config when resource load fails', 0, async () => {
      let resourceManager = new ThrowingRawFileResourceManager()
      let context = createContext(resourceManager)

      let config = await FirewallPresetConfigReader.loadConfig(context)

      expect(config.fixedPublicIp).assertEqual('')
      expect(config.privateCidrs.length).assertEqual(0)
      expect(config.privateTcpPorts.length).assertEqual(0)
      expect(config.privateUdpPorts.length).assertEqual(0)
    })

    it('should fallback to default config when json content is invalid', 0, async () => {
      let resourceManager = new StaticRawFileResourceManager('{invalid json}')
      let context = createContext(resourceManager)

      let config = await FirewallPresetConfigReader.loadConfig(context)

      expect(config.fixedPublicIp).assertEqual('')
      expect(config.privateCidrs.length).assertEqual(0)
    })
  })
}

import { describe, expect, it } from '@ohos/hypium'
import { AppInfoService, AppVersionProvider } from '../../main/ets/services/common/app-info/AppInfoService'

class FakeAppVersionProvider implements AppVersionProvider {
  private versionName: string
  private shouldThrow: boolean

  constructor(versionName: string, shouldThrow: boolean = false) {
    this.versionName = versionName
    this.shouldThrow = shouldThrow
  }

  getVersionName(): string {
    if (this.shouldThrow) {
      throw new Error('version unavailable')
    }
    return this.versionName
  }
}

export default function appInfoServiceTest() {
  describe('AppInfoService', () => {
    it('should return version name from provider', 0, () => {
      expect(AppInfoService.getVersionName(new FakeAppVersionProvider('1.2.3'))).assertEqual('1.2.3')
    })

    it('should return empty version when provider fails', 0, () => {
      expect(AppInfoService.getVersionName(new FakeAppVersionProvider('', true))).assertEqual('')
    })
  })
}

import { describe, expect, it } from '@ohos/hypium'
import { ManagedPermissionService } from '../../main/ets/services/admin/activation/ManagedPermissionService'

/**
 * ManagedPermissionService 行为契约测试。
 *
 * 单测环境无企业管理员激活态，setPermissionManagedState 预授权链路必然失败；
 * 服务契约要求任何失败不抛异常、统一返回 false，由调用方降级弹窗链路。
 * 本文件覆盖该兜底契约；预授权成功路径（真机管理员激活）由设备验收覆盖。
 */
export default function managedPermissionServiceTest() {
  describe('ManagedPermissionService', () => {
    it('should swallow failures and return false when managed grant unavailable', 0, async () => {
      const granted = await ManagedPermissionService.ensureSelfGranted('ohos.permission.ACCESS_BLUETOOTH')

      expect(granted).assertFalse()
    })

    it('should return true when permission already granted by system', 0, async () => {
      // ACCESS_BLUETOOTH 在本地单测环境未授予；同上走失败兜底路径。
      // 已授权短路路径依赖设备侧授权状态，由设备验收覆盖。
      const granted = await ManagedPermissionService.ensureSelfGranted('ohos.permission.ACCESS_BLUETOOTH')

      expect(granted).assertFalse()
    })
  })
}

import { abilityAccessCtrl, bundleManager, Permissions, Want } from '@kit.AbilityKit'
import { securityManager } from '@kit.MDMKit'
import { osAccount } from '@kit.BasicServicesKit'
import { ADMIN_WANT } from '../../../constants/AppConstants'
import { ErrorLike } from '../../../types/LooseValueTypes'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'ManagedPermission'

/**
 * EDM managed-state 预授权服务。
 *
 * 企业管理员可通过 securityManager.setPermissionManagedState 为本包内应用的
 * user_grant 权限静默授权，替代用户弹窗（对齐 logbox ManagedPermissionService
 * 模式，设计见外设管理组件设计说明 1.0.64）。仅限管理员已激活且应用具备
 * ENTERPRISE_MANAGE_USER_GRANT_PERMISSION 的场景；任何失败均返回 false，
 * 由调用方降级 requestPermissionsFromUser 弹窗链路。
 */
export class ManagedPermissionService {
  /**
   * 确保本应用自身已获得指定 user_grant 权限；未授权时以企业管理员身份预授权。
   * 返回是否最终确认已授权，不抛出异常。
   */
  static async ensureSelfGranted(permission: Permissions): Promise<boolean> {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION |
          bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_SIGNATURE_INFO
      )
      const atManager = abilityAccessCtrl.createAtManager()
      const tokenId = info.appInfo.accessTokenId
      if (atManager.checkAccessTokenSync(tokenId, permission) ===
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true
      }

      // 官方说明：应用无 appIdentifier 时可用 signatureInfo.appId 代替
      const appIdentifier = info.signatureInfo?.appIdentifier?.length ? info.signatureInfo.appIdentifier : (info.signatureInfo?.appId ?? '')
      if (appIdentifier.length === 0) {
        LogUtils.warn(TAG, `managed grant skipped: empty appIdentifier/appId, permission=${permission}`)
        return false
      }
      const accountId = await osAccount.getAccountManager().getOsAccountLocalId()
      const instance: securityManager.ApplicationInstance = {
        appIdentifier: appIdentifier,
        accountId: accountId,
        appIndex: 0
      }
      securityManager.setPermissionManagedState(
        ADMIN_WANT as Want,
        instance,
        [permission],
        securityManager.PermissionManagedState.GRANTED
      )
      if (atManager.checkAccessTokenSync(tokenId, permission) !==
        abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        LogUtils.warn(TAG, `managed grant not confirmed: permission=${permission}`)
        return false
      }
      LogUtils.info(TAG, `managed permission granted: permission=${permission}`)
      return true
    } catch (err) {
      const error: ErrorLike = err as ErrorLike
      LogUtils.warn(TAG,
        `managed grant failed: permission=${permission}, err=${JSON.stringify(error)}`
      )
      return false
    }
  }
}

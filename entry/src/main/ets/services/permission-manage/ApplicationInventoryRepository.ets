import { bundleManager as enterpriseBundleManager } from '@kit.MDMKit'
import { ADMIN_WANT, AppInfo } from '../../constants/AppConstants'
import { ApplicationInventoryResult, PermissionAppSnapshot } from '../../models/PermissionModels'
import { PermissionEmptyStrings } from '../../constants/modules/PermissionStrings'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'ApplicationInventoryRepository'
const NON_MANAGEABLE_BUNDLE_BLOCKLIST: string[] = [
  'com.ohos.formrenderservice',
  'com.huawei.hmos.arkwebcore',
  'com.huawei.hmos.arkwebcorelegacy',
  'com.ohos.backgroundtaskmgr.resources'
]
const NON_MANAGEABLE_LABEL_KEYWORDS: string[] = [
  'fromrenderservice',
  'arkweb',
  '方舟web',
  '长时任务通知资源'
]

export interface ApplicationInventoryRawRecord {
  bundleName: string
  label?: string
  appId?: string
  appIndex?: number
  uid?: number
  versionName?: string
  iconData?: string
  systemApp?: boolean
  removable?: boolean
  installSource?: string
  appDistributionType?: string
  mainAbilityName?: string
}

export class ApplicationInventoryRepository {
  static async loadApplications(accountId: number): Promise<ApplicationInventoryResult> {
    try {
      let bundleInfos = await enterpriseBundleManager.getInstalledBundleList(
        ADMIN_WANT,
        accountId,
        enterpriseBundleManager.BundleInfoGetFlag.WITH_APPLICATION_INFO |
          enterpriseBundleManager.BundleInfoGetFlag.WITH_SIGNATURE_INFO
      )
      let applications = ApplicationInventoryRepository.normalizeBundleInfos(accountId, bundleInfos)
      return {
        appSnapshots: applications,
        installPolicies: [],
        message: applications.length === 0 ? PermissionEmptyStrings.APPLICATIONS : ''
      } as ApplicationInventoryResult
    } catch (err) {
      LogUtils.warn(TAG, `loadApplications failed: ${JSON.stringify(err)}`)
      return {
        appSnapshots: [],
        installPolicies: [],
        message: PermissionEmptyStrings.INVENTORY_LOAD_FAILED
      } as ApplicationInventoryResult
    }
  }

  static normalizeBundleInfos(
    accountId: number,
    bundleInfos: enterpriseBundleManager.BundleInfo[],
    selfBundleName: string = AppInfo.BUNDLE_NAME
  ): PermissionAppSnapshot[] {
    let records = bundleInfos.map((bundleInfo: enterpriseBundleManager.BundleInfo): ApplicationInventoryRawRecord =>
      ApplicationInventoryRepository.toRawRecord(bundleInfo)
    )
    return ApplicationInventoryRepository.normalizeApplications(accountId, records, selfBundleName)
  }

  private static toRawRecord(bundleInfo: enterpriseBundleManager.BundleInfo): ApplicationInventoryRawRecord {
    return {
      bundleName: bundleInfo.name,
      label: bundleInfo.appInfo?.label,
      appId: bundleInfo.signatureInfo?.appId,
      appIndex: bundleInfo.appIndex ?? bundleInfo.appInfo?.appIndex,
      uid: bundleInfo.appInfo?.uid,
      versionName: bundleInfo.versionName,
      iconData: bundleInfo.appInfo?.iconData,
      systemApp: bundleInfo.appInfo?.systemApp,
      removable: bundleInfo.appInfo?.removable,
      installSource: bundleInfo.appInfo?.installSource,
      appDistributionType: bundleInfo.appInfo?.appDistributionType
    } as ApplicationInventoryRawRecord
  }

  static normalizeApplications(
    accountId: number,
    records: ApplicationInventoryRawRecord[],
    selfBundleName: string = AppInfo.BUNDLE_NAME
  ): PermissionAppSnapshot[] {
    return records
      .filter((record: ApplicationInventoryRawRecord): boolean =>
        ApplicationInventoryRepository.isManageableApplication(record, selfBundleName)
      )
      .map((record: ApplicationInventoryRawRecord): PermissionAppSnapshot =>
        ApplicationInventoryRepository.toAppSnapshot(accountId, record)
      )
      .sort((left: PermissionAppSnapshot, right: PermissionAppSnapshot): number =>
        ApplicationInventoryRepository.compareApplications(left, right)
      )
  }

  static filterApplications(applications: PermissionAppSnapshot[], keyword: string): PermissionAppSnapshot[] {
    let normalizedKeyword = keyword.trim().toLowerCase()
    if (normalizedKeyword.length === 0) {
      return applications
    }
    return applications.filter((app: PermissionAppSnapshot): boolean =>
      app.label.toLowerCase().includes(normalizedKeyword) ||
        app.bundleName.toLowerCase().includes(normalizedKeyword)
    )
  }

  static buildAppKey(accountId: number, bundleName: string): string {
    return `${accountId}:${bundleName}`
  }

  private static isManageableApplication(record: ApplicationInventoryRawRecord, selfBundleName: string): boolean {
    let bundleName = record.bundleName?.trim()
    if (bundleName === undefined || bundleName.length === 0 || bundleName === selfBundleName) {
      return false
    }
    if (ApplicationInventoryRepository.isBlockedApplication(bundleName, record.label)) {
      return false
    }
    return record.systemApp !== true
  }

  private static isBlockedApplication(bundleName: string, label: string | undefined): boolean {
    if (NON_MANAGEABLE_BUNDLE_BLOCKLIST.includes(bundleName)) {
      return true
    }
    let normalizedLabel = label?.trim().toLowerCase() ?? ''
    return normalizedLabel.length > 0 &&
      NON_MANAGEABLE_LABEL_KEYWORDS.some((keyword: string): boolean => normalizedLabel.includes(keyword))
  }

  private static toAppSnapshot(accountId: number, record: ApplicationInventoryRawRecord): PermissionAppSnapshot {
    let bundleName = record.bundleName.trim()
    let appIndex = record.appIndex !== undefined && Number.isFinite(record.appIndex) ? record.appIndex : 0
    let uid = record.uid !== undefined && Number.isFinite(record.uid) ? record.uid : 0
    return {
      appKey: ApplicationInventoryRepository.buildAppKey(accountId, bundleName),
      accountId: accountId,
      bundleName: bundleName,
      appId: ApplicationInventoryRepository.normalizeString(record.appId, ''),
      appIndex: appIndex,
      uid: uid,
      label: ApplicationInventoryRepository.normalizeString(record.label, bundleName),
      uninstallProtected: false,
      runningBlocked: false,
      networkBlocked: false,
      threeDGroups: [],
      threeDPolicies: [],
      threeDLoadState: 'idle',
      threeDMessage: ''
    } as PermissionAppSnapshot
  }

  private static normalizeString(value: string | undefined, fallback: string): string {
    let normalized = value?.trim()
    return normalized && normalized.length > 0 ? normalized : fallback
  }

  private static compareApplications(left: PermissionAppSnapshot, right: PermissionAppSnapshot): number {
    let labelCompare = left.label.localeCompare(right.label)
    if (labelCompare !== 0) {
      return labelCompare
    }
    return left.bundleName.localeCompare(right.bundleName)
  }
}

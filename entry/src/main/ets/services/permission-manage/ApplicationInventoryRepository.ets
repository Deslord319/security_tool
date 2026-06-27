import { bundleManager as enterpriseBundleManager } from '@kit.MDMKit'
import { ADMIN_WANT, AppInfo } from '../../constants/AppConstants'
import { ApplicationInventoryResult, ManagedApplicationInfo } from '../../models/PermissionModels'
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
  'formrenderservice',
  'fromrenderservice',
  'arkweb',
  '方舟web',
  '长时任务通知资源'
]

export interface ApplicationInventoryRawRecord {
  bundleName: string
  label?: string
  appIdentifier?: string
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
        applications: applications,
        policyRecords: [],
        message: applications.length === 0 ? PermissionEmptyStrings.APPLICATIONS : ''
      } as ApplicationInventoryResult
    } catch (err) {
      LogUtils.warn(TAG, `loadApplications failed: ${JSON.stringify(err)}`)
      return {
        applications: [],
        policyRecords: [],
        message: PermissionEmptyStrings.INVENTORY_LOAD_FAILED
      } as ApplicationInventoryResult
    }
  }

  static normalizeBundleInfos(
    accountId: number,
    bundleInfos: enterpriseBundleManager.BundleInfo[],
    selfBundleName: string = AppInfo.BUNDLE_NAME
  ): ManagedApplicationInfo[] {
    let records = bundleInfos.map((bundleInfo: enterpriseBundleManager.BundleInfo): ApplicationInventoryRawRecord =>
      ApplicationInventoryRepository.toRawRecord(bundleInfo)
    )
    return ApplicationInventoryRepository.normalizeApplications(accountId, records, selfBundleName)
  }

  private static toRawRecord(bundleInfo: enterpriseBundleManager.BundleInfo): ApplicationInventoryRawRecord {
    return {
      bundleName: bundleInfo.name,
      label: bundleInfo.appInfo?.label,
      appIdentifier: bundleInfo.signatureInfo?.appIdentifier,
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
  ): ManagedApplicationInfo[] {
    return records
      .filter((record: ApplicationInventoryRawRecord): boolean =>
        ApplicationInventoryRepository.isManageableApplication(record, selfBundleName)
      )
      .map((record: ApplicationInventoryRawRecord): ManagedApplicationInfo =>
        ApplicationInventoryRepository.toManagedApplication(accountId, record)
      )
      .sort((left: ManagedApplicationInfo, right: ManagedApplicationInfo): number =>
        ApplicationInventoryRepository.compareApplications(left, right)
      )
  }

  static filterApplications(applications: ManagedApplicationInfo[], keyword: string): ManagedApplicationInfo[] {
    let normalizedKeyword = keyword.trim().toLowerCase()
    if (normalizedKeyword.length === 0) {
      return applications
    }
    return applications.filter((app: ManagedApplicationInfo): boolean =>
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

  private static toManagedApplication(accountId: number, record: ApplicationInventoryRawRecord): ManagedApplicationInfo {
    let bundleName = record.bundleName.trim()
    let appIdentifier = ApplicationInventoryRepository.normalizeString(record.appIdentifier, '')
    let appIndex = record.appIndex !== undefined && Number.isFinite(record.appIndex) ? record.appIndex : 0
    let uid = record.uid !== undefined && Number.isFinite(record.uid) ? record.uid : 0
    return {
      key: ApplicationInventoryRepository.buildAppKey(accountId, bundleName),
      accountId: accountId,
      bundleName: bundleName,
      appIdentifier: appIdentifier,
      appIndex: appIndex,
      uid: uid,
      label: ApplicationInventoryRepository.normalizeString(record.label, bundleName),
      versionName: ApplicationInventoryRepository.normalizeString(record.versionName, ''),
      iconData: ApplicationInventoryRepository.normalizeString(record.iconData, ''),
      systemApp: record.systemApp ?? false,
      removable: record.removable ?? true,
      installSource: ApplicationInventoryRepository.normalizeString(record.installSource, ''),
      appDistributionType: ApplicationInventoryRepository.normalizeString(record.appDistributionType, ''),
      mainAbilityName: ApplicationInventoryRepository.normalizeString(record.mainAbilityName, ''),
      installPolicy: 'default',
      uninstallProtected: false,
      runningPolicy: 'default',
      networkPolicy: 'default'
    } as ManagedApplicationInfo
  }

  private static normalizeString(value: string | undefined, fallback: string): string {
    let normalized = value?.trim()
    return normalized && normalized.length > 0 ? normalized : fallback
  }

  private static compareApplications(left: ManagedApplicationInfo, right: ManagedApplicationInfo): number {
    let labelCompare = left.label.localeCompare(right.label)
    if (labelCompare !== 0) {
      return labelCompare
    }
    return left.bundleName.localeCompare(right.bundleName)
  }
}

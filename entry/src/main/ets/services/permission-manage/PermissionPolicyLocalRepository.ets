import { common } from '@kit.AbilityKit'
import { PermissionLocalPolicyRecord, PermissionPolicyActionKind } from '../../models/PermissionModels'
import { PreferencesAccessor } from '../../storage/preferences/PreferencesAccessor'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'PermissionPolicyLocalRepo'
const PREF_STORE_NAME = 'permission_policy_records'
const PREF_KEY_POLICY_RECORDS = 'records'

export class PermissionPolicyLocalRepository {
  private static context: common.Context | null = null
  private static records: PermissionLocalPolicyRecord[] = []
  private static initialized: boolean = false
  private static initPromise: Promise<boolean> | null = null
  private static nowProvider: () => number = () => Date.now()

  static async init(context: common.Context): Promise<boolean> {
    PermissionPolicyLocalRepository.context = context
    if (PermissionPolicyLocalRepository.initialized) {
      return true
    }
    if (PermissionPolicyLocalRepository.initPromise) {
      return PermissionPolicyLocalRepository.initPromise
    }
    PermissionPolicyLocalRepository.initPromise = PermissionPolicyLocalRepository.doInit()
    let ok = await PermissionPolicyLocalRepository.initPromise
    PermissionPolicyLocalRepository.initPromise = null
    return ok
  }

  static resetForTest(): void {
    PermissionPolicyLocalRepository.context = null
    PermissionPolicyLocalRepository.records = []
    PermissionPolicyLocalRepository.initialized = false
    PermissionPolicyLocalRepository.initPromise = null
  }

  static listActiveByAccount(accountId: number): PermissionLocalPolicyRecord[] {
    return PermissionPolicyLocalRepository.records
      .filter((record: PermissionLocalPolicyRecord): boolean =>
        record.accountId === accountId && record.status === 'active'
      )
      .map((record: PermissionLocalPolicyRecord): PermissionLocalPolicyRecord =>
        PermissionPolicyLocalRepository.normalizeRecord(record)
      )
  }

  static async upsertActive(record: PermissionLocalPolicyRecord): Promise<boolean> {
    let normalized = PermissionPolicyLocalRepository.normalizeRecord(record)
    normalized.status = 'active'
    let existing = PermissionPolicyLocalRepository.records.find((item: PermissionLocalPolicyRecord): boolean =>
      item.recordId === normalized.recordId
    )
    if (existing) {
      normalized.createdAt = existing.createdAt
    }
    PermissionPolicyLocalRepository.records = PermissionPolicyLocalRepository.records
      .filter((item: PermissionLocalPolicyRecord): boolean => item.recordId !== normalized.recordId)
    PermissionPolicyLocalRepository.records.unshift(normalized)
    return await PermissionPolicyLocalRepository.saveRecords()
  }

  static async remove(recordId: string): Promise<boolean> {
    PermissionPolicyLocalRepository.records = PermissionPolicyLocalRepository.records
      .filter((item: PermissionLocalPolicyRecord): boolean => item.recordId !== recordId)
    return await PermissionPolicyLocalRepository.saveRecords()
  }

  private static async doInit(): Promise<boolean> {
    if (!PermissionPolicyLocalRepository.context) {
      return false
    }
    try {
      let pref = PreferencesAccessor.of(PermissionPolicyLocalRepository.context, PREF_STORE_NAME)
      let parsed = await pref.getJsonArray<PermissionLocalPolicyRecord>(PREF_KEY_POLICY_RECORDS, [])
      PermissionPolicyLocalRepository.records = parsed
        .map((record: PermissionLocalPolicyRecord): PermissionLocalPolicyRecord =>
          PermissionPolicyLocalRepository.normalizeRecord(record)
        )
        .filter((record: PermissionLocalPolicyRecord): boolean => record.recordId.length > 0)
      PermissionPolicyLocalRepository.initialized = true
      return true
    } catch (err) {
      PermissionPolicyLocalRepository.records = []
      PermissionPolicyLocalRepository.initialized = false
      LogUtils.error(TAG, `init failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static async saveRecords(): Promise<boolean> {
    if (!PermissionPolicyLocalRepository.context) {
      return false
    }
    try {
      let pref = PreferencesAccessor.of(PermissionPolicyLocalRepository.context, PREF_STORE_NAME)
      return await pref.setJson(PREF_KEY_POLICY_RECORDS, PermissionPolicyLocalRepository.records)
    } catch (err) {
      LogUtils.error(TAG, `saveRecords failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  private static normalizeRecord(record: PermissionLocalPolicyRecord): PermissionLocalPolicyRecord {
    let now = PermissionPolicyLocalRepository.nowProvider()
    let createdAt = Number.isFinite(record.createdAt) && record.createdAt > 0 ? Math.floor(record.createdAt) : now
    let updatedAt = Number.isFinite(record.updatedAt) && record.updatedAt > 0 ? Math.floor(record.updatedAt) : now
    return {
      recordId: PermissionPolicyLocalRepository.normalizeString(record.recordId),
      accountId: Number.isFinite(record.accountId) ? Math.floor(record.accountId) : 0,
      appKey: PermissionPolicyLocalRepository.normalizeString(record.appKey),
      bundleName: PermissionPolicyLocalRepository.normalizeString(record.bundleName),
      appIdentifier: PermissionPolicyLocalRepository.normalizeString(record.appIdentifier),
      appIndex: Number.isFinite(record.appIndex) ? Math.floor(record.appIndex) : 0,
      policyType: PermissionPolicyLocalRepository.normalizeString(record.policyType),
      policyValue: PermissionPolicyLocalRepository.normalizeString(record.policyValue),
      targetName: PermissionPolicyLocalRepository.normalizeString(record.targetName),
      targetDetail: PermissionPolicyLocalRepository.normalizeString(record.targetDetail),
      statusLabel: PermissionPolicyLocalRepository.normalizeString(record.statusLabel),
      scopeLabel: PermissionPolicyLocalRepository.normalizeString(record.scopeLabel),
      actionKind: PermissionPolicyLocalRepository.normalizeActionKind(record.actionKind),
      policyId: PermissionPolicyLocalRepository.normalizeString(record.policyId),
      status: record.status === 'stale' ? 'stale' : 'active',
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastError: PermissionPolicyLocalRepository.normalizeString(record.lastError)
    } as PermissionLocalPolicyRecord
  }

  private static normalizeString(value: string | undefined): string {
    return value?.trim() ?? ''
  }

  private static normalizeActionKind(value: string | undefined): PermissionPolicyActionKind {
    let actionKind = PermissionPolicyLocalRepository.normalizeString(value)
    if (
      actionKind === 'install-deny' ||
      actionKind === 'install-allow' ||
      actionKind === 'uninstall-protect' ||
      actionKind === 'running' ||
      actionKind === 'network' ||
      actionKind === 'three-d'
    ) {
      return actionKind
    }
    return 'three-d'
  }
}

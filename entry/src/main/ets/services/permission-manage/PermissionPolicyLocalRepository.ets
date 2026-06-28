import relationalStore from '@ohos.data.relationalStore'
import { common } from '@kit.AbilityKit'
import { AppInfo } from '../../constants/AppConstants'
import { PermissionLocalPolicyRecord, PermissionPolicyActionKind } from '../../models/PermissionModels'
import { RdbRepository, SqlBundle } from '../../storage/rdb/RdbRepository'
import { RdbResultSetReader } from '../../storage/rdb/RdbResultSetReader'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'PermissionPolicyLocalRepo'
const TABLE_NAME = 'permission_policy_records'

const CREATE_TABLE_SQL = `
CREATE TABLE IF NOT EXISTS permission_policy_records (
  record_id TEXT PRIMARY KEY,
  account_id INTEGER NOT NULL,
  app_key TEXT NOT NULL,
  bundle_name TEXT NOT NULL,
  app_identifier TEXT NOT NULL,
  app_index INTEGER NOT NULL,
  policy_type TEXT NOT NULL,
  policy_value TEXT NOT NULL,
  target_name TEXT NOT NULL,
  target_detail TEXT NOT NULL,
  status_label TEXT NOT NULL,
  scope_label TEXT NOT NULL,
  action_kind TEXT NOT NULL,
  policy_id TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  last_error TEXT NOT NULL
)`

const CREATE_ACCOUNT_STATUS_INDEX_SQL = `
CREATE INDEX IF NOT EXISTS idx_permission_policy_account_status
ON permission_policy_records(account_id, status)
`

const CREATE_APP_KEY_INDEX_SQL = `
CREATE INDEX IF NOT EXISTS idx_permission_policy_app_key
ON permission_policy_records(app_key)
`

class PermissionPolicyRecordRdbRepository extends RdbRepository<PermissionLocalPolicyRecord, Object> {
  constructor() {
    super({
      tag: TAG,
      dbName: AppInfo.DB_NAME,
      tableName: TABLE_NAME,
      createStatements: [
        CREATE_TABLE_SQL,
        CREATE_ACCOUNT_STATUS_INDEX_SQL,
        CREATE_APP_KEY_INDEX_SQL
      ]
    })
  }

  async listAll(): Promise<PermissionLocalPolicyRecord[]> {
    return this.queryRows(
      {
        sql: `SELECT record_id, account_id, app_key, bundle_name, app_identifier, app_index,
                policy_type, policy_value, target_name, target_detail, status_label, scope_label,
                action_kind, policy_id, status, created_at, updated_at, last_error
              FROM ${TABLE_NAME}
              ORDER BY updated_at DESC, created_at DESC`,
        args: []
      } as SqlBundle,
      (reader: RdbResultSetReader): PermissionLocalPolicyRecord[] => this.mapResultSet(reader),
      'listAll'
    )
  }

  async upsert(record: PermissionLocalPolicyRecord): Promise<boolean> {
    return this.executeSql(
      `INSERT OR REPLACE INTO ${TABLE_NAME} (
        record_id, account_id, app_key, bundle_name, app_identifier, app_index,
        policy_type, policy_value, target_name, target_detail, status_label, scope_label,
        action_kind, policy_id, status, created_at, updated_at, last_error
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      this.buildArgs(record),
      'upsert'
    )
  }

  async deleteByRecordId(recordId: string): Promise<boolean> {
    return this.executeSql(
      `DELETE FROM ${TABLE_NAME} WHERE record_id = ?`,
      [recordId],
      'deleteByRecordId'
    )
  }

  private buildArgs(record: PermissionLocalPolicyRecord): Array<relationalStore.ValueType> {
    return [
      record.recordId,
      record.accountId,
      record.appKey,
      record.bundleName,
      record.appIdentifier,
      record.appIndex,
      record.policyType,
      record.policyValue,
      record.targetName,
      record.targetDetail,
      record.statusLabel,
      record.scopeLabel,
      record.actionKind,
      record.policyId,
      record.status,
      record.createdAt,
      record.updatedAt,
      record.lastError
    ]
  }

  private mapResultSet(reader: RdbResultSetReader): PermissionLocalPolicyRecord[] {
    let records: PermissionLocalPolicyRecord[] = []
    if (!reader.moveToFirst()) {
      return records
    }
    let recordIdIndex = reader.getColumnIndex('record_id')
    let accountIdIndex = reader.getColumnIndex('account_id')
    let appKeyIndex = reader.getColumnIndex('app_key')
    let bundleNameIndex = reader.getColumnIndex('bundle_name')
    let appIdentifierIndex = reader.getColumnIndex('app_identifier')
    let appIndexIndex = reader.getColumnIndex('app_index')
    let policyTypeIndex = reader.getColumnIndex('policy_type')
    let policyValueIndex = reader.getColumnIndex('policy_value')
    let targetNameIndex = reader.getColumnIndex('target_name')
    let targetDetailIndex = reader.getColumnIndex('target_detail')
    let statusLabelIndex = reader.getColumnIndex('status_label')
    let scopeLabelIndex = reader.getColumnIndex('scope_label')
    let actionKindIndex = reader.getColumnIndex('action_kind')
    let policyIdIndex = reader.getColumnIndex('policy_id')
    let statusIndex = reader.getColumnIndex('status')
    let createdAtIndex = reader.getColumnIndex('created_at')
    let updatedAtIndex = reader.getColumnIndex('updated_at')
    let lastErrorIndex = reader.getColumnIndex('last_error')
    do {
      records.push({
        recordId: reader.getRequiredString(recordIdIndex),
        accountId: reader.getRequiredNumber(accountIdIndex),
        appKey: reader.getRequiredString(appKeyIndex),
        bundleName: reader.getRequiredString(bundleNameIndex),
        appIdentifier: reader.getRequiredString(appIdentifierIndex),
        appIndex: reader.getRequiredNumber(appIndexIndex),
        policyType: reader.getRequiredString(policyTypeIndex),
        policyValue: reader.getRequiredString(policyValueIndex),
        targetName: reader.getRequiredString(targetNameIndex),
        targetDetail: reader.getRequiredString(targetDetailIndex),
        statusLabel: reader.getRequiredString(statusLabelIndex),
        scopeLabel: reader.getRequiredString(scopeLabelIndex),
        actionKind: reader.getRequiredString(actionKindIndex) as PermissionPolicyActionKind,
        policyId: reader.getRequiredString(policyIdIndex),
        status: reader.getRequiredString(statusIndex),
        createdAt: reader.getRequiredNumber(createdAtIndex),
        updatedAt: reader.getRequiredNumber(updatedAtIndex),
        lastError: reader.getRequiredString(lastErrorIndex)
      } as PermissionLocalPolicyRecord)
    } while (reader.moveToNext())
    return records
  }
}

export class PermissionPolicyLocalRepository {
  private static records: PermissionLocalPolicyRecord[] = []
  private static initialized: boolean = false
  private static initPromise: Promise<boolean> | null = null
  private static nowProvider: () => number = () => Date.now()
  private static rdbRepository: PermissionPolicyRecordRdbRepository = new PermissionPolicyRecordRdbRepository()

  static async init(context: common.UIAbilityContext): Promise<boolean> {
    if (PermissionPolicyLocalRepository.initialized) {
      return true
    }
    if (PermissionPolicyLocalRepository.initPromise) {
      return PermissionPolicyLocalRepository.initPromise
    }
    PermissionPolicyLocalRepository.initPromise = PermissionPolicyLocalRepository.doInit(context)
    let ok = await PermissionPolicyLocalRepository.initPromise
    PermissionPolicyLocalRepository.initPromise = null
    return ok
  }

  static resetForTest(): void {
    PermissionPolicyLocalRepository.records = []
    PermissionPolicyLocalRepository.initialized = false
    PermissionPolicyLocalRepository.initPromise = null
    PermissionPolicyLocalRepository.rdbRepository = new PermissionPolicyRecordRdbRepository()
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
    return await PermissionPolicyLocalRepository.rdbRepository.upsert(normalized)
  }

  static async remove(recordId: string): Promise<boolean> {
    PermissionPolicyLocalRepository.records = PermissionPolicyLocalRepository.records
      .filter((item: PermissionLocalPolicyRecord): boolean => item.recordId !== recordId)
    return await PermissionPolicyLocalRepository.rdbRepository.deleteByRecordId(recordId)
  }

  private static async doInit(context: common.UIAbilityContext): Promise<boolean> {
    let ready = await PermissionPolicyLocalRepository.rdbRepository.init(context)
    if (!ready) {
      PermissionPolicyLocalRepository.records = []
      PermissionPolicyLocalRepository.initialized = false
      return false
    }
    try {
      let records = await PermissionPolicyLocalRepository.rdbRepository.listAll()
      PermissionPolicyLocalRepository.records = records
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

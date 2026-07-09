import relationalStore from '@ohos.data.relationalStore'
import { AppInfo } from '../../../constants/AppConstants'
import {
  PeripheralDevicePolicy,
  UsbDeviceActivePolicy,
  UsbDevicePolicyStateRecord
} from '../../../models/PeripheralModels'
import { RdbRepository, SqlBundle } from '../../../storage/rdb/RdbRepository'
import { RdbResultSetReader } from '../../../storage/rdb/RdbResultSetReader'

const TAG = 'UsbDevicePolicyStateRepo'
const TABLE_NAME = 'usb_device_policy_states'

const CREATE_TABLE_SQL = `
CREATE TABLE IF NOT EXISTS usb_device_policy_states (
  fingerprint_key TEXT PRIMARY KEY,
  fingerprint_type TEXT NOT NULL,
  serial_number TEXT,
  vendor_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  description TEXT,
  base_class INTEGER NOT NULL,
  device_name TEXT NOT NULL,
  desired_policy TEXT NOT NULL,
  present INTEGER NOT NULL,
  active_policy TEXT NOT NULL,
  last_seen_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)`

const CREATE_INDEX_BASE_CLASS_SQL = `
CREATE INDEX IF NOT EXISTS idx_usb_policy_state_base_class
ON usb_device_policy_states(base_class, present, active_policy)
`

const CREATE_INDEX_UPDATED_AT_SQL = `
CREATE INDEX IF NOT EXISTS idx_usb_policy_state_updated_at
ON usb_device_policy_states(updated_at DESC)
`

class UsbDevicePolicyStateRdbRepository extends RdbRepository<UsbDevicePolicyStateRecord, Object> {
  constructor() {
    super({
      tag: TAG,
      dbName: AppInfo.DB_NAME,
      tableName: TABLE_NAME,
      createStatements: [
        CREATE_TABLE_SQL,
        CREATE_INDEX_BASE_CLASS_SQL,
        CREATE_INDEX_UPDATED_AT_SQL
      ]
    })
  }

  async upsert(record: UsbDevicePolicyStateRecord): Promise<boolean> {
    return this.upsertAll([record])
  }

  async upsertAll(records: UsbDevicePolicyStateRecord[]): Promise<boolean> {
    if (records.length === 0) {
      return true
    }
    const normalizedRecords = records.map((record: UsbDevicePolicyStateRecord) => this.normalizeRecord(record))
    const saved = await this.replaceBatch(
      normalizedRecords,
      `INSERT OR REPLACE INTO ${TABLE_NAME} (
        fingerprint_key, fingerprint_type, serial_number, vendor_id, product_id,
        description, base_class, device_name, desired_policy, present, active_policy,
        last_seen_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      (item: UsbDevicePolicyStateRecord) => this.buildArgs(item),
      'upsertAll'
    )
    if (saved) {
      this.notifyChanged()
    }
    return saved
  }

  async get(fingerprintKey: string): Promise<UsbDevicePolicyStateRecord | null> {
    const rows = await this.queryRows(
      {
        sql: `SELECT ${this.selectColumns()} FROM ${TABLE_NAME} WHERE fingerprint_key = ?`,
        args: [fingerprintKey]
      },
      (reader: RdbResultSetReader) => this.mapResultSet(reader),
      'get'
    )
    return rows.length > 0 ? rows[0] : null
  }

  async listAll(): Promise<UsbDevicePolicyStateRecord[]> {
    return this.queryRows(
      {
        sql: `SELECT ${this.selectColumns()} FROM ${TABLE_NAME} ORDER BY last_seen_at DESC, updated_at DESC`,
        args: []
      },
      (reader: RdbResultSetReader) => this.mapResultSet(reader),
      'listAll'
    )
  }

  async hasOtherActiveDeny(baseClass: number, fingerprintKey: string): Promise<boolean> {
    const count = await this.countByRawWhere(
      'base_class = ? AND present = 1 AND active_policy = ? AND fingerprint_key <> ?',
      [Math.floor(baseClass), 'deny', fingerprintKey]
    )
    return count > 0
  }

  private buildArgs(record: UsbDevicePolicyStateRecord): Array<relationalStore.ValueType> {
    return [
      record.fingerprintKey,
      record.fingerprintType,
      record.serialNumber ?? null,
      record.vendorId,
      record.productId,
      record.description ?? null,
      record.baseClass,
      record.deviceName,
      record.desiredPolicy,
      record.present ? 1 : 0,
      record.activePolicy,
      record.lastSeenAt,
      record.updatedAt
    ]
  }

  private selectColumns(): string {
    return `fingerprint_key, fingerprint_type, serial_number, vendor_id, product_id,
      description, base_class, device_name, desired_policy, present, active_policy,
      last_seen_at, updated_at`
  }

  private mapResultSet(reader: RdbResultSetReader): UsbDevicePolicyStateRecord[] {
    const records: UsbDevicePolicyStateRecord[] = []
    if (!reader.moveToFirst()) {
      return records
    }
    const fingerprintKeyIndex = reader.getColumnIndex('fingerprint_key')
    const fingerprintTypeIndex = reader.getColumnIndex('fingerprint_type')
    const serialNumberIndex = reader.getColumnIndex('serial_number')
    const vendorIdIndex = reader.getColumnIndex('vendor_id')
    const productIdIndex = reader.getColumnIndex('product_id')
    const descriptionIndex = reader.getColumnIndex('description')
    const baseClassIndex = reader.getColumnIndex('base_class')
    const deviceNameIndex = reader.getColumnIndex('device_name')
    const desiredPolicyIndex = reader.getColumnIndex('desired_policy')
    const presentIndex = reader.getColumnIndex('present')
    const activePolicyIndex = reader.getColumnIndex('active_policy')
    const lastSeenAtIndex = reader.getColumnIndex('last_seen_at')
    const updatedAtIndex = reader.getColumnIndex('updated_at')
    do {
      records.push({
        fingerprintKey: reader.getRequiredString(fingerprintKeyIndex),
        fingerprintType: this.parseFingerprintType(reader.getRequiredString(fingerprintTypeIndex)),
        serialNumber: reader.getOptionalString(serialNumberIndex),
        vendorId: reader.getRequiredNumber(vendorIdIndex),
        productId: reader.getRequiredNumber(productIdIndex),
        description: reader.getOptionalString(descriptionIndex),
        baseClass: reader.getRequiredNumber(baseClassIndex),
        deviceName: reader.getRequiredString(deviceNameIndex),
        desiredPolicy: this.parseDesiredPolicy(reader.getRequiredString(desiredPolicyIndex)),
        present: reader.getRequiredNumber(presentIndex) === 1,
        activePolicy: this.parseActivePolicy(reader.getRequiredString(activePolicyIndex)),
        lastSeenAt: reader.getRequiredNumber(lastSeenAtIndex),
        updatedAt: reader.getRequiredNumber(updatedAtIndex)
      })
    } while (reader.moveToNext())
    return records
  }

  private normalizeRecord(record: UsbDevicePolicyStateRecord): UsbDevicePolicyStateRecord {
    const now = Date.now()
    return {
      fingerprintKey: record.fingerprintKey,
      fingerprintType: record.fingerprintType === 'serial' ? 'serial' : 'weak',
      serialNumber: record.serialNumber,
      vendorId: Math.floor(record.vendorId),
      productId: Math.floor(record.productId),
      description: record.description,
      baseClass: Number.isFinite(record.baseClass) ? Math.floor(record.baseClass) : 0,
      deviceName: (record.deviceName || '').trim(),
      desiredPolicy: this.parseDesiredPolicy(record.desiredPolicy),
      present: record.present === true,
      activePolicy: this.parseActivePolicy(record.activePolicy),
      lastSeenAt: Number.isFinite(record.lastSeenAt) && record.lastSeenAt > 0 ? Math.floor(record.lastSeenAt) : now,
      updatedAt: Number.isFinite(record.updatedAt) && record.updatedAt > 0 ? Math.floor(record.updatedAt) : now
    }
  }

  private parseFingerprintType(value: string): 'serial' | 'weak' {
    return value === 'serial' ? 'serial' : 'weak'
  }

  private parseDesiredPolicy(value: string): PeripheralDevicePolicy {
    return value === 'deny' ? 'deny' : 'allow'
  }

  private parseActivePolicy(value: string): UsbDeviceActivePolicy {
    return value === 'deny' ? 'deny' : 'none'
  }
}

export const UsbDevicePolicyStateRepository = new UsbDevicePolicyStateRdbRepository()

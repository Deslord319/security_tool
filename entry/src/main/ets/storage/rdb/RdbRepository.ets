import relationalStore from '@ohos.data.relationalStore'
import { common } from '@kit.AbilityKit'
import { LogUtils } from '../../utils/LogUtils'
import { RdbResultSetReader } from './RdbResultSetReader'
import { RdbStoreProvider } from './RdbStoreProvider'
import { ErrorLike } from '../../types/LooseValueTypes'

export interface SqlBundle {
  sql: string
  args: Array<relationalStore.ValueType>
}

interface GroupCountRow {
  key: string
  count: number
}

type ChangeListener = () => void

interface RdbRepositoryOptions {
  tag: string
  dbName: string
  tableName: string
  createStatements: string[]
}

export abstract class RdbRepository<TRecord, TQuery> {
  private readonly tag: string
  private readonly dbName: string
  protected readonly tableName: string
  private readonly createStatements: string[]
  private context: common.UIAbilityContext | null = null
  private initialized: boolean = false
  private initializedContextDir: string = ''
  private initPromise: Promise<boolean> | null = null
  private nextListenerId: number = 1
  private listeners: Map<number, ChangeListener> = new Map()

  protected constructor(options: RdbRepositoryOptions) {
    this.tag = options.tag
    this.dbName = options.dbName
    this.tableName = options.tableName
    this.createStatements = options.createStatements
  }

  async init(context: common.UIAbilityContext): Promise<boolean> {
    this.context = context
    let contextDir = context.filesDir || ''
    if (this.initialized && this.initializedContextDir === contextDir) {
      return true
    }
    if (this.initPromise) {
      return this.initPromise
    }
    this.initPromise = this.doInit(context, contextDir)
    let ready = await this.initPromise
    this.initPromise = null
    return ready
  }

  isReady(): boolean {
    return this.initialized
  }

  addChangeListener(listener: ChangeListener): number {
    let id = this.nextListenerId++
    this.listeners.set(id, listener)
    return id
  }

  removeChangeListener(listenerId: number): void {
    this.listeners.delete(listenerId)
  }

  notifyChanged(): void {
    this.listeners.forEach((listener: ChangeListener) => {
      try {
        listener()
      } catch (err) {
        LogUtils.warn(this.tag, `listener failed: ${JSON.stringify(err)}`)
      }
    })
  }

  protected async replaceBatch(
    records: TRecord[],
    insertSql: string,
    buildArgs: (record: TRecord) => Array<relationalStore.ValueType>,
    operationName: string
  ): Promise<boolean> {
    let store = await this.getStore()
    if (!store) {
      return false
    }
    try {
      for (let record of records) {
        await store.executeSql(insertSql, buildArgs(record))
      }
      return true
    } catch (err) {
      LogUtils.error(this.tag, `${operationName} failed: ${this.stringifyError(err)}`)
      return false
    }
  }

  protected async queryRows<TRow>(
    sqlBundle: SqlBundle,
    mapResultSet: (reader: RdbResultSetReader) => TRow[],
    operationName: string
  ): Promise<TRow[]> {
    let store = await this.getStore()
    if (!store) {
      return []
    }
    let reader: RdbResultSetReader | null = null
    try {
      let resultSet = await store.querySql(sqlBundle.sql, sqlBundle.args)
      reader = new RdbResultSetReader(resultSet, this.tag)
      return mapResultSet(reader)
    } catch (err) {
      LogUtils.error(this.tag, `${operationName} failed: ${this.stringifyError(err)}`)
      return []
    } finally {
      reader?.close()
    }
  }

  protected async countByQueryBuilt(
    query: TQuery | undefined,
    buildCountSql: (query?: TQuery) => SqlBundle,
    operationName: string
  ): Promise<number> {
    return this.queryCount(buildCountSql(query), operationName)
  }

  protected async deleteExpiredByColumn(timestampColumn: string, cutoffTimestamp: number): Promise<boolean> {
    return this.executeSql(
      `DELETE FROM ${this.tableName} WHERE ${timestampColumn} < ?`,
      [cutoffTimestamp],
      'deleteExpired'
    )
  }

  protected async trimToMaxEntriesByOrder(orderByClause: string, maxEntries: number): Promise<boolean> {
    return this.executeSql(
      `DELETE FROM ${this.tableName}
       WHERE id NOT IN (
         SELECT id FROM ${this.tableName}
         ORDER BY ${orderByClause}
         LIMIT ?
       )`,
      [maxEntries],
      'trimToMaxEntries'
    )
  }

  protected async clearAllRows(): Promise<boolean> {
    return this.executeSql(`DELETE FROM ${this.tableName}`, [], 'clearAll')
  }

  protected async countByRawWhere(whereClause: string, args: Array<relationalStore.ValueType>): Promise<number> {
    return this.queryCount(
      {
        sql: `SELECT COUNT(1) AS count FROM ${this.tableName} WHERE ${whereClause}`,
        args
      },
      'countByRawWhere'
    )
  }

  protected buildSelectSql(
    selectColumnsSql: string,
    where: SqlBundle,
    orderByClause: string,
    limit?: number,
    offset?: number
  ): SqlBundle {
    let sql =
      `SELECT ${selectColumnsSql}
       FROM ${this.tableName}${where.sql}
       ORDER BY ${orderByClause}`
    let args = where.args.slice()
    if (limit !== undefined) {
      sql += ' LIMIT ?'
      args.push(limit)
      if (offset !== undefined && offset > 0) {
        sql += ' OFFSET ?'
        args.push(offset)
      }
    }
    return { sql, args }
  }

  protected buildCountSql(where: SqlBundle): SqlBundle {
    return {
      sql: `SELECT COUNT(1) AS count FROM ${this.tableName}${where.sql}`,
      args: where.args
    }
  }

  protected parseJsonObject<TExtra extends Object>(rawValue: string | undefined, operationName: string): TExtra | null {
    if (!rawValue || rawValue.length === 0) {
      return null
    }
    try {
      let parsed = JSON.parse(rawValue) as Object
      if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as TExtra
      }
      return null
    } catch (err) {
      LogUtils.warn(this.tag, `${operationName} failed: ${this.stringifyError(err)}`)
      return null
    }
  }

  protected stringifyError(err: ErrorLike): string {
    return JSON.stringify(err)
  }

  protected async queryCount(sqlBundle: SqlBundle, operationName: string): Promise<number> {
    let store = await this.getStore()
    if (!store) {
      return 0
    }
    let reader: RdbResultSetReader | null = null
    try {
      let resultSet = await store.querySql(sqlBundle.sql, sqlBundle.args)
      reader = new RdbResultSetReader(resultSet, this.tag)
      return reader.readFirstLong('count')
    } catch (err) {
      LogUtils.error(this.tag, `${operationName} failed: ${this.stringifyError(err)}`)
      return 0
    } finally {
      reader?.close()
    }
  }

  protected async queryGroupCounts(
    column: string,
    where: SqlBundle,
    operationName: string
  ): Promise<Map<string, number>> {
    let result = new Map<string, number>()
    let rows = await this.queryRows(
      {
        sql: `SELECT ${column} AS grouped_key, COUNT(1) AS count
              FROM ${this.tableName}${where.sql}
              GROUP BY ${column}`,
        args: where.args
      },
      (reader: RdbResultSetReader) => this.mapGroupCountRows(reader),
      operationName
    )
    rows.forEach((item: GroupCountRow) => result.set(item.key, item.count))
    return result
  }

  private mapGroupCountRows(reader: RdbResultSetReader): GroupCountRow[] {
    let rows: GroupCountRow[] = []
    if (!reader.moveToFirst()) {
      return rows
    }
    let keyIndex = reader.getColumnIndex('grouped_key')
    let countIndex = reader.getColumnIndex('count')
    do {
      rows.push({
        key: reader.getRequiredString(keyIndex),
        count: reader.getRequiredNumber(countIndex)
      })
    } while (reader.moveToNext())
    return rows
  }

  private async doInit(context: common.UIAbilityContext, contextDir: string): Promise<boolean> {
    this.context = context
    let store = await this.getStore()
    if (!store) {
      this.initialized = false
      this.initializedContextDir = ''
      return false
    }
    try {
      for (let statement of this.createStatements) {
        await store.executeSql(statement)
      }
      this.initialized = true
      this.initializedContextDir = contextDir
      return true
    } catch (err) {
      this.initialized = false
      this.initializedContextDir = ''
      LogUtils.error(this.tag, `init failed: ${this.stringifyError(err)}`)
      return false
    }
  }

  private async getStore(): Promise<relationalStore.RdbStore | null> {
    if (!this.context) {
      return null
    }
    return RdbStoreProvider.getStore(this.context, this.dbName)
  }

  private async executeSql(
    sql: string,
    args: Array<relationalStore.ValueType>,
    operationName: string
  ): Promise<boolean> {
    let store = await this.getStore()
    if (!store) {
      return false
    }
    try {
      await store.executeSql(sql, args)
      return true
    } catch (err) {
      LogUtils.error(this.tag, `${operationName} failed: ${this.stringifyError(err)}`)
      return false
    }
  }
}

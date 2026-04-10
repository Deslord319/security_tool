import relationalStore from '@ohos.data.relationalStore'
import { LogUtils } from '../../utils/LogUtils'

export class RdbResultSetReader {
  private readonly resultSet: relationalStore.ResultSet
  private readonly tag: string

  constructor(resultSet: relationalStore.ResultSet, tag: string) {
    this.resultSet = resultSet
    this.tag = tag
  }

  moveToFirst(): boolean {
    try {
      return this.resultSet.rowCount > 0 && this.resultSet.goToFirstRow()
    } catch (err) {
      LogUtils.error(this.tag, `moveToFirst failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  moveToNext(): boolean {
    try {
      return this.resultSet.goToNextRow()
    } catch (err) {
      LogUtils.error(this.tag, `moveToNext failed: ${JSON.stringify(err)}`)
      return false
    }
  }

  getColumnIndex(column: string): number {
    try {
      return this.resultSet.getColumnIndex(column)
    } catch (err) {
      LogUtils.error(this.tag, `getColumnIndex failed: column=${column}, err=${JSON.stringify(err)}`)
      return -1
    }
  }

  getRequiredString(columnIndex: number): string {
    if (columnIndex < 0) {
      return ''
    }
    try {
      return this.resultSet.getString(columnIndex)
    } catch (err) {
      LogUtils.error(this.tag, `getRequiredString failed: index=${columnIndex}, err=${JSON.stringify(err)}`)
      return ''
    }
  }

  getOptionalString(columnIndex: number): string | undefined {
    if (columnIndex < 0) {
      return undefined
    }
    try {
      return this.resultSet.isColumnNull(columnIndex) ? undefined : this.resultSet.getString(columnIndex)
    } catch (err) {
      LogUtils.error(this.tag, `getOptionalString failed: index=${columnIndex}, err=${JSON.stringify(err)}`)
      return undefined
    }
  }

  getRequiredNumber(columnIndex: number): number {
    if (columnIndex < 0) {
      return 0
    }
    try {
      return this.resultSet.getLong(columnIndex)
    } catch (err) {
      LogUtils.error(this.tag, `getRequiredNumber failed: index=${columnIndex}, err=${JSON.stringify(err)}`)
      return 0
    }
  }

  readFirstLong(column: string): number {
    if (!this.moveToFirst()) {
      return 0
    }
    let columnIndex = this.getColumnIndex(column)
    return this.getRequiredNumber(columnIndex)
  }

  close(): void {
    try {
      if (!this.resultSet.isClosed) {
        this.resultSet.close()
      }
    } catch (err) {
      LogUtils.warn(this.tag, `close failed: ${JSON.stringify(err)}`)
    }
  }
}

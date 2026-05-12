import { describe, expect, it } from '@ohos/hypium'
import {
  LogManageState,
  LogSummaryState,
  LogFilterState,
  LogPaginationState,
  LogListState,
  LogStorageSettingsState
} from '../../main/ets/models/LogManageModels'

export default function logManageModelsTest() {
  describe('LogManageModels', () => {
    it('should initialize LogSummaryState with default values', 0, () => {
      let state = new LogSummaryState()

      expect(state.totalCount).assertEqual(0)
      expect(state.todayCount).assertEqual(0)
      expect(state.currentShownCount).assertEqual(0)
    })

    it('should initialize LogFilterState with default values', 0, () => {
      let state = new LogFilterState()

      expect(state.eventTypeIndex).assertEqual(0)
      expect(state.timeRangeIndex).assertEqual(0)
      expect(state.keyword).assertEqual('')
    })

    it('should initialize LogPaginationState with default values', 0, () => {
      let state = new LogPaginationState()

      expect(state.currentPage).assertEqual(1)
      expect(state.pageSizeIndex).assertEqual(0)
      expect(state.pageInputText).assertEqual('1')
      expect(state.totalPages).assertEqual(1)
    })

    it('should initialize LogListState with default values', 0, () => {
      let state = new LogListState()

      expect(state.pagedEntries.length).assertEqual(0)
    })

    it('should initialize LogStorageSettingsState with default values', 0, () => {
      let state = new LogStorageSettingsState()

      expect(state.maxLocalEntries).assertEqual(0)
      expect(state.retentionDays).assertEqual(0)
      expect(state.dirty).assertFalse()
      expect(state.saving).assertFalse()
    })

    it('should initialize LogManageState with default values', 0, () => {
      let state = new LogManageState()

      expect(state.initialized).assertFalse()
      expect(state.loading).assertFalse()
      expect(state.active).assertFalse()
      expect(state.autoRefreshEnabled).assertTrue()
      expect(state.mode).assertEqual('list')
      expect(state.summary.totalCount).assertEqual(0)
      expect(state.filter.eventTypeIndex).assertEqual(0)
      expect(state.pagination.currentPage).assertEqual(1)
      expect(state.list.pagedEntries.length).assertEqual(0)
      expect(state.detail.visible).assertFalse()
      expect(state.detail.entryId).assertEqual('')
    })
  })
}

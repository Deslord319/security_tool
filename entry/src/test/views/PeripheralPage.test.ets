import { describe, expect, it } from '@ohos/hypium'
import { executePeripheralPageClearHistory, PeripheralPage, PeripheralPageClearHistoryAction } from '../../main/ets/views/PeripheralPage'
import { PeripheralViewModel } from '../../main/ets/viewmodels/PeripheralViewModel'

class TestPeripheralViewModel extends PeripheralViewModel {
  clearCallCount: number = 0
  clearResult: boolean = true

  async clearConnectionHistory(): Promise<boolean> {
    this.clearCallCount++
    return this.clearResult
  }
}

class ActionProbe {
  successCount: number = 0
  failureCount: number = 0
  clearByViewModelCount: number = 0
  clearResult: boolean = true

  buildAction(): PeripheralPageClearHistoryAction {
    return {
      clearByViewModel: async (): Promise<boolean> => {
        this.clearByViewModelCount++
        return this.clearResult
      },
      onSuccess: (): void => {
        this.successCount++
      },
      onFailure: (): void => {
        this.failureCount++
      }
    }
  }
}

export default function peripheralPageBoundaryTest() {
  describe('PeripheralPage clear history boundary', () => {
    it('should keep success branch behavior in clear-history action executor', 0, async (done: Function) => {
      const probe = new ActionProbe()
      probe.clearResult = true

      const result = await executePeripheralPageClearHistory(probe.buildAction())
      expect(result).assertTrue()
      expect(probe.clearByViewModelCount).assertEqual(1)
      expect(probe.successCount).assertEqual(1)
      expect(probe.failureCount).assertEqual(0)
      done()
    })

    it('should keep failure branch behavior in clear-history action executor', 0, async (done: Function) => {
      const probe = new ActionProbe()
      probe.clearResult = false

      const result = await executePeripheralPageClearHistory(probe.buildAction())
      expect(result).assertFalse()
      expect(probe.clearByViewModelCount).assertEqual(1)
      expect(probe.successCount).assertEqual(0)
      expect(probe.failureCount).assertEqual(1)
      done()
    })

    it('should route page clear-history action to viewModel entry', 0, async (done: Function) => {
      const page = new PeripheralPage()
      const vm = new TestPeripheralViewModel()
      vm.clearResult = true
      page.viewModel = vm

      const action = page.createClearConnectionHistoryActionForTest()
      const result = await action.clearByViewModel()

      expect(result).assertTrue()
      expect(vm.clearCallCount).assertEqual(1)

      const body = page.createClearConnectionHistoryActionForTest.toString()
      expect(body.includes('viewModel.clearConnectionHistory')).assertTrue()
      expect(body.includes('PeripheralTraceRepository')).assertFalse()
      done()
    })
  })
}

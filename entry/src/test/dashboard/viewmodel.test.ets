import { describe, expect, it } from '@ohos/hypium'
import { NAV_ITEMS } from '../../main/ets/constants/AppConstants'
import { RouteIds } from '../../main/ets/constants/RouteIds'
import { ModuleText } from '../../main/ets/constants/StringCatalog'
import { DashboardQuickEntryState } from '../../main/ets/models/DashboardModels'
import { DashboardViewModel } from '../../main/ets/viewmodels/dashboard/overview/DashboardViewModel'

interface DashboardViewModelContractAccess {
  buildQuickEntries(): DashboardQuickEntryState[]
}

export default function dashboardViewModelTest() {
  describe('DashboardViewModel', () => {
    it('should keep basic defaults stable before initialization', 0, () => {
      let viewModel = new DashboardViewModel()

      expect(viewModel.moduleCards.length).assertEqual(0)
      expect(viewModel.quickEntries.length).assertEqual(0)
    })

    it('should expose six quick entries including help feedback contract', 0, () => {
      let viewModel = new DashboardViewModel()
      let contract = viewModel as Object as DashboardViewModelContractAccess
      let quickEntries = contract.buildQuickEntries()

      expect(quickEntries.length).assertEqual(6)
      expect(quickEntries[0].id).assertEqual(RouteIds.FIREWALL)
      expect(quickEntries[5].id).assertEqual(RouteIds.HELP_FEEDBACK)
      expect(quickEntries[5].title).assertEqual(ModuleText.HELP_FEEDBACK)
    })

    it('should keep help feedback outside sidebar navigation items', 0, () => {
      let helpItem = NAV_ITEMS.find((item) => item.id === RouteIds.HELP_FEEDBACK)
      let toolSettingsItem = NAV_ITEMS.find((item) => item.id === RouteIds.TOOL_SETTINGS)

      expect(NAV_ITEMS.length).assertEqual(6)
      expect(toolSettingsItem?.label ?? '').assertEqual(ModuleText.TOOL_SETTINGS)
      expect(helpItem === undefined).assertTrue()
    })

    it('should allow destroy before initialization', 0, () => {
      let viewModel = new DashboardViewModel()

      viewModel.destroy()

      expect(true).assertTrue()
    })
  })
}

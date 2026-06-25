import { PermissionInitialData } from '../../models/PermissionModels'

export class PermissionService {
  static loadInitialState(): PermissionInitialData {
    return {
      adminActivated: false,
      selectedAccountId: 0,
      summary: {
        accountCount: 0,
        applicationCount: 0,
        managedPolicyCount: 0
      },
      accountOptions: [],
      applications: []
    }
  }
}

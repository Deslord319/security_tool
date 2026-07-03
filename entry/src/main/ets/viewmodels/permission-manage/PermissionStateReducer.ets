import {
  AccountInstallPolicySnapshot,
  ApplicationPermissionProfile,
  PermissionAppSnapshot,
  PermissionPageState,
  PermissionThreeDPolicySnapshot,
  ThreeDLoadState,
  ThreeDManagedState,
  ThreeDPermissionItem
} from '../../models/PermissionModels'
import { PermissionApplicationStrings } from '../../constants/modules/PermissionStrings'
import { PermissionService } from '../../services/permission-manage/PermissionService'
import { PermissionPolicyRecordMapper } from './PermissionPolicyRecordMapper'

export interface PermissionAppSnapshotPatch {
  uninstallProtected?: boolean
  runningBlocked?: boolean
  networkBlocked?: boolean
  threeDGroups?: ThreeDPermissionItem[]
  threeDPolicies?: PermissionThreeDPolicySnapshot[]
  threeDLoadState?: ThreeDLoadState
  threeDMessage?: string
}

export interface PermissionStateUpdate {
  appSnapshots?: PermissionAppSnapshot[]
  installPolicies?: AccountInstallPolicySnapshot[]
  selectedAppKey?: string
  inventoryMessage?: string
}

export class PermissionStateReducer {
  static commit(state: PermissionPageState, update: PermissionStateUpdate): boolean {
    if (update.appSnapshots !== undefined) {
      state.appSnapshots = update.appSnapshots
    }
    if (update.installPolicies !== undefined) {
      state.installPolicies = update.installPolicies
    }
    if (update.selectedAppKey !== undefined) {
      state.selectedAppKey = update.selectedAppKey
    }
    if (update.inventoryMessage !== undefined) {
      state.inventoryMessage = update.inventoryMessage
    }
    return PermissionStateReducer.rebuildDerivedState(state)
  }

  static rebuildDerivedState(state: PermissionPageState): boolean {
    let selectedCleared = false
    state.filteredAppKeys = PermissionService.filterAppKeys(state.appSnapshots, state.searchKeyword)
    if (state.filteredAppKeys.length === 0) {
      if (PermissionStateReducer.hasSelectedApplicationState(state)) {
        PermissionStateReducer.clearSelectedApplicationState(state)
        selectedCleared = true
      }
    } else if (!state.filteredAppKeys.includes(state.selectedAppKey) && state.selectedAppKey.length > 0) {
      PermissionStateReducer.clearSelectedApplicationState(state)
      selectedCleared = true
    }
    state.policyRecords = PermissionService.buildPolicyRecordsFromState(state.appSnapshots, state.installPolicies)
    state.summary = PermissionService.buildSummaryFromState(state.appSnapshots, state.policyRecords)
    return selectedCleared
  }

  static mergePolicySnapshots(state: PermissionPageState, nextSnapshots: PermissionAppSnapshot[]): PermissionAppSnapshot[] {
    return nextSnapshots.map((snapshot: PermissionAppSnapshot): PermissionAppSnapshot => {
      let previous = PermissionStateReducer.findAppSnapshot(state, snapshot.appKey)
      if (previous === undefined ||
        previous.threeDLoadState !== 'loaded' ||
        !PermissionStateReducer.isSameApplicationIdentity(previous, snapshot)) {
        return snapshot
      }
      let nextGroups = snapshot.threeDGroups.length > 0 ? snapshot.threeDGroups : previous.threeDGroups
      let nextPolicies = snapshot.threeDPolicies.length > 0
        ? snapshot.threeDPolicies
        : PermissionPolicyRecordMapper.buildThreeDPolicySnapshotsFromGroups(snapshot, nextGroups)
      return {
        appKey: snapshot.appKey,
        accountId: snapshot.accountId,
        bundleName: snapshot.bundleName,
        appId: snapshot.appId,
        appIdentifier: snapshot.appIdentifier,
        label: snapshot.label,
        uid: snapshot.uid,
        appIndex: snapshot.appIndex,
        uninstallProtected: snapshot.uninstallProtected,
        runningBlocked: snapshot.runningBlocked,
        networkBlocked: snapshot.networkBlocked,
        threeDGroups: nextGroups,
        threeDPolicies: nextPolicies,
        threeDLoadState: previous.threeDLoadState,
        threeDMessage: previous.threeDMessage
      } as PermissionAppSnapshot
    })
  }

  static reconcileSelectedApplicationAfterRefresh(
    state: PermissionPageState,
    previousSelectedSnapshot: PermissionAppSnapshot | undefined
  ): boolean {
    if (previousSelectedSnapshot === undefined) {
      return false
    }
    let refreshedSnapshot = PermissionStateReducer.findAppSnapshot(state, previousSelectedSnapshot.appKey)
    if (refreshedSnapshot === undefined ||
      !PermissionStateReducer.isSameApplicationIdentity(previousSelectedSnapshot, refreshedSnapshot)) {
      PermissionStateReducer.clearSelectedApplicationState(state)
      return true
    }
    return false
  }

  static isSameApplicationIdentity(previous: PermissionAppSnapshot, next: PermissionAppSnapshot): boolean {
    return previous.accountId === next.accountId &&
      previous.appKey === next.appKey &&
      previous.bundleName === next.bundleName &&
      previous.appId === next.appId &&
      previous.appIdentifier === next.appIdentifier &&
      previous.appIndex === next.appIndex
  }

  static isApplicationPolicyRecord(actionKind: string): boolean {
    return actionKind !== 'install-deny' && actionKind !== 'install-allow'
  }

  static findAppSnapshot(state: PermissionPageState, appKey: string): PermissionAppSnapshot | undefined {
    return state.appSnapshots.find((snapshot: PermissionAppSnapshot): boolean => snapshot.appKey === appKey)
  }

  static getSelectedAppSnapshot(state: PermissionPageState): PermissionAppSnapshot | undefined {
    if (state.selectedAppKey.length === 0) {
      return undefined
    }
    return PermissionStateReducer.findAppSnapshot(state, state.selectedAppKey)
  }

  static buildSelectedPermissionProfile(snapshot: PermissionAppSnapshot): ApplicationPermissionProfile | null {
    return {
      appKey: snapshot.appKey,
      bundleName: snapshot.bundleName,
      requestedPermissions: [],
      mainAbilityName: '',
      sensitivePermissionCount: snapshot.threeDGroups.filter((item: ThreeDPermissionItem): boolean => item.canManage).length,
      message: snapshot.threeDMessage,
      threeDGroups: snapshot.threeDGroups
    } as ApplicationPermissionProfile
  }

  static clearSelectedApplicationState(state: PermissionPageState): void {
    state.selectedAppKey = ''
    state.loadingSelectedApp = false
  }

  static patchAppSnapshot(
    state: PermissionPageState,
    appKey: string,
    patch: PermissionAppSnapshotPatch
  ): boolean {
    let nextSnapshots = state.appSnapshots.map((snapshot: PermissionAppSnapshot): PermissionAppSnapshot => {
      if (snapshot.appKey !== appKey) {
        return snapshot
      }
      return {
        appKey: snapshot.appKey,
        accountId: snapshot.accountId,
        bundleName: snapshot.bundleName,
        appId: snapshot.appId,
        appIdentifier: snapshot.appIdentifier,
        label: snapshot.label,
        uid: snapshot.uid,
        appIndex: snapshot.appIndex,
        uninstallProtected: patch.uninstallProtected !== undefined ? patch.uninstallProtected : snapshot.uninstallProtected,
        runningBlocked: patch.runningBlocked !== undefined ? patch.runningBlocked : snapshot.runningBlocked,
        networkBlocked: patch.networkBlocked !== undefined ? patch.networkBlocked : snapshot.networkBlocked,
        threeDGroups: patch.threeDGroups !== undefined ? patch.threeDGroups : snapshot.threeDGroups,
        threeDPolicies: patch.threeDPolicies !== undefined ? patch.threeDPolicies : snapshot.threeDPolicies,
        threeDLoadState: patch.threeDLoadState !== undefined ? patch.threeDLoadState : snapshot.threeDLoadState,
        threeDMessage: patch.threeDMessage !== undefined ? patch.threeDMessage : snapshot.threeDMessage
      } as PermissionAppSnapshot
    })
    return PermissionStateReducer.commit(state, { appSnapshots: nextSnapshots })
  }

  static patchInstallPolicies(state: PermissionPageState, removePolicyId: string): boolean {
    let nextPolicies = state.installPolicies.filter(
      (p: AccountInstallPolicySnapshot): boolean => p.policyId !== removePolicyId
    )
    return PermissionStateReducer.commit(state, { installPolicies: nextPolicies })
  }

  static patchThreeDState(
    state: PermissionPageState,
    appKey: string,
    groupKey: string,
    managedState: ThreeDManagedState
  ): boolean {
    let snapshot = PermissionStateReducer.findAppSnapshot(state, appKey)
    if (snapshot === undefined) {
      return false
    }
    let nextGroups = snapshot.threeDGroups.map((item: ThreeDPermissionItem): ThreeDPermissionItem => {
      if (item.groupKey !== groupKey) {
        return item
      }
      return {
        groupKey: item.groupKey,
        title: item.title,
        permissionNames: item.permissionNames,
        declaredPermissions: item.declaredPermissions,
        managedState: managedState,
        canManage: item.canManage,
        disabledReason: item.disabledReason
      } as ThreeDPermissionItem
    })
    let nextPolicies: PermissionThreeDPolicySnapshot[]
    if (managedState === 'default') {
      nextPolicies = snapshot.threeDPolicies.filter(
        (p: PermissionThreeDPolicySnapshot): boolean => p.groupKey !== groupKey
      )
    } else {
      let existing = snapshot.threeDPolicies.find(
        (p: PermissionThreeDPolicySnapshot): boolean => p.groupKey === groupKey
      )
      let policyType = existing?.policyType ?? nextGroups.find((i: ThreeDPermissionItem): boolean =>
        i.groupKey === groupKey
      )?.title ?? ''
      let updated: PermissionThreeDPolicySnapshot = {
        recordId: PermissionPolicyRecordMapper.getThreeDRecordKey(appKey, groupKey),
        appKey: appKey,
        groupKey: groupKey,
        actionKind: 'three-d',
        policyValue: managedState,
        policyType: policyType,
        targetName: snapshot.label,
        targetDetail: `${snapshot.bundleName} / ${policyType}`,
        statusLabel: PermissionPolicyRecordMapper.formatThreeDState(managedState),
        scopeLabel: `${PermissionApplicationStrings.POLICY_SCOPE_ACCOUNT_PREFIX} ${snapshot.accountId}`
      } as PermissionThreeDPolicySnapshot
      let found = false
      nextPolicies = snapshot.threeDPolicies.map((p: PermissionThreeDPolicySnapshot): PermissionThreeDPolicySnapshot => {
        if (p.groupKey === groupKey) {
          found = true
          return updated
        }
        return p
      })
      if (!found) {
        nextPolicies.push(updated)
      }
    }
    return PermissionStateReducer.patchAppSnapshot(state, appKey, { threeDGroups: nextGroups, threeDPolicies: nextPolicies })
  }

  private static hasSelectedApplicationState(state: PermissionPageState): boolean {
    return state.selectedAppKey.length > 0
  }
}

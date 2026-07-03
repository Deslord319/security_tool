import {
  PermissionAppSnapshot,
  PermissionLocalPolicyRecord,
  PermissionPolicyActionKind,
  PermissionThreeDPolicySnapshot,
  ThreeDManagedState,
  ThreeDPermissionItem
} from '../../models/PermissionModels'
import { PermissionApplicationStrings } from '../../constants/modules/PermissionStrings'

export interface LocalPolicyRecordParams {
  recordId: string
  app: PermissionAppSnapshot
  policyType: string
  policyValue: string
  statusLabel: string
  actionKind: PermissionPolicyActionKind
  policyId: string
  targetName: string
  targetDetail: string
}

export class PermissionPolicyRecordMapper {
  static getThreeDRecordKey(appKey: string, groupKey: string): string {
    return `three-d:${appKey}:${groupKey}`
  }

  static buildThreeDPolicySnapshotsFromGroups(
    snapshot: PermissionAppSnapshot,
    groups: ThreeDPermissionItem[]
  ): PermissionThreeDPolicySnapshot[] {
    return groups
      .filter((item: ThreeDPermissionItem): boolean =>
        item.canManage && (item.managedState === 'granted' || item.managedState === 'denied')
      )
      .map((item: ThreeDPermissionItem): PermissionThreeDPolicySnapshot => ({
        recordId: PermissionPolicyRecordMapper.getThreeDRecordKey(snapshot.appKey, item.groupKey),
        appKey: snapshot.appKey,
        groupKey: item.groupKey,
        actionKind: 'three-d',
        policyValue: item.managedState,
        policyType: item.title,
        targetName: snapshot.label,
        targetDetail: `${snapshot.bundleName} / ${item.title}`,
        statusLabel: PermissionPolicyRecordMapper.formatThreeDState(item.managedState),
        scopeLabel: `${PermissionApplicationStrings.POLICY_SCOPE_ACCOUNT_PREFIX} ${snapshot.accountId}`
      } as PermissionThreeDPolicySnapshot))
  }

  static buildLocalPolicyRecord(params: LocalPolicyRecordParams): PermissionLocalPolicyRecord {
    let now = Date.now()
    return {
      recordId: params.recordId,
      accountId: params.app.accountId,
      appKey: params.app.appKey,
      bundleName: params.app.bundleName,
      appIdentifier: params.app.appIdentifier,
      appIndex: params.app.appIndex,
      policyType: params.policyType,
      policyValue: params.policyValue,
      targetName: params.targetName,
      targetDetail: params.targetDetail,
      statusLabel: params.statusLabel,
      scopeLabel: `${PermissionApplicationStrings.POLICY_SCOPE_ACCOUNT_PREFIX} ${params.app.accountId}`,
      actionKind: params.actionKind,
      policyId: params.policyId,
      status: 'active',
      createdAt: now,
      updatedAt: now,
      lastError: ''
    } as PermissionLocalPolicyRecord
  }

  static formatThreeDState(state: ThreeDManagedState): string {
    if (state === 'granted') {
      return PermissionApplicationStrings.POLICY_ALLOWED
    }
    if (state === 'denied') {
      return PermissionApplicationStrings.POLICY_DENIED
    }
    return PermissionApplicationStrings.POLICY_DEFAULT
  }
}

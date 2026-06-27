import { bundleManager } from '@kit.AbilityKit'
import { securityManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../constants/AppConstants'
import { PermissionApplicationStrings, PermissionThreeDStrings } from '../../constants/modules/PermissionStrings'
import {
  ApplicationPermissionProfile,
  PermissionAppSnapshot,
  ThreeDManagedState,
  ThreeDPermissionItem
} from '../../models/PermissionModels'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'ThreeDPermissionRepository'
const FULL_DISK_PERMISSION = 'ohos.permission.ACCESS_USER_FULL_DISK'

interface ThreeDPermissionDefinition {
  groupKey: string
  title: string
  permissionNames: string[]
}

const THREE_D_PERMISSION_DEFINITIONS: ThreeDPermissionDefinition[] = [
  {
    groupKey: 'downloads',
    title: PermissionThreeDStrings.DOWNLOADS,
    permissionNames: ['ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY']
  },
  {
    groupKey: 'desktop',
    title: PermissionThreeDStrings.DESKTOP,
    permissionNames: ['ohos.permission.READ_WRITE_DESKTOP_DIRECTORY']
  },
  {
    groupKey: 'documents',
    title: PermissionThreeDStrings.DOCUMENTS,
    permissionNames: ['ohos.permission.READ_WRITE_DOCUMENTS_DIRECTORY']
  }
]

export class ThreeDPermissionRepository {
  static async loadPermissionProfile(app: PermissionAppSnapshot): Promise<ApplicationPermissionProfile> {
    try {
      let bundleInfo = await bundleManager.getBundleInfo(
        app.bundleName,
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_REQUESTED_PERMISSION |
          bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
          bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_ABILITY,
        app.accountId
      )
      let requestedPermissions = ThreeDPermissionRepository.extractRequestedPermissions(bundleInfo)
      let mainAbilityName = ThreeDPermissionRepository.extractMainAbilityName(bundleInfo)
      let groups = THREE_D_PERMISSION_DEFINITIONS.map((definition: ThreeDPermissionDefinition): ThreeDPermissionItem =>
        ThreeDPermissionRepository.buildPermissionItem(app, definition, requestedPermissions)
      )
      let sensitivePermissionCount = groups
        .filter((item: ThreeDPermissionItem): boolean => item.declaredPermissions.length > 0)
        .length
      return {
        appKey: app.appKey,
        bundleName: app.bundleName,
        requestedPermissions: requestedPermissions,
        mainAbilityName: mainAbilityName,
        sensitivePermissionCount: sensitivePermissionCount,
        message: sensitivePermissionCount === 0 ? PermissionThreeDStrings.NO_DECLARED : '',
        threeDGroups: groups
      } as ApplicationPermissionProfile
    } catch (err) {
      LogUtils.warn(TAG, `loadPermissionProfile failed: ${JSON.stringify(err)}`)
      return ThreeDPermissionRepository.buildUnsupportedProfile(app, PermissionThreeDStrings.DETAIL_FAILED)
    }
  }

  static async setPermissionState(app: PermissionAppSnapshot, item: ThreeDPermissionItem, state: ThreeDManagedState): Promise<void> {
    if (!item.canManage || item.declaredPermissions.length === 0) {
      throw new Error('permission undeclared')
    }
    try {
      await securityManager.setPermissionManagedState(
        ADMIN_WANT,
        ThreeDPermissionRepository.buildApplicationInstance(app),
        item.declaredPermissions,
        ThreeDPermissionRepository.toSystemState(state)
      )
    } catch (err) {
      LogUtils.warn(TAG, `setPermissionManagedState failed: ${JSON.stringify(err)}`)
      throw new Error(`setPermissionManagedState failed: ${JSON.stringify(err)}`)
    }
  }

  static findPermissionItem(
    profile: ApplicationPermissionProfile | null,
    groupKey: string
  ): ThreeDPermissionItem | undefined {
    return profile?.threeDGroups.find((item: ThreeDPermissionItem): boolean => item.groupKey === groupKey)
  }

  private static buildPermissionItem(
    app: PermissionAppSnapshot,
    definition: ThreeDPermissionDefinition,
    requestedPermissions: string[]
  ): ThreeDPermissionItem {
    let declaredPermissions = definition.permissionNames.filter((permissionName: string): boolean =>
      requestedPermissions.includes(permissionName)
    )
    if (declaredPermissions.length === 0 && requestedPermissions.includes(FULL_DISK_PERMISSION)) {
      declaredPermissions = [FULL_DISK_PERMISSION]
    }
    if (declaredPermissions.length === 0) {
      return ThreeDPermissionRepository.createItem(
        definition,
        [],
        'undeclared',
        false,
        PermissionApplicationStrings.THREE_D_UNDECLARED
      )
    }
    try {
      return ThreeDPermissionRepository.createItem(
        definition,
        declaredPermissions,
        ThreeDPermissionRepository.resolveManagedState(app, declaredPermissions),
        true,
        declaredPermissions.includes(FULL_DISK_PERMISSION) ? PermissionApplicationStrings.THREE_D_FULL_FILE_DESC : ''
      )
    } catch (err) {
      LogUtils.warn(TAG, `resolveManagedState failed: ${JSON.stringify(err)}`)
      return ThreeDPermissionRepository.createItem(
        definition,
        declaredPermissions,
        'default',
        true,
        declaredPermissions.includes(FULL_DISK_PERMISSION) ? PermissionApplicationStrings.THREE_D_FULL_FILE_DESC : ''
      )
    }
  }

  private static createItem(
    definition: ThreeDPermissionDefinition,
    declaredPermissions: string[],
    managedState: ThreeDManagedState,
    canManage: boolean,
    disabledReason: string
  ): ThreeDPermissionItem {
    return {
      groupKey: definition.groupKey,
      title: definition.title,
      permissionNames: definition.permissionNames,
      declaredPermissions: declaredPermissions,
      managedState: managedState,
      canManage: canManage,
      disabledReason: disabledReason
    } as ThreeDPermissionItem
  }

  static buildUnsupportedProfile(app: PermissionAppSnapshot, message: string): ApplicationPermissionProfile {
    return {
      appKey: app.appKey,
      bundleName: app.bundleName,
      requestedPermissions: [],
      mainAbilityName: '',
      sensitivePermissionCount: 0,
      message: message,
      threeDGroups: THREE_D_PERMISSION_DEFINITIONS.map((definition: ThreeDPermissionDefinition): ThreeDPermissionItem =>
        ThreeDPermissionRepository.createItem(definition, [], 'unsupported', false, message)
      )
    } as ApplicationPermissionProfile
  }

  private static extractRequestedPermissions(bundleInfo: bundleManager.BundleInfo): string[] {
    return (bundleInfo.reqPermissionDetails ?? [])
      .map((permissionDetail: bundleManager.ReqPermissionDetail): string => permissionDetail.name)
      .filter((permissionName: string, index: number, all: string[]): boolean =>
        permissionName.length > 0 && all.indexOf(permissionName) === index
      )
  }

  private static extractMainAbilityName(bundleInfo: bundleManager.BundleInfo): string {
    let modules = bundleInfo.hapModulesInfo ?? []
    for (let index = 0; index < modules.length; index++) {
      let moduleInfo = modules[index]
      if (moduleInfo.mainElementName.length > 0) {
        return moduleInfo.mainElementName
      }
      let abilities = moduleInfo.abilitiesInfo ?? []
      if (abilities.length > 0 && abilities[0].name.length > 0) {
        return abilities[0].name
      }
    }
    return ''
  }

  private static resolveManagedState(app: PermissionAppSnapshot, permissions: string[]): ThreeDManagedState {
    let states = permissions.map((permissionName: string): securityManager.PermissionManagedState =>
      securityManager.getPermissionManagedState(
        ADMIN_WANT,
        ThreeDPermissionRepository.buildApplicationInstance(app),
        permissionName
      )
    )
    if (states.includes(securityManager.PermissionManagedState.DENIED)) {
      return 'denied'
    }
    if (states.includes(securityManager.PermissionManagedState.GRANTED)) {
      return 'granted'
    }
    return 'default'
  }

  private static buildApplicationInstance(app: PermissionAppSnapshot): securityManager.ApplicationInstance {
    return {
      appIdentifier: app.appIdentifier,
      accountId: app.accountId,
      appIndex: app.appIndex
    } as securityManager.ApplicationInstance
  }

  private static toSystemState(state: ThreeDManagedState): securityManager.PermissionManagedState {
    if (state === 'granted') {
      return securityManager.PermissionManagedState.GRANTED
    }
    if (state === 'denied') {
      return securityManager.PermissionManagedState.DENIED
    }
    return securityManager.PermissionManagedState.DEFAULT
  }
}

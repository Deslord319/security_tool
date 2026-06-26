import { bundleManager } from '@kit.AbilityKit'
import { securityManager } from '@kit.MDMKit'
import { ADMIN_WANT } from '../../constants/AppConstants'
import { PermissionApplicationStrings, PermissionSixDStrings } from '../../constants/modules/PermissionStrings'
import {
  ApplicationPermissionProfile,
  ManagedApplicationInfo,
  SixDManagedState,
  SixDPermissionItem
} from '../../models/PermissionModels'
import { LogUtils } from '../../utils/LogUtils'

const TAG = 'SixDPermissionRepository'
const FULL_FILE_PERMISSION = 'ohos.permission.READ_WRITE_USER_FILE'

interface SixDPermissionDefinition {
  groupKey: string
  title: string
  permissionNames: string[]
}

const SIX_D_PERMISSION_DEFINITIONS: SixDPermissionDefinition[] = [
  {
    groupKey: 'downloads',
    title: PermissionSixDStrings.DOWNLOADS,
    permissionNames: ['ohos.permission.READ_WRITE_DOWNLOAD_DIRECTORY']
  },
  {
    groupKey: 'desktop',
    title: PermissionSixDStrings.DESKTOP,
    permissionNames: ['ohos.permission.READ_WRITE_DESKTOP_DIRECTORY']
  },
  {
    groupKey: 'documents',
    title: PermissionSixDStrings.DOCUMENTS,
    permissionNames: ['ohos.permission.READ_WRITE_DOCUMENTS_DIRECTORY']
  },
  {
    groupKey: 'gallery',
    title: PermissionSixDStrings.GALLERY,
    permissionNames: ['ohos.permission.READ_IMAGEVIDEO', 'ohos.permission.WRITE_IMAGEVIDEO']
  },
  {
    groupKey: 'music',
    title: PermissionSixDStrings.MUSIC,
    permissionNames: ['ohos.permission.READ_AUDIO', 'ohos.permission.WRITE_AUDIO']
  },
  {
    groupKey: 'document_file',
    title: PermissionSixDStrings.DOCUMENT_FILE,
    permissionNames: ['ohos.permission.READ_DOCUMENT', 'ohos.permission.WRITE_DOCUMENT']
  }
]

export class SixDPermissionRepository {
  static async loadPermissionProfile(app: ManagedApplicationInfo): Promise<ApplicationPermissionProfile> {
    try {
      let bundleInfo = await bundleManager.getBundleInfo(
        app.bundleName,
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_REQUESTED_PERMISSION |
          bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_HAP_MODULE |
          bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_ABILITY,
        app.accountId
      )
      let requestedPermissions = SixDPermissionRepository.extractRequestedPermissions(bundleInfo)
      let mainAbilityName = SixDPermissionRepository.extractMainAbilityName(bundleInfo)
      let groups = SIX_D_PERMISSION_DEFINITIONS.map((definition: SixDPermissionDefinition): SixDPermissionItem =>
        SixDPermissionRepository.buildPermissionItem(app, definition, requestedPermissions)
      )
      let sensitivePermissionCount = groups
        .filter((item: SixDPermissionItem): boolean => item.declaredPermissions.length > 0)
        .length
      return {
        appKey: app.key,
        bundleName: app.bundleName,
        requestedPermissions: requestedPermissions,
        mainAbilityName: mainAbilityName,
        sensitivePermissionCount: sensitivePermissionCount,
        message: sensitivePermissionCount === 0 ? PermissionSixDStrings.NO_DECLARED : '',
        sixDGroups: groups
      } as ApplicationPermissionProfile
    } catch (err) {
      LogUtils.warn(TAG, `loadPermissionProfile failed: ${JSON.stringify(err)}`)
      return SixDPermissionRepository.buildUnsupportedProfile(app, PermissionSixDStrings.DETAIL_FAILED)
    }
  }

  static async setPermissionState(app: ManagedApplicationInfo, item: SixDPermissionItem, state: SixDManagedState): Promise<void> {
    if (!item.canManage || item.declaredPermissions.length === 0) {
      throw new Error('permission undeclared')
    }
    await securityManager.setPermissionManagedState(
      ADMIN_WANT,
      SixDPermissionRepository.buildApplicationInstance(app),
      item.declaredPermissions,
      SixDPermissionRepository.toSystemState(state)
    )
  }

  static findPermissionItem(
    profile: ApplicationPermissionProfile | null,
    groupKey: string
  ): SixDPermissionItem | undefined {
    return profile?.sixDGroups.find((item: SixDPermissionItem): boolean => item.groupKey === groupKey)
  }

  private static buildPermissionItem(
    app: ManagedApplicationInfo,
    definition: SixDPermissionDefinition,
    requestedPermissions: string[]
  ): SixDPermissionItem {
    let declaredPermissions = definition.permissionNames.filter((permissionName: string): boolean =>
      requestedPermissions.includes(permissionName)
    )
    if (declaredPermissions.length === 0 && requestedPermissions.includes(FULL_FILE_PERMISSION)) {
      declaredPermissions = [FULL_FILE_PERMISSION]
    }
    if (declaredPermissions.length === 0) {
      return SixDPermissionRepository.createItem(
        definition,
        [],
        'undeclared',
        false,
        PermissionApplicationStrings.SIX_D_UNDECLARED
      )
    }
    try {
      return SixDPermissionRepository.createItem(
        definition,
        declaredPermissions,
        SixDPermissionRepository.resolveManagedState(app, declaredPermissions),
        true,
        declaredPermissions.includes(FULL_FILE_PERMISSION) ? PermissionApplicationStrings.SIX_D_FULL_FILE_DESC : ''
      )
    } catch (err) {
      LogUtils.warn(TAG, `resolveManagedState failed: ${JSON.stringify(err)}`)
      return SixDPermissionRepository.createItem(
        definition,
        declaredPermissions,
        'unsupported',
        false,
        PermissionApplicationStrings.SIX_D_UNSUPPORTED
      )
    }
  }

  private static createItem(
    definition: SixDPermissionDefinition,
    declaredPermissions: string[],
    managedState: SixDManagedState,
    canManage: boolean,
    disabledReason: string
  ): SixDPermissionItem {
    return {
      groupKey: definition.groupKey,
      title: definition.title,
      permissionNames: definition.permissionNames,
      declaredPermissions: declaredPermissions,
      managedState: managedState,
      canManage: canManage,
      disabledReason: disabledReason
    } as SixDPermissionItem
  }

  static buildUnsupportedProfile(app: ManagedApplicationInfo, message: string): ApplicationPermissionProfile {
    return {
      appKey: app.key,
      bundleName: app.bundleName,
      requestedPermissions: [],
      mainAbilityName: '',
      sensitivePermissionCount: 0,
      message: message,
      sixDGroups: SIX_D_PERMISSION_DEFINITIONS.map((definition: SixDPermissionDefinition): SixDPermissionItem =>
        SixDPermissionRepository.createItem(definition, [], 'unsupported', false, message)
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

  private static resolveManagedState(app: ManagedApplicationInfo, permissions: string[]): SixDManagedState {
    let states = permissions.map((permissionName: string): securityManager.PermissionManagedState =>
      securityManager.getPermissionManagedState(
        ADMIN_WANT,
        SixDPermissionRepository.buildApplicationInstance(app),
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

  private static buildApplicationInstance(app: ManagedApplicationInfo): securityManager.ApplicationInstance {
    return {
      appIdentifier: app.appIdentifier,
      accountId: app.accountId,
      appIndex: app.appIndex
    } as securityManager.ApplicationInstance
  }

  private static toSystemState(state: SixDManagedState): securityManager.PermissionManagedState {
    if (state === 'granted') {
      return securityManager.PermissionManagedState.GRANTED
    }
    if (state === 'denied') {
      return securityManager.PermissionManagedState.DENIED
    }
    return securityManager.PermissionManagedState.DEFAULT
  }
}

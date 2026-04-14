import { common, contextConstant, StartOptions, Want } from '@kit.AbilityKit'
import { image } from '@kit.ImageKit'
import { statusBarManager } from '@kit.DeskTopExtensionKit'

import { AppInfo } from '../constants/AppConstants'
import { AppResources } from '../constants/AppResources'
import { LogUtils } from './LogUtils'

const TAG = 'StatusBarUtil'

async function getPixelMap(context: common.UIAbilityContext): Promise<PixelMap> {
  let fileData = context.resourceManager.getMediaContentSync(AppResources.START_ICON_ABOUT.id)
  let imageSource = image.createImageSource(fileData.buffer)
  return await imageSource.createPixelMap()
}

export async function loadStatusBar(context: common.UIAbilityContext): Promise<void> {
  let trayIcon = await getPixelMap(context)
  let icons: statusBarManager.StatusBarIcon = {
    white: trayIcon,
    black: trayIcon
  }
  let quickOperation: statusBarManager.QuickOperation = {
    abilityName: '',
    title: AppInfo.STATUS_BAR_TITLE,
    height: 30,
    moduleName: AppInfo.ENTRY_MODULE_NAME
  }
  let statusBarItem: statusBarManager.StatusBarItem = {
    icons: icons,
    quickOperation: quickOperation
  }
  statusBarManager.addToStatusBar(context, statusBarItem)
  LogUtils.info(TAG, 'loadStatusBar success')
}

export function holdStatusBar(context: common.UIAbilityContext | common.UIExtensionContext): Promise<void> {
  return new Promise((resolve, reject) => {
    let want: Want = {
      bundleName: AppInfo.BUNDLE_NAME,
      abilityName: AppInfo.BACKGROUND_ABILITY_NAME
    }
    let options: StartOptions = {
      processMode: contextConstant.ProcessMode.NEW_PROCESS_ATTACH_TO_STATUS_BAR_ITEM,
      startupVisibility: contextConstant.StartupVisibility.STARTUP_HIDE
    }
    context.startAbility(want, options, (err) => {
      if (err.code) {
        LogUtils.warn(TAG, 'holdStatusBar failed: %{public}s', JSON.stringify(err))
        reject(err)
        return
      }
      LogUtils.info(TAG, 'holdStatusBar success')
      resolve()
    })
  })
}

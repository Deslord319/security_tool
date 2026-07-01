import { common, contextConstant, StartOptions, Want } from '@kit.AbilityKit'
import { image } from '@kit.ImageKit'
import { statusBarManager } from '@kit.DeskTopExtensionKit'
import { AppInfo } from '../constants/AppConstants'
import { LogUtils } from './LogUtils'

const TAG = 'StatusBarUtil'

async function getPixelMap(context: common.UIAbilityContext): Promise<PixelMap | null> {
  try {
    let fileData = context.resourceManager.getMediaContentSync($r('app.media.startIcon').id)
    let imageSource = image.createImageSource(fileData.buffer)
    return await imageSource.createPixelMap()
  } catch (err) {
    LogUtils.warn(TAG, `getPixelMap failed: ${JSON.stringify(err)}`)
    return null
  }
}

export async function loadStatusBar(context: common.UIAbilityContext): Promise<void> {
  let trayIcon = await getPixelMap(context)
  if (!trayIcon) {
    LogUtils.warn(TAG, 'loadStatusBar skipped: tray icon unavailable')
    return
  }
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
    quickOperation: quickOperation,
    hoverTips: AppInfo.STATUS_BAR_TITLE
  }
  try {
    statusBarManager.addToStatusBar(context, statusBarItem)
  } catch (err) {
    LogUtils.warn(TAG, `loadStatusBar failed: ${JSON.stringify(err)}`)
    return
  }
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
        LogUtils.warn(TAG, `holdStatusBar failed: ${JSON.stringify(err)}`)
        reject(err)
        return
      }
      LogUtils.info(TAG, 'holdStatusBar success')
      resolve()
    })
  })
}

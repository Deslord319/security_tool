export interface LockScreenAuthConfig {
  ukeyUnlockEnabled: boolean
}

export interface LockScreenUKeyDevice {
  fingerprint: string
  deviceId: string
  vendorId: number
  productId: number
  serial: string
  manufacturerName: string
  productName: string
  deviceName: string
  clazz: number
  subClass: number
  protocol: number
  stableIdentifier: boolean
}

export interface LockScreenUKeyBinding {
  fingerprint: string
  deviceId: string
  deviceName: string
  userId: number
  credentialIdHex: string
  pluginInfo: string
  boundAt: number
  stableIdentifier: boolean
}

export const DEFAULT_LOCKSCREEN_AUTH_CONFIG: LockScreenAuthConfig = {
  ukeyUnlockEnabled: true
}

export const LOCKSCREEN_CUSTOM_AUTH_BUNDLE_NAME: string = 'com.demo.customauthenticator'
export const LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO: string = JSON.stringify({
  customAuthenticatorType: 'HAP',
  customAuthenticatorBundleName: LOCKSCREEN_CUSTOM_AUTH_BUNDLE_NAME,
  customAuthenticatorAppIdentifier: LOCKSCREEN_CUSTOM_AUTH_BUNDLE_NAME,
  customAuthenticatorProtocolVersion: 1
})

export const PREF_STORE_NAME_LOCKSCREEN_AUTH: string = 'lockscreen_auth_settings'
export const PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED: string = 'lockscreen_ukey_auth_enabled'
export const PREF_KEY_LOCKSCREEN_UKEY_BINDING: string = 'lockscreen_ukey_binding'

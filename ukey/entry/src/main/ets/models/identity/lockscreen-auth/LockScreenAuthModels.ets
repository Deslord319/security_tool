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

export type LockScreenUKeyCredentialLifecycle =
  'active' |
  'inactive' |
  'failed'

export interface LockScreenUKeyUserCredential {
  userId: number
  credentialIdHex: string
  templateId: string
  pluginInfo: string
  lifecycle: LockScreenUKeyCredentialLifecycle
  createdAt: number
}

export interface LockScreenUKeyBinding {
  fingerprint: string
  deviceId: string
  deviceName: string
  boundAt: number
  stableIdentifier: boolean
  userCredentials: LockScreenUKeyUserCredential[]
}

export interface LockScreenUKeyActiveCredential {
  fingerprint: string
  deviceId: string
  deviceName: string
  createdAt: number
  lifecycle: LockScreenUKeyCredentialLifecycle
  userCredentials: LockScreenUKeyUserCredential[]
}

export const DEFAULT_LOCKSCREEN_AUTH_CONFIG: LockScreenAuthConfig = {
  ukeyUnlockEnabled: true
}

export const LOCKSCREEN_CUSTOM_AUTH_BUNDLE_NAME: string = 'com.ukey.pin'
export const LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO: string = JSON.stringify({
  customAuthenticatorType: 'HAP',
  customAuthenticatorBundleName: LOCKSCREEN_CUSTOM_AUTH_BUNDLE_NAME,
  customAuthenticatorAppIdentifier: LOCKSCREEN_CUSTOM_AUTH_BUNDLE_NAME,
  customAuthenticatorProtocolVersion: 1
})

export const PREF_STORE_NAME_LOCKSCREEN_AUTH: string = 'ukey_lockscreen_auth_settings_gskv_v1'
export const PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED: string = 'lockscreen_ukey_auth_enabled'
export const PREF_KEY_LOCKSCREEN_UKEY_BINDING: string = 'lockscreen_ukey_binding'
export const PREF_KEY_LOCKSCREEN_UKEY_ACTIVE_CREDENTIAL: string = 'lockscreen_ukey_active_credential'
export const PREF_KEY_LOCKSCREEN_UKEY_PASSWORD_STATES: string = 'lockscreen_ukey_password_states'

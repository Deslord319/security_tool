export interface PasscodePromptParams {
  challenge: Uint8Array
}

export type PasscodePromptCallback = (submit: (passcode: Uint8Array) => void, options: PasscodePromptParams) => void

interface CompanionDeviceAuthApi {
  registerPasscodePromptCallback(callback: PasscodePromptCallback): void
  unregisterPasscodePromptCallback(): void
}

declare function requireNapi(moduleName: string): CompanionDeviceAuthApi

const companionDeviceAuth: CompanionDeviceAuthApi = requireNapi('userIAM.companionDeviceAuth')

export default companionDeviceAuth

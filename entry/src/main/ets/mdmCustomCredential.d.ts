/**
 * Minimal custom credential declarations sourced from:
 * C:\Users\mu\Desktop\CustomAuth\design\interface\mdm_js\@mdm.d.ts
 */
declare function loadNativeModule(moduleName: string): Object

interface MdmCustomCredentialAddParam {
  userId: number
  authToken?: Uint8Array
  pluginInfo: string
}

interface MdmCustomCredentialAddResult {
  resultCode: number
  credentialId?: Uint8Array
}

interface MdmCustomCredentialDeleteParam {
  credentialId: Uint8Array
  authToken?: Uint8Array
}

interface MdmCustomCredentialInfo {
  credentialId: Uint8Array
  pluginInfo: string
}

interface MdmCustomCredentialModule {
  openSession(userId: number): Promise<Uint8Array>
  closeSession(userId: number): void
  addUserCustomCredential(param: MdmCustomCredentialAddParam): Promise<MdmCustomCredentialAddResult>
  deleteUserCustomCredential(param: MdmCustomCredentialDeleteParam): Promise<void>
  getUserCustomCredentials(userId: number): Promise<Uint8Array[]>
  getUserCustomCredentialInfo(userId: number): Promise<MdmCustomCredentialInfo[]>
}

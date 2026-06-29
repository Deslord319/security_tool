/**
 * Minimal local osAccount declarations used by SecurityTool.
 *
 * The installed API 26 SDK declarations available in this workspace do not expose
 * the CustomAuth UserIdentityManager systemapi surface, so only the osAccount
 * surface used by this project is declared locally.
 */
declare module '@ohos.account.osAccount' {
  namespace osAccount {
    function getAccountManager(): AccountManager

    interface OsAccountInfo {
      localId: number
      localName?: string
      isActivated?: boolean
      isVerified?: boolean
      isCreateCompleted?: boolean
    }

    interface AccountManager {
      getActivatedOsAccountLocalIds(): Promise<number[]>
      getForegroundOsAccountLocalId(): Promise<number>
      getOsAccountName(): Promise<string>
      queryOsAccountById?(localId: number): Promise<OsAccountInfo>
    }

    type AuthType = number

    type AuthSubType = number

    interface CredentialInfo {
      credType: AuthType
      credSubType: AuthSubType
      token: Uint8Array
      accountId: number
      additionalInfo: string
    }

    interface RequestResult {
      credentialId?: Uint8Array
    }

    interface IIdmCallback {
      onResult: (result: number, extraInfo: RequestResult) => void
      onAcquireInfo?: (module: number, acquire: number, extraInfo: Uint8Array) => void
    }

    class UserIdentityManager {
      constructor()
      openSession(accountId?: number): Promise<Uint8Array>
      addCredential(credentialInfo: CredentialInfo, callback: IIdmCallback): void
      closeSession(accountId?: number): void
    }
  }

  export default osAccount
}

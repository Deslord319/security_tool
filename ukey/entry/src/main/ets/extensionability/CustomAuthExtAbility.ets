import { AppServiceExtensionAbility, Want } from '@kit.AbilityKit'
import { rpc } from '@kit.IPCKit'
import { LogUtils } from '../utils/LogUtils'
import { CustomAuthStub } from '../services/identity/custom-auth-core/ipc/CustomAuthStub'
import { authenticatorUKeyProvider } from '../services/identity/custom-auth-core/ukey/AuthenticatorUKeyProvider'

const TAG = 'CustomAuth.Ext'

export default class CustomAuthExtAbility extends AppServiceExtensionAbility {
  private stub: CustomAuthStub | null = null

  onCreate(want: Want): void {
    authenticatorUKeyProvider.bindContext(this.context)
    LogUtils.info(TAG, `onCreate, abilityName=${want.abilityName}`)
  }

  onConnect(want: Want): rpc.RemoteObject {
    const callerUid = rpc.IPCSkeleton.getCallingUid()
    const callerPid = rpc.IPCSkeleton.getCallingPid()
    LogUtils.info(TAG, `onConnect, abilityName=${want.abilityName}, callerUid=${callerUid}, callerPid=${callerPid}`)
    authenticatorUKeyProvider.bindContext(this.context)

    // Caller access is enforced by extensionAbilities.permissions in module.json5.

    if (this.stub === null) {
      this.stub = new CustomAuthStub()
      LogUtils.info(TAG, 'CustomAuthStub created')
    }
    return this.stub
  }

  onDisconnect(want: Want): void {
    LogUtils.info(TAG, 'onDisconnect')
    this.stub?.dispose()
    this.stub = null
  }

  onDestroy(): void {
    LogUtils.info(TAG, 'onDestroy')
    this.stub?.dispose()
    this.stub = null
  }
}

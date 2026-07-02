import { common } from '@kit.AbilityKit'
import { AccountSnapshotChange } from './AccountSnapshotModels'

export interface AccountChangeHandler {
  name: string
  handle(context: common.Context, snapshot: AccountSnapshotChange): Promise<boolean>
}

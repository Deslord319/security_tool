import { UserFirewallOption } from '../firewall/FirewallModels'

export type AccountChangeSource = 'account-added' | 'account-removed' | 'manual'

export interface AccountSnapshotChange {
  source: AccountChangeSource
  triggerAccountId?: number
  users: UserFirewallOption[]
  currentUserIds: number[]
  addedUserIds: number[]
  removedUserIds: number[]
  signature: string
  previousSignature?: string
  message?: string
}

export function normalizeAccountUserIds(userIds: number[]): number[] {
  let normalizedIds = new Set<number>()
  userIds.forEach((userId: number) => {
    if (Number.isInteger(userId) && userId >= 0) {
      normalizedIds.add(userId)
    }
  })
  return Array.from(normalizedIds).sort((left: number, right: number): number => left - right)
}

export function buildAccountUserIdsSignature(userIds: number[]): string {
  return normalizeAccountUserIds(userIds).join(',')
}

import { AccountChangeCoordinator } from './AccountChangeCoordinator'
import { FIREWALL_ACCOUNT_CHANGE_HANDLER } from '../firewall/FirewallAccountChangeHandler'

let defaultHandlersRegistered = false

export function registerDefaultAccountChangeHandlers(): void {
  if (defaultHandlersRegistered) {
    return
  }
  AccountChangeCoordinator.registerHandler(FIREWALL_ACCOUNT_CHANGE_HANDLER)
  defaultHandlersRegistered = true
}

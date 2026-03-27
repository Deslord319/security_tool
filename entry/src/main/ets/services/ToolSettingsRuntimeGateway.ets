import { common } from '@kit.AbilityKit'
import { AuthAvailabilityResult, AuthService } from './AuthService'
import { SystemSettingsService } from './SystemSettingsService'
import { AuthMethod } from '../models/DataModels'

export interface ToolSettingsRuntimeGateway {
  checkAuthAvailability(authMethod: AuthMethod): AuthAvailabilityResult
  openPasswordSettings(context: common.UIAbilityContext): Promise<boolean>
}

export class DefaultToolSettingsRuntimeGateway implements ToolSettingsRuntimeGateway {
  checkAuthAvailability(authMethod: AuthMethod): AuthAvailabilityResult {
    return AuthService.checkAuthMethodAvailability(authMethod)
  }

  async openPasswordSettings(context: common.UIAbilityContext): Promise<boolean> {
    return SystemSettingsService.openPasswordSettings(context)
  }
}

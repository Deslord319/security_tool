import { common } from '@kit.AbilityKit'
import {
  LogStorageConfig,
  LogSubscriptionConfig
} from '../../../models/DataModels'
import { ServiceResult } from '../common/LogManagePorts'
import { LogSettingsRepository } from './LogSettingsRepository'

export class LogConfigRepository {
  static async init(context: common.UIAbilityContext): Promise<ServiceResult> {
    return LogSettingsRepository.init(context)
  }

  static async loadStorageConfig(): Promise<LogStorageConfig> {
    return LogSettingsRepository.loadStorageConfig()
  }

  static getStorageConfigSync(): LogStorageConfig {
    return LogSettingsRepository.getStorageConfigSync()
  }

  static async saveStorageConfig(config: LogStorageConfig): Promise<ServiceResult> {
    return LogSettingsRepository.saveStorageConfig(config)
  }

  static async loadSubscriptionConfig(): Promise<LogSubscriptionConfig> {
    return LogSettingsRepository.loadSubscriptionConfig()
  }
}

import { common } from '@kit.AbilityKit'
import { IdentityLockScreenAuthStrings } from '../../../constants/modules/IdentityStrings'
import {
  DEFAULT_LOCKSCREEN_AUTH_CONFIG,
  LockScreenAuthConfig
} from '../../../models/identity/lockscreen-auth/LockScreenAuthModels'
import {
  LockScreenAuthRepository,
  PreferencesLockScreenAuthRepository
} from '../../../services/identity/lockscreen-auth/LockScreenAuthRepository'
import {
  LockScreenCustomAuthEnrollmentService,
  LockScreenUKeyEnrollmentService
} from '../../../services/identity/lockscreen-auth/LockScreenCustomAuthEnrollmentService'
import { ActionDialogStatus, DialogActionKind } from '../../../utils/DialogService'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LockScreenAuth.ViewModel'

export interface LockScreenAuthActionRequest {
  kind: DialogActionKind
  status?: ActionDialogStatus
  message?: string
}

@ObservedV2
export class LockScreenAuthState {
  @Trace initialized: boolean = false
  @Trace loading: boolean = false
  @Trace saving: boolean = false
  @Trace enrolling: boolean = false
  @Trace ukeyUnlockEnabled: boolean = DEFAULT_LOCKSCREEN_AUTH_CONFIG.ukeyUnlockEnabled
  @Trace ukeyCredentialRegistered: boolean = false
  @Trace message: string = ''
}

@ObservedV2
export class LockScreenAuthViewModel {
  @Trace state: LockScreenAuthState = new LockScreenAuthState()
  private repository: LockScreenAuthRepository
  private enrollmentService: LockScreenUKeyEnrollmentService

  constructor(
    repository: LockScreenAuthRepository = new PreferencesLockScreenAuthRepository(),
    enrollmentService: LockScreenUKeyEnrollmentService = new LockScreenCustomAuthEnrollmentService()
  ) {
    this.repository = repository
    this.enrollmentService = enrollmentService
  }

  async initialize(context: common.Context): Promise<void> {
    if (this.state.initialized || this.state.loading) {
      return
    }
    this.state.loading = true
    try {
      let config = await this.repository.loadConfig(context)
      this.applyConfig(config)
      this.state.message = ''
      this.state.initialized = true
      if (config.ukeyUnlockEnabled) {
        await this.ensureUKeyCredentialRegistered(context, false)
      }
    } finally {
      this.state.loading = false
    }
  }

  async setUKeyUnlockEnabled(
    context: common.Context,
    enabled: boolean
  ): Promise<LockScreenAuthActionRequest> {
    if (this.state.saving) {
      LogUtils.warn(TAG, '[SAVE_SKIP] setUKeyUnlockEnabled | reason=saving')
      return { kind: 'none' }
    }
    if (enabled === this.state.ukeyUnlockEnabled) {
      return { kind: 'none' }
    }

    let previous = this.state.ukeyUnlockEnabled
    this.state.ukeyUnlockEnabled = enabled
    this.state.saving = true
    this.state.message = ''
    try {
      let saved = await this.repository.saveConfig(context, { ukeyUnlockEnabled: enabled })
      if (saved) {
        this.state.initialized = true
        if (enabled) {
          let enrollRequest = await this.ensureUKeyCredentialRegistered(context, true)
          if (enrollRequest.kind !== 'none') {
            return enrollRequest
          }
        }
        return { kind: 'none' }
      }
      this.state.ukeyUnlockEnabled = previous
      this.state.message = IdentityLockScreenAuthStrings.SAVE_FAILED
      return {
        kind: 'result',
        status: 'failure',
        message: IdentityLockScreenAuthStrings.SAVE_FAILED
      }
    } finally {
      this.state.saving = false
    }
  }

  private applyConfig(config: LockScreenAuthConfig): void {
    this.state.ukeyUnlockEnabled = config.ukeyUnlockEnabled
  }

  private async ensureUKeyCredentialRegistered(
    context: common.Context,
    userVisible: boolean
  ): Promise<LockScreenAuthActionRequest> {
    if (this.state.enrolling) {
      return { kind: 'none' }
    }
    this.state.enrolling = true
    try {
      let result = await this.enrollmentService.ensureFirstUKeyRegistered(context)
      this.state.ukeyCredentialRegistered = !!result.success && !!result.data
      if (result.success) {
        this.state.message = ''
        return { kind: 'none' }
      }
      let message = result.userMessage ?? result.errorMessage ?? IdentityLockScreenAuthStrings.UKEY_REGISTER_FAILED
      this.state.message = message
      if (!userVisible) {
        LogUtils.warn(TAG, `[ENROLL_FAIL] ensureUKeyCredentialRegistered | stage=${result.stage ?? 'unknown'}, message=${message}`)
        return { kind: 'none' }
      }
      return {
        kind: 'result',
        status: 'failure',
        message: message
      }
    } finally {
      this.state.enrolling = false
    }
  }
}

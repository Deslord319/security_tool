import { common } from '@kit.AbilityKit'
import { commonEventManager } from '@kit.BasicServicesKit'
import {
  PeripheralConnectionRecordConsumeResult,
  PeripheralConnectionRecordConsumer,
  PeripheralConnectionRecordProducerEvent
} from '../../peripheral/connection-record/peripheral_connection_record_producer_contract'
import {
  LockScreenAuthRepository,
  PreferencesLockScreenAuthRepository
} from './LockScreenAuthRepository'
import {
  LockScreenCustomAuthEnrollmentService,
  LockScreenUKeyEnrollmentService
} from './LockScreenCustomAuthEnrollmentService'
import { LogUtils } from '../../../utils/LogUtils'

const TAG = 'LockScreenUKey.RuntimeConsumer'

export class LockScreenUKeyRuntimeEnrollmentConsumer implements PeripheralConnectionRecordConsumer {
  private context: common.Context | null = null
  private enrollmentInFlight: boolean = false
  private readonly repository: LockScreenAuthRepository
  private readonly enrollmentService: LockScreenUKeyEnrollmentService

  constructor(
    repository: LockScreenAuthRepository = new PreferencesLockScreenAuthRepository(),
    enrollmentService: LockScreenUKeyEnrollmentService = new LockScreenCustomAuthEnrollmentService()
  ) {
    this.repository = repository
    this.enrollmentService = enrollmentService
  }

  bindContext(context: common.Context): void {
    this.context = context
  }

  canHandle(event: PeripheralConnectionRecordProducerEvent): boolean {
    return event.channel === 'usb' &&
      event.eventName === commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED
  }

  async consume(event: PeripheralConnectionRecordProducerEvent): Promise<PeripheralConnectionRecordConsumeResult> {
    if (!this.canHandle(event)) {
      return null
    }
    if (!this.context) {
      LogUtils.warn(TAG, '[ENROLL_SKIP] reason=context_missing')
      return null
    }
    if (this.enrollmentInFlight) {
      LogUtils.info(TAG, '[ENROLL_SKIP] reason=in_flight')
      return null
    }

    this.enrollmentInFlight = true
    try {
      let config = await this.repository.loadConfig(this.context)
      if (!config.ukeyUnlockEnabled) {
        LogUtils.info(TAG, '[ENROLL_SKIP] reason=disabled')
        return null
      }
      let result = await this.enrollmentService.ensureFirstUKeyRegistered(this.context)
      if (result.success) {
        LogUtils.info(TAG, `[ENROLL_DONE] stage=${result.stage ?? 'unknown'}, registered=${!!result.data}`)
      } else {
        LogUtils.warn(TAG, `[ENROLL_FAIL] stage=${result.stage ?? 'unknown'}, message=${result.errorMessage ?? '-'}`)
      }
    } finally {
      this.enrollmentInFlight = false
    }
    return null
  }
}

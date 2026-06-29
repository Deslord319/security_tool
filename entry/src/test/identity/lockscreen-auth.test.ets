import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { commonEventManager } from '@kit.BasicServicesKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { IdentityLockScreenAuthStrings } from '../../main/ets/constants/modules/IdentityStrings'
import { OperationResult } from '../../main/ets/models/CommonModels'
import {
  DEFAULT_LOCKSCREEN_AUTH_CONFIG,
  LockScreenAuthConfig,
  LockScreenUKeyBinding,
  LockScreenUKeyDevice,
  PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED
} from '../../main/ets/models/identity/lockscreen-auth/LockScreenAuthModels'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'
import {
  CustomAuthCredentialRegistrar,
  CustomAuthCredentialRegistrationResult,
  LockScreenCustomAuthEnrollmentService,
  LockScreenUKeyEnrollmentService
} from '../../main/ets/services/identity/lockscreen-auth/LockScreenCustomAuthEnrollmentService'
import {
  LockScreenAuthRepository,
  PreferencesLockScreenAuthRepository
} from '../../main/ets/services/identity/lockscreen-auth/LockScreenAuthRepository'
import {
  LockScreenUKeyBindingRepository
} from '../../main/ets/services/identity/lockscreen-auth/LockScreenUKeyBindingRepository'
import {
  LockScreenUKeyDeviceProvider
} from '../../main/ets/services/identity/lockscreen-auth/LockScreenUKeyDeviceService'
import { LockScreenUKeyRuntimeEnrollmentConsumer } from '../../main/ets/services/identity/lockscreen-auth/LockScreenUKeyRuntimeEnrollmentConsumer'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'
import { LockScreenAuthViewModel } from '../../main/ets/viewmodels/identity/lockscreen-auth/LockScreenAuthViewModel'

class FakePreferencesAccessor {
  private values: Map<string, Object> = new Map<string, Object>()
  setResult: boolean = true

  async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    let val = this.values.get(key)
    return val !== undefined ? val as boolean : defaultValue
  }

  async setValue(key: string, value: string | number | boolean, _flush?: boolean): Promise<boolean> {
    if (!this.setResult) {
      return false
    }
    this.values.set(key, value)
    return true
  }

  set(key: string, value: Object): void {
    this.values.set(key, value)
  }
}

class FakeLockScreenAuthRepository implements LockScreenAuthRepository {
  config: LockScreenAuthConfig = {
    ukeyUnlockEnabled: DEFAULT_LOCKSCREEN_AUTH_CONFIG.ukeyUnlockEnabled
  }
  saveResult: boolean = true

  async loadConfig(_context: common.Context): Promise<LockScreenAuthConfig> {
    return {
      ukeyUnlockEnabled: this.config.ukeyUnlockEnabled
    }
  }

  async saveConfig(_context: common.Context, config: LockScreenAuthConfig): Promise<boolean> {
    if (this.saveResult) {
      this.config = {
        ukeyUnlockEnabled: config.ukeyUnlockEnabled
      }
    }
    return this.saveResult
  }
}

class FakeEnrollmentService implements LockScreenUKeyEnrollmentService {
  callCount: number = 0
  result: OperationResult<LockScreenUKeyBinding | null> = {
    success: true,
    data: null,
    stage: 'already_bound'
  } as OperationResult<LockScreenUKeyBinding | null>

  async ensureFirstUKeyRegistered(_context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    this.callCount++
    return this.result
  }
}

class FakeBindingRepository implements LockScreenUKeyBindingRepository {
  binding: LockScreenUKeyBinding | null = null
  saveCount: number = 0

  async loadBinding(_context: common.Context): Promise<LockScreenUKeyBinding | null> {
    return this.binding
  }

  async saveBinding(_context: common.Context, binding: LockScreenUKeyBinding): Promise<boolean> {
    this.saveCount++
    this.binding = binding
    return true
  }
}

class FakeDeviceProvider implements LockScreenUKeyDeviceProvider {
  devices: LockScreenUKeyDevice[] = []

  getCandidateDevices(): OperationResult<LockScreenUKeyDevice[]> {
    return {
      success: true,
      data: this.devices
    } as OperationResult<LockScreenUKeyDevice[]>
  }
}

class FakeRegistrar implements CustomAuthCredentialRegistrar {
  callCount: number = 0
  result: CustomAuthCredentialRegistrationResult = {
    success: true,
    resultCode: 0,
    credentialIdHex: '010203'
  }

  async addCredential(_userId: number, _pluginInfo: string): Promise<CustomAuthCredentialRegistrationResult> {
    this.callCount++
    return this.result
  }
}

function createBinding(fingerprint: string = 'VID:1111 PID:2222|SN:FIRST'): LockScreenUKeyBinding {
  return {
    fingerprint: fingerprint,
    deviceId: 'VID:1111 PID:2222',
    deviceName: 'First UKey',
    userId: 100,
    credentialIdHex: '010203',
    pluginInfo: '{}',
    boundAt: 1,
    stableIdentifier: true
  }
}

function createDevice(fingerprint: string = 'VID:1111 PID:2222|SN:FIRST'): LockScreenUKeyDevice {
  return {
    fingerprint: fingerprint,
    deviceId: 'VID:1111 PID:2222',
    vendorId: 0x1111,
    productId: 0x2222,
    serial: 'FIRST',
    manufacturerName: 'Demo',
    productName: 'UKey',
    deviceName: 'Demo UKey',
    clazz: 0x08,
    subClass: 0,
    protocol: 0,
    stableIdentifier: true
  }
}

function createUsbAttachEvent(): PeripheralConnectionRecordProducerEvent {
  return {
    source: 'runtime',
    channel: 'usb',
    eventName: commonEventManager.Support.COMMON_EVENT_USB_DEVICE_ATTACHED
  } as PeripheralConnectionRecordProducerEvent
}

export default function lockScreenAuthTest() {
  describe('LockScreenAuthSettings', () => {
    let mockKit: MockKit
    let fakeAccessor: FakePreferencesAccessor
    let context: common.UIAbilityContext

    beforeEach(() => {
      mockKit = new MockKit()
      fakeAccessor = new FakePreferencesAccessor()
      context = {} as common.UIAbilityContext
    })

    afterEach(() => {
      mockKit.clearAll()
    })

    it('should default UKey lock screen authentication to enabled when preference is missing', 0, async (done: Function) => {
      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesLockScreenAuthRepository()
      let config = await repository.loadConfig(context)

      expect(config.ukeyUnlockEnabled).assertTrue()
      done()
    })

    it('should persist disabled UKey lock screen authentication config', 0, async (done: Function) => {
      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesLockScreenAuthRepository()
      let saved = await repository.saveConfig(context, { ukeyUnlockEnabled: false })
      let config = await repository.loadConfig(context)

      expect(saved).assertTrue()
      expect(config.ukeyUnlockEnabled).assertFalse()
      done()
    })

    it('should load disabled UKey lock screen authentication from existing preference', 0, async (done: Function) => {
      fakeAccessor.set(PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED, false)
      let ofMock = mockKit.mockFunc(PreferencesAccessor, PreferencesAccessor.of)
      when(ofMock)(ArgumentMatchers.any).afterReturn(fakeAccessor as never as PreferencesAccessor)

      let repository = new PreferencesLockScreenAuthRepository()
      let config = await repository.loadConfig(context)

      expect(config.ukeyUnlockEnabled).assertFalse()
      done()
    })

    it('should initialize ViewModel from repository', 0, async (done: Function) => {
      let repository = new FakeLockScreenAuthRepository()
      let enrollment = new FakeEnrollmentService()
      repository.config.ukeyUnlockEnabled = false
      let viewModel = new LockScreenAuthViewModel(repository, enrollment)

      await viewModel.initialize(context)

      expect(viewModel.state.initialized).assertTrue()
      expect(viewModel.state.ukeyUnlockEnabled).assertFalse()
      expect(enrollment.callCount).assertEqual(0)
      done()
    })

    it('should save ViewModel toggle immediately', 0, async (done: Function) => {
      let repository = new FakeLockScreenAuthRepository()
      let enrollment = new FakeEnrollmentService()
      let viewModel = new LockScreenAuthViewModel(repository, enrollment)
      await viewModel.initialize(context)

      let result = await viewModel.setUKeyUnlockEnabled(context, false)

      expect(result.kind).assertEqual('none')
      expect(viewModel.state.ukeyUnlockEnabled).assertFalse()
      expect(repository.config.ukeyUnlockEnabled).assertFalse()
      done()
    })

    it('should rollback ViewModel toggle when save fails', 0, async (done: Function) => {
      let repository = new FakeLockScreenAuthRepository()
      repository.saveResult = false
      let viewModel = new LockScreenAuthViewModel(repository, new FakeEnrollmentService())
      await viewModel.initialize(context)

      let result = await viewModel.setUKeyUnlockEnabled(context, false)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('failure')
      expect(result.message).assertEqual(IdentityLockScreenAuthStrings.SAVE_FAILED)
      expect(viewModel.state.ukeyUnlockEnabled).assertTrue()
      done()
    })

    it('should auto enroll first UKey when initialized with enabled config', 0, async (done: Function) => {
      let repository = new FakeLockScreenAuthRepository()
      let enrollment = new FakeEnrollmentService()
      enrollment.result = {
        success: true,
        data: createBinding(),
        stage: 'completed'
      } as OperationResult<LockScreenUKeyBinding | null>
      let viewModel = new LockScreenAuthViewModel(repository, enrollment)

      await viewModel.initialize(context)

      expect(enrollment.callCount).assertEqual(1)
      expect(viewModel.state.ukeyCredentialRegistered).assertTrue()
      done()
    })

    it('should report register failure when enabling without a usable first UKey', 0, async (done: Function) => {
      let repository = new FakeLockScreenAuthRepository()
      repository.config.ukeyUnlockEnabled = false
      let enrollment = new FakeEnrollmentService()
      enrollment.result = {
        success: false,
        data: null,
        userMessage: IdentityLockScreenAuthStrings.UKEY_REGISTER_FAILED,
        stage: 'no_ukey'
      } as OperationResult<LockScreenUKeyBinding | null>
      let viewModel = new LockScreenAuthViewModel(repository, enrollment)
      await viewModel.initialize(context)

      let result = await viewModel.setUKeyUnlockEnabled(context, true)

      expect(result.kind).assertEqual('result')
      expect(result.status).assertEqual('failure')
      expect(enrollment.callCount).assertEqual(1)
      expect(viewModel.state.ukeyUnlockEnabled).assertTrue()
      expect(viewModel.state.ukeyCredentialRegistered).assertFalse()
      done()
    })

    it('should register and persist binding when exactly one first UKey is present', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      let deviceProvider = new FakeDeviceProvider()
      let registrar = new FakeRegistrar()
      deviceProvider.devices = [createDevice()]
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar)

      let result = await service.ensureFirstUKeyRegistered(context)

      expect(result.success).assertTrue()
      expect(registrar.callCount).assertEqual(1)
      expect(bindingRepository.saveCount).assertEqual(1)
      expect(bindingRepository.binding?.credentialIdHex).assertEqual('010203')
      done()
    })

    it('should not register another UKey when a first binding already exists', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      bindingRepository.binding = createBinding('VID:1111 PID:2222|SN:FIRST')
      let deviceProvider = new FakeDeviceProvider()
      deviceProvider.devices = [createDevice('VID:3333 PID:4444|SN:SECOND')]
      let registrar = new FakeRegistrar()
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar)

      let result = await service.ensureFirstUKeyRegistered(context)

      expect(result.success).assertTrue()
      expect(result.data?.fingerprint).assertEqual('VID:1111 PID:2222|SN:FIRST')
      expect(registrar.callCount).assertEqual(0)
      expect(bindingRepository.saveCount).assertEqual(0)
      done()
    })

    it('should reject enrollment when zero or multiple UKeys are present', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      let deviceProvider = new FakeDeviceProvider()
      let registrar = new FakeRegistrar()
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar)

      let noDeviceResult = await service.ensureFirstUKeyRegistered(context)
      deviceProvider.devices = [createDevice('A'), createDevice('B')]
      let multiDeviceResult = await service.ensureFirstUKeyRegistered(context)

      expect(noDeviceResult.success).assertFalse()
      expect(multiDeviceResult.success).assertFalse()
      expect(registrar.callCount).assertEqual(0)
      expect(bindingRepository.saveCount).assertEqual(0)
      done()
    })

    it('should enroll from USB attach runtime event when switch is enabled', 0, async (done: Function) => {
      let repository = new FakeLockScreenAuthRepository()
      let enrollment = new FakeEnrollmentService()
      enrollment.result = {
        success: true,
        data: createBinding(),
        stage: 'completed'
      } as OperationResult<LockScreenUKeyBinding | null>
      let consumer = new LockScreenUKeyRuntimeEnrollmentConsumer(repository, enrollment)
      consumer.bindContext(context)

      let record = await consumer.consume(createUsbAttachEvent())

      expect(record === null).assertTrue()
      expect(enrollment.callCount).assertEqual(1)
      done()
    })

    it('should skip USB attach runtime enrollment when switch is disabled', 0, async (done: Function) => {
      let repository = new FakeLockScreenAuthRepository()
      repository.config.ukeyUnlockEnabled = false
      let enrollment = new FakeEnrollmentService()
      let consumer = new LockScreenUKeyRuntimeEnrollmentConsumer(repository, enrollment)
      consumer.bindContext(context)

      await consumer.consume(createUsbAttachEvent())

      expect(enrollment.callCount).assertEqual(0)
      done()
    })
  })
}

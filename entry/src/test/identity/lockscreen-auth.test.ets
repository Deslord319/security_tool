import { afterEach, beforeEach, describe, expect, it } from '@ohos/hypium'
import { common } from '@kit.AbilityKit'
import { commonEventManager, usbManager } from '@kit.BasicServicesKit'
import { ArgumentMatchers, MockKit, when } from '@ohos/hamock'
import { IdentityLockScreenAuthStrings } from '../../main/ets/constants/modules/IdentityStrings'
import { OperationResult } from '../../main/ets/models/CommonModels'
import {
  DEFAULT_LOCKSCREEN_AUTH_CONFIG,
  LockScreenAuthConfig,
  LockScreenUKeyActiveCredential,
  LockScreenUKeyBinding,
  LockScreenUKeyDevice,
  PREF_KEY_LOCKSCREEN_UKEY_AUTH_ENABLED
} from '../../main/ets/models/identity/lockscreen-auth/LockScreenAuthModels'
import { PreferencesAccessor } from '../../main/ets/storage/preferences/PreferencesAccessor'
import {
  CustomAuthCredentialDeletionResult,
  CustomAuthCredentialManager,
  CustomAuthCredentialRegistrationResult,
  LockScreenCustomAuthEnrollmentService,
  LockScreenUKeyEnrollmentService
} from '../../main/ets/services/identity/lockscreen-auth/LockScreenCustomAuthEnrollmentService'
import {
  LockScreenAuthRepository,
  PreferencesLockScreenAuthRepository
} from '../../main/ets/services/identity/lockscreen-auth/LockScreenAuthRepository'
import {
  LockScreenUKeyActiveCredentialRepository,
  LockScreenUKeyBindingRepository
} from '../../main/ets/services/identity/lockscreen-auth/LockScreenUKeyBindingRepository'
import {
  DdkLockScreenUKeyDeviceService,
  DdkUsbDeviceInfo,
  DdkUsbDeviceQuery,
  LockScreenUKeyDeviceProvider,
  UsbDeviceDetailProbe
} from '../../main/ets/services/identity/lockscreen-auth/LockScreenUKeyDeviceService'
import { LockScreenUKeyRuntimeEnrollmentConsumer } from '../../main/ets/services/identity/lockscreen-auth/LockScreenUKeyRuntimeEnrollmentConsumer'
import {
  AuthenticatorUKeyTemplateBindingRepository,
  SecurityToolAuthenticatorUKeyProvider
} from '../../main/ets/services/identity/custom-auth-core/ukey/AuthenticatorUKeyProvider'
import { PeripheralConnectionRecordProducerEvent } from '../../main/ets/services/peripheral/connection-record/peripheral_connection_record_producer_contract'
import { LockScreenAuthViewModel } from '../../main/ets/viewmodels/identity/lockscreen-auth/LockScreenAuthViewModel'

class FakePreferencesAccessor {
  private values: Map<string, Object> = new Map<string, Object>()
  setResult: boolean = true

  async getBoolean(key: string, defaultValue: boolean): Promise<boolean> {
    let val = this.values.get(key)
    return val !== undefined ? val as boolean : defaultValue
  }

  async getString(key: string, defaultValue: string): Promise<string> {
    let val = this.values.get(key)
    return typeof val === 'string' ? val : defaultValue
  }

  async getJsonObject<T>(key: string, defaultValue: T): Promise<T> {
    let raw = await this.getString(key, '')
    if (raw.length === 0) {
      return defaultValue
    }
    return JSON.parse(raw) as T
  }

  async setValue(key: string, value: string | number | boolean, _flush?: boolean): Promise<boolean> {
    if (!this.setResult) {
      return false
    }
    this.values.set(key, value)
    return true
  }

  async setJson(key: string, value: object, _flush?: boolean): Promise<boolean> {
    if (!this.setResult) {
      return false
    }
    this.values.set(key, JSON.stringify(value))
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
  reconcileCallCount: number = 0
  result: OperationResult<LockScreenUKeyBinding | null> = {
    success: true,
    data: null,
    stage: 'already_bound'
  } as OperationResult<LockScreenUKeyBinding | null>

  async ensureFirstUKeyRegistered(_context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    this.callCount++
    return this.result
  }

  async onUKeyAttached(context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    return await this.ensureFirstUKeyRegistered(context)
  }

  async onUKeyDetached(_context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    this.callCount++
    return this.result
  }

  async reconcileOnStartup(_context: common.Context): Promise<OperationResult<LockScreenUKeyBinding | null>> {
    this.reconcileCallCount++
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

class FakeActiveCredentialRepository implements LockScreenUKeyActiveCredentialRepository {
  activeCredential: LockScreenUKeyActiveCredential | null = null
  saveCount: number = 0
  clearCount: number = 0

  async loadActiveCredential(_context: common.Context): Promise<LockScreenUKeyActiveCredential | null> {
    return this.activeCredential
  }

  async saveActiveCredential(_context: common.Context, credential: LockScreenUKeyActiveCredential): Promise<boolean> {
    this.saveCount++
    this.activeCredential = credential
    return true
  }

  async clearActiveCredential(_context: common.Context): Promise<boolean> {
    this.clearCount++
    this.activeCredential = null
    return true
  }
}

class FakeTemplateBindingRepository implements AuthenticatorUKeyTemplateBindingRepository {
  bindings: Record<string, string> = {}
  saveCount: number = 0

  async loadTemplateBindings(_context: common.Context): Promise<Record<string, string>> {
    return this.bindings
  }

  async saveTemplateBindings(_context: common.Context, bindings: Record<string, string>): Promise<boolean> {
    this.saveCount++
    this.bindings = bindings
    return true
  }
}

class FakeDeviceProvider implements LockScreenUKeyDeviceProvider {
  devices: LockScreenUKeyDevice[] = []
  result: OperationResult<LockScreenUKeyDevice[]> | null = null

  getCandidateDevices(): OperationResult<LockScreenUKeyDevice[]> {
    if (this.result) {
      return this.result
    }
    return {
      success: true,
      data: this.devices
    } as OperationResult<LockScreenUKeyDevice[]>
  }
}

class FakeDdkUsbDeviceQuery implements DdkUsbDeviceQuery {
  devices: DdkUsbDeviceInfo[] = []
  shouldThrow: boolean = false

  queryUsbDevices(): OperationResult<DdkUsbDeviceInfo[]> {
    if (this.shouldThrow) {
      return {
        success: false,
        errorCode: -1,
        errorMessage: 'ddk unavailable',
        stage: 'query_ddk_devices'
      } as OperationResult<DdkUsbDeviceInfo[]>
    }
    return {
      success: true,
      data: this.devices
    } as OperationResult<DdkUsbDeviceInfo[]>
  }
}

class FakeUsbDeviceDetailProbe implements UsbDeviceDetailProbe {
  devices: usbManager.USBDevice[] = []

  getUsbDevices(): OperationResult<usbManager.USBDevice[]> {
    return {
      success: true,
      data: this.devices
    } as OperationResult<usbManager.USBDevice[]>
  }
}

class FakeRegistrar implements CustomAuthCredentialManager {
  callCount: number = 0
  deleteCallCount: number = 0
  result: CustomAuthCredentialRegistrationResult = {
    success: true,
    resultCode: 0,
    credentialIdHex: '010203'
  }
  deleteResult: CustomAuthCredentialDeletionResult = {
    success: true,
    resultCode: 0
  }

  async addCredential(_userId: number, _pluginInfo: string): Promise<CustomAuthCredentialRegistrationResult> {
    this.callCount++
    return this.result
  }

  async deleteCredential(_userId: number, credentialIdHex: string): Promise<CustomAuthCredentialDeletionResult> {
    this.deleteCallCount++
    return {
      success: this.deleteResult.success,
      resultCode: this.deleteResult.resultCode,
      credentialIdHex: credentialIdHex
    }
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

function createUsbDetachEvent(): PeripheralConnectionRecordProducerEvent {
  return {
    source: 'runtime',
    channel: 'usb',
    eventName: commonEventManager.Support.COMMON_EVENT_USB_DEVICE_DETACHED
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
      let activeRepository = new FakeActiveCredentialRepository()
      let deviceProvider = new FakeDeviceProvider()
      let registrar = new FakeRegistrar()
      deviceProvider.devices = [createDevice()]
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar, activeRepository)

      let result = await service.ensureFirstUKeyRegistered(context)

      expect(result.success).assertTrue()
      expect(registrar.callCount).assertEqual(1)
      expect(bindingRepository.saveCount).assertEqual(1)
      expect(activeRepository.saveCount).assertEqual(1)
      expect(bindingRepository.binding?.credentialIdHex).assertEqual('010203')
      expect(activeRepository.activeCredential?.credentialIdHex).assertEqual('010203')
      done()
    })

    it('should build UKey candidates from DDK USB device query', 0, async (done: Function) => {
      let ddkQuery = new FakeDdkUsbDeviceQuery()
      ddkQuery.devices = [{
        ddkDeviceId: 7,
        vendorId: 0x1111,
        productId: 0x2222,
        description: 'DDK UKey'
      }]
      let detailProbe = new FakeUsbDeviceDetailProbe()
      detailProbe.devices = [{
        vendorId: 0x1111,
        productId: 0x2222,
        serial: 'FIRST',
        manufacturerName: 'Acme',
        productName: 'Token',
        name: 'usb-token',
        clazz: 0x08,
        subClass: 0x06,
        protocol: 0x50
      } as usbManager.USBDevice]
      let service = new DdkLockScreenUKeyDeviceService(ddkQuery, detailProbe)

      let result = service.getCandidateDevices()

      expect(result.success).assertTrue()
      expect(result.data?.length).assertEqual(1)
      expect(result.data?.[0].fingerprint).assertEqual('VID:1111 PID:2222|SN:FIRST')
      expect(result.data?.[0].clazz).assertEqual(0x08)
      expect(result.data?.[0].stableIdentifier).assertTrue()
      done()
    })

    it('should fallback to DDK description and device id when serial is absent', 0, async (done: Function) => {
      let ddkQuery = new FakeDdkUsbDeviceQuery()
      ddkQuery.devices = [{
        ddkDeviceId: 7,
        vendorId: 0x055c,
        productId: 0xe618,
        description: 'Longmai Technologies Longmai-GM3000'
      }]
      let detailProbe = new FakeUsbDeviceDetailProbe()
      detailProbe.devices = [{
        vendorId: 0x055c,
        productId: 0xe618,
        serial: '',
        manufacturerName: 'Longmai Technologies',
        productName: 'Longmai-GM3000',
        name: 'hidraw2',
        clazz: 0x03,
        subClass: 0x00,
        protocol: 0x00
      } as usbManager.USBDevice]
      let service = new DdkLockScreenUKeyDeviceService(ddkQuery, detailProbe)

      let result = service.getCandidateDevices()

      expect(result.success).assertTrue()
      expect(result.data?.length).assertEqual(1)
      expect(result.data?.[0].fingerprint)
        .assertEqual(
          'VID:055C PID:E618|WEAK:LONGMAI TECHNOLOGIES LONGMAI-GM3000|LONGMAI TECHNOLOGIES LONGMAI-GM3000|DDK:7'
        )
      expect(result.data?.[0].stableIdentifier).assertFalse()
      done()
    })

    it('should return query_ddk_devices when DDK USB query fails', 0, async (done: Function) => {
      let ddkQuery = new FakeDdkUsbDeviceQuery()
      ddkQuery.shouldThrow = true
      let service = new DdkLockScreenUKeyDeviceService(ddkQuery, new FakeUsbDeviceDetailProbe())

      let result = service.getCandidateDevices()

      expect(result.success).assertFalse()
      expect(result.stage).assertEqual('query_ddk_devices')
      done()
    })

    it('should re-add active credential for the trusted first UKey when active credential is missing', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      bindingRepository.binding = createBinding('VID:1111 PID:2222|SN:FIRST')
      bindingRepository.binding.credentialIdHex = ''
      let activeRepository = new FakeActiveCredentialRepository()
      let deviceProvider = new FakeDeviceProvider()
      deviceProvider.devices = [createDevice('VID:1111 PID:2222|SN:FIRST')]
      let registrar = new FakeRegistrar()
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar, activeRepository)

      let result = await service.onUKeyAttached(context)

      expect(result.success).assertTrue()
      expect(registrar.callCount).assertEqual(1)
      expect(activeRepository.saveCount).assertEqual(1)
      expect(activeRepository.activeCredential?.fingerprint).assertEqual('VID:1111 PID:2222|SN:FIRST')
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

    it('should delete active credential when trusted first UKey is detached', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      bindingRepository.binding = createBinding('VID:1111 PID:2222|SN:FIRST')
      let activeRepository = new FakeActiveCredentialRepository()
      activeRepository.activeCredential = {
        credentialIdHex: '010203',
        userId: 100,
        pluginInfo: '{}',
        fingerprint: 'VID:1111 PID:2222|SN:FIRST',
        deviceId: 'VID:1111 PID:2222',
        deviceName: 'First UKey',
        createdAt: 1,
        lifecycle: 'active'
      }
      let deviceProvider = new FakeDeviceProvider()
      deviceProvider.devices = []
      let registrar = new FakeRegistrar()
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar, activeRepository)

      let result = await service.onUKeyDetached(context)

      expect(result.success).assertTrue()
      expect(result.stage).assertEqual('credential_deleted')
      expect(registrar.deleteCallCount).assertEqual(1)
      expect(activeRepository.clearCount).assertEqual(1)
      expect(bindingRepository.binding?.fingerprint).assertEqual('VID:1111 PID:2222|SN:FIRST')
      done()
    })

    it('should keep failed active credential when delete credential fails', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      bindingRepository.binding = createBinding('VID:1111 PID:2222|SN:FIRST')
      let activeRepository = new FakeActiveCredentialRepository()
      activeRepository.activeCredential = {
        credentialIdHex: '010203',
        userId: 100,
        pluginInfo: '{}',
        fingerprint: 'VID:1111 PID:2222|SN:FIRST',
        deviceId: 'VID:1111 PID:2222',
        deviceName: 'First UKey',
        createdAt: 1,
        lifecycle: 'active'
      }
      let deviceProvider = new FakeDeviceProvider()
      deviceProvider.devices = []
      let registrar = new FakeRegistrar()
      registrar.deleteResult = {
        success: false,
        resultCode: 123
      }
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar, activeRepository)

      let result = await service.onUKeyDetached(context)

      expect(result.success).assertFalse()
      expect(result.stage).assertEqual('delete_credential')
      expect(registrar.deleteCallCount).assertEqual(1)
      expect(activeRepository.clearCount).assertEqual(0)
      expect(activeRepository.activeCredential?.lifecycle).assertEqual('failed')
      expect(bindingRepository.binding?.fingerprint).assertEqual('VID:1111 PID:2222|SN:FIRST')
      done()
    })

    it('should not delete active credential when trusted first UKey is still present', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      bindingRepository.binding = createBinding('VID:1111 PID:2222|SN:FIRST')
      let activeRepository = new FakeActiveCredentialRepository()
      activeRepository.activeCredential = {
        credentialIdHex: '010203',
        userId: 100,
        pluginInfo: '{}',
        fingerprint: 'VID:1111 PID:2222|SN:FIRST',
        deviceId: 'VID:1111 PID:2222',
        deviceName: 'First UKey',
        createdAt: 1,
        lifecycle: 'active'
      }
      let deviceProvider = new FakeDeviceProvider()
      deviceProvider.devices = [createDevice('VID:1111 PID:2222|SN:FIRST')]
      let registrar = new FakeRegistrar()
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar, activeRepository)

      let result = await service.onUKeyDetached(context)

      expect(result.success).assertTrue()
      expect(result.stage).assertEqual('bound_device_present')
      expect(registrar.deleteCallCount).assertEqual(0)
      expect(activeRepository.clearCount).assertEqual(0)
      done()
    })

    it('should reconcile startup by re-adding credential when trusted UKey is present and inactive', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      bindingRepository.binding = createBinding('VID:1111 PID:2222|SN:FIRST')
      bindingRepository.binding.credentialIdHex = ''
      let activeRepository = new FakeActiveCredentialRepository()
      let deviceProvider = new FakeDeviceProvider()
      deviceProvider.devices = [createDevice('VID:1111 PID:2222|SN:FIRST')]
      let registrar = new FakeRegistrar()
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar, activeRepository)

      let result = await service.reconcileOnStartup(context)

      expect(result.success).assertTrue()
      expect(registrar.callCount).assertEqual(1)
      expect(registrar.deleteCallCount).assertEqual(0)
      expect(activeRepository.saveCount).assertEqual(1)
      expect(activeRepository.activeCredential?.credentialIdHex).assertEqual('010203')
      done()
    })

    it('should reconcile startup by deleting stale active credential when trusted UKey is absent', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      bindingRepository.binding = createBinding('VID:1111 PID:2222|SN:FIRST')
      let activeRepository = new FakeActiveCredentialRepository()
      activeRepository.activeCredential = {
        credentialIdHex: '010203',
        userId: 100,
        pluginInfo: '{}',
        fingerprint: 'VID:1111 PID:2222|SN:FIRST',
        deviceId: 'VID:1111 PID:2222',
        deviceName: 'First UKey',
        createdAt: 1,
        lifecycle: 'active'
      }
      let deviceProvider = new FakeDeviceProvider()
      deviceProvider.devices = []
      let registrar = new FakeRegistrar()
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar, activeRepository)

      let result = await service.reconcileOnStartup(context)

      expect(result.success).assertTrue()
      expect(result.stage).assertEqual('credential_deleted')
      expect(registrar.callCount).assertEqual(0)
      expect(registrar.deleteCallCount).assertEqual(1)
      expect(activeRepository.clearCount).assertEqual(1)
      expect(bindingRepository.binding?.fingerprint).assertEqual('VID:1111 PID:2222|SN:FIRST')
      done()
    })

    it('should not change binding or credential when startup DDK reconciliation fails', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      bindingRepository.binding = createBinding('VID:1111 PID:2222|SN:FIRST')
      let activeRepository = new FakeActiveCredentialRepository()
      activeRepository.activeCredential = {
        credentialIdHex: '010203',
        userId: 100,
        pluginInfo: '{}',
        fingerprint: 'VID:1111 PID:2222|SN:FIRST',
        deviceId: 'VID:1111 PID:2222',
        deviceName: 'First UKey',
        createdAt: 1,
        lifecycle: 'active'
      }
      let deviceProvider = new FakeDeviceProvider()
      deviceProvider.result = {
        success: false,
        errorMessage: 'ddk unavailable',
        stage: 'query_ddk_devices'
      } as OperationResult<LockScreenUKeyDevice[]>
      let registrar = new FakeRegistrar()
      let service = new LockScreenCustomAuthEnrollmentService(bindingRepository, deviceProvider, registrar, activeRepository)

      let result = await service.reconcileOnStartup(context)

      expect(result.success).assertFalse()
      expect(result.stage).assertEqual('query_ddk_devices')
      expect(registrar.callCount).assertEqual(0)
      expect(registrar.deleteCallCount).assertEqual(0)
      expect(activeRepository.clearCount).assertEqual(0)
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

    it('should bind CustomAuth template to the enrolled first UKey', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      let deviceProvider = new FakeDeviceProvider()
      let templateRepository = new FakeTemplateBindingRepository()
      deviceProvider.devices = [createDevice('VID:1111 PID:2222|SN:FIRST')]
      let provider = new SecurityToolAuthenticatorUKeyProvider(deviceProvider, bindingRepository, templateRepository)
      provider.bindContext(context)

      await provider.onEnrolled('1001')

      expect(templateRepository.bindings['1001']).assertEqual('VID:1111 PID:2222|SN:FIRST')
      expect(templateRepository.saveCount).assertEqual(1)
      done()
    })

    it('should return template id only when the trusted first UKey is present', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      bindingRepository.binding = createBinding('VID:1111 PID:2222|SN:FIRST')
      let deviceProvider = new FakeDeviceProvider()
      deviceProvider.devices = [createDevice('VID:1111 PID:2222|SN:FIRST')]
      let templateRepository = new FakeTemplateBindingRepository()
      templateRepository.bindings = {
        '1001': 'VID:1111 PID:2222|SN:FIRST'
      }
      let provider = new SecurityToolAuthenticatorUKeyProvider(deviceProvider, bindingRepository, templateRepository)
      provider.bindContext(context)

      let matched = await provider.getPresentTemplateId(['1001', '1002'])

      expect(matched).assertEqual('1001')
      done()
    })

    it('should not fallback to another template when a second UKey is present', 0, async (done: Function) => {
      let bindingRepository = new FakeBindingRepository()
      bindingRepository.binding = createBinding('VID:1111 PID:2222|SN:FIRST')
      let deviceProvider = new FakeDeviceProvider()
      deviceProvider.devices = [createDevice('VID:3333 PID:4444|SN:SECOND')]
      let templateRepository = new FakeTemplateBindingRepository()
      templateRepository.bindings = {
        '1001': 'VID:1111 PID:2222|SN:FIRST',
        '1002': 'VID:3333 PID:4444|SN:SECOND'
      }
      let provider = new SecurityToolAuthenticatorUKeyProvider(deviceProvider, bindingRepository, templateRepository)
      provider.bindContext(context)

      let matched = await provider.getPresentTemplateId(['1001', '1002'])

      expect(matched === null).assertTrue()
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

    it('should handle USB detach runtime event when switch is enabled', 0, async (done: Function) => {
      let repository = new FakeLockScreenAuthRepository()
      let enrollment = new FakeEnrollmentService()
      enrollment.result = {
        success: true,
        data: createBinding(),
        stage: 'credential_deleted'
      } as OperationResult<LockScreenUKeyBinding | null>
      let consumer = new LockScreenUKeyRuntimeEnrollmentConsumer(repository, enrollment)
      consumer.bindContext(context)

      let record = await consumer.consume(createUsbDetachEvent())

      expect(record === null).assertTrue()
      expect(enrollment.callCount).assertEqual(1)
      done()
    })

    it('should reconcile startup from runtime consumer when switch is enabled', 0, async (done: Function) => {
      let repository = new FakeLockScreenAuthRepository()
      let enrollment = new FakeEnrollmentService()
      enrollment.result = {
        success: true,
        data: createBinding(),
        stage: 'completed'
      } as OperationResult<LockScreenUKeyBinding | null>
      let consumer = new LockScreenUKeyRuntimeEnrollmentConsumer(repository, enrollment)
      consumer.bindContext(context)

      await consumer.reconcileOnStartup()

      expect(enrollment.reconcileCallCount).assertEqual(1)
      expect(enrollment.callCount).assertEqual(0)
      done()
    })

    it('should skip startup reconciliation when switch is disabled', 0, async (done: Function) => {
      let repository = new FakeLockScreenAuthRepository()
      repository.config.ukeyUnlockEnabled = false
      let enrollment = new FakeEnrollmentService()
      let consumer = new LockScreenUKeyRuntimeEnrollmentConsumer(repository, enrollment)
      consumer.bindContext(context)

      await consumer.reconcileOnStartup()

      expect(enrollment.reconcileCallCount).assertEqual(0)
      done()
    })
  })
}

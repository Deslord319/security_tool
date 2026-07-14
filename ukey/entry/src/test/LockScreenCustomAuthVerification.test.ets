import { common } from '@kit.AbilityKit'
import { describe, expect, it } from '@ohos/hypium'
import { OperationResult } from '../main/ets/models/CommonModels'
import {
  LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO,
  LockScreenUKeyActiveCredential,
  LockScreenUKeyBinding,
  LockScreenUKeyDevice
} from '../main/ets/models/identity/lockscreen-auth/LockScreenAuthModels'
import {
  AuthenticatorUKeyPasscodeVerification
} from '../main/ets/services/identity/custom-auth-core/ukey/AuthenticatorUKeyProvider'
import {
  buildCustomAuthVerificationFailureMessage,
  CustomAuthCredentialListResult,
  CustomAuthCredentialManager,
  CustomAuthCredentialVerificationResult,
  CustomAuthCredentialVerificationSummary,
  CustomAuthCredentialVerifier,
  CustomAuthCredentialRegistrationResult,
  CustomAuthCredentialDeletionResult,
  describeCustomAuthVerificationFailure,
  describeUKeyPasscodePrecheckFailure,
  LockScreenCustomAuthEnrollmentService,
  UKeyPasscodeVerificationProvider,
  UKeyUserProvider
} from '../main/ets/services/identity/lockscreen-auth/LockScreenCustomAuthEnrollmentService'
import {
  LockScreenUKeyActiveCredentialRepository,
  LockScreenUKeyBindingRepository
} from '../main/ets/services/identity/lockscreen-auth/LockScreenUKeyBindingRepository'
import {
  LockScreenUKeyDeviceProvider
} from '../main/ets/services/identity/lockscreen-auth/LockScreenUKeyDeviceService'

class FakeBindingRepository implements LockScreenUKeyBindingRepository {
  async loadBinding(_context: common.Context): Promise<LockScreenUKeyBinding | null> {
    return null
  }

  async saveBinding(_context: common.Context, _binding: LockScreenUKeyBinding): Promise<boolean> {
    return true
  }
}

class FakeActiveCredentialRepository implements LockScreenUKeyActiveCredentialRepository {
  private readonly credential: LockScreenUKeyActiveCredential

  constructor(credential: LockScreenUKeyActiveCredential) {
    this.credential = credential
  }

  async loadActiveCredential(_context: common.Context): Promise<LockScreenUKeyActiveCredential | null> {
    return this.credential
  }

  async saveActiveCredential(
    _context: common.Context,
    _credential: LockScreenUKeyActiveCredential
  ): Promise<boolean> {
    return true
  }

  async clearActiveCredential(_context: common.Context): Promise<boolean> {
    return true
  }
}

class FakeDeviceProvider implements LockScreenUKeyDeviceProvider {
  getCandidateDevices(): OperationResult<LockScreenUKeyDevice[]> {
    return { success: true, data: [] }
  }
}

class FakeCredentialManager implements CustomAuthCredentialManager {
  async addCredential(
    _userId: number,
    _pluginInfo: string,
    _systemPin: string
  ): Promise<CustomAuthCredentialRegistrationResult> {
    return { success: false }
  }

  async deleteCredential(
    _userId: number,
    _credentialIdHex: string,
    _systemPin: string
  ): Promise<CustomAuthCredentialDeletionResult> {
    return { success: false }
  }

  async listCustomAuthCredentialIds(userId: number): Promise<CustomAuthCredentialListResult> {
    return { success: true, userId: userId, credentials: [] }
  }
}

class FakeUserProvider implements UKeyUserProvider {
  async loadAvailableUserIds(): Promise<OperationResult<number[]>> {
    return { success: true, data: [] }
  }
}

class CountingCredentialVerifier implements CustomAuthCredentialVerifier {
  calls: number = 0

  async verifyCredential(
    userId: number,
    credentialIdHex: string,
    _challenge: Uint8Array,
    _ukeyPassword: string
  ): Promise<CustomAuthCredentialVerificationResult> {
    this.calls += 1
    return {
      success: true,
      userId: userId,
      credentialIdHex: credentialIdHex,
      challengeHex: '01',
      resultCode: 0
    }
  }
}

class FakePasscodeVerifier implements UKeyPasscodeVerificationProvider {
  verifyCalls: number = 0
  private readonly result: AuthenticatorUKeyPasscodeVerification

  constructor(result: AuthenticatorUKeyPasscodeVerification) {
    this.result = result
  }

  bindContext(_context: common.Context): void {
  }

  async isFingerprintLocked(_context: common.Context, _fingerprint: string): Promise<boolean> {
    return this.result.locked
  }

  async verifyPasscodeForFingerprint(
    _context: common.Context,
    _fingerprint: string,
    _passcode: string
  ): Promise<AuthenticatorUKeyPasscodeVerification> {
    this.verifyCalls += 1
    return this.result
  }
}

function activeCredential(): LockScreenUKeyActiveCredential {
  return {
    fingerprint: 'SN:FIRST',
    deviceId: 'VID:1234 PID:5678',
    deviceName: 'Secure UKey',
    createdAt: 1,
    lifecycle: 'active',
    userCredentials: [
      {
        userId: 100,
        credentialIdHex: '01',
        templateId: '1',
        pluginInfo: LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO,
        lifecycle: 'active',
        createdAt: 1
      },
      {
        userId: 101,
        credentialIdHex: '02',
        templateId: '2',
        pluginInfo: LOCKSCREEN_CUSTOM_AUTH_PLUGIN_INFO,
        lifecycle: 'active',
        createdAt: 1
      }
    ]
  }
}

export default function lockScreenCustomAuthVerificationTest(): void {
  describe('LockScreenCustomAuthVerification', () => {
    it('maps_standard_result_codes_to_clear_messages', 0, () => {
      let locked: CustomAuthCredentialVerificationResult = {
        success: false,
        userId: 100,
        credentialIdHex: '01',
        challengeHex: '01',
        resultCode: 9
      }
      let notEnrolled: CustomAuthCredentialVerificationResult = {
        success: false,
        userId: 101,
        credentialIdHex: '02',
        challengeHex: '01',
        resultCode: 10
      }
      expect(describeCustomAuthVerificationFailure(locked)).assertEqual('UKey 密码已锁定')
      expect(describeCustomAuthVerificationFailure(notEnrolled)).assertEqual('系统未找到对应的 UKEY解锁凭据')
      expect(describeCustomAuthVerificationFailure({
        success: false,
        userId: 102,
        credentialIdHex: '03',
        challengeHex: '01',
        resultCode: 4
      })).assertEqual('认证超时，请重新尝试')
      expect(describeCustomAuthVerificationFailure({
        success: false,
        userId: 103,
        credentialIdHex: '04',
        challengeHex: '01',
        resultCode: 7
      })).assertEqual('认证服务正忙，请稍后重试')
      expect(describeCustomAuthVerificationFailure({
        success: false,
        userId: 104,
        credentialIdHex: '05',
        challengeHex: '01',
        resultCode: 2
      })).assertEqual('认证器内部异常，请重试')
    })

    it('maps_passcode_precheck_failures_without_exposing_password', 0, () => {
      expect(describeUKeyPasscodePrecheckFailure({
        success: false,
        locked: false,
        failedAttempts: 1,
        remainingAttempts: 4,
        fingerprint: 'SN:FIRST',
        reason: 'mismatch'
      })).assertEqual('UKey 密码错误，剩余 4 次')
      expect(describeUKeyPasscodePrecheckFailure({
        success: false,
        locked: false,
        failedAttempts: 0,
        remainingAttempts: 5,
        fingerprint: 'SN:FIRST',
        reason: 'ukey_absent'
      })).assertEqual('目标 UKey 已移除，请重新插入后重试')
    })

    it('includes_user_reason_and_skipped_count_in_summary', 0, () => {
      let failure: CustomAuthCredentialVerificationResult = {
        success: false,
        userId: 100,
        credentialIdHex: '01',
        challengeHex: '01',
        resultCode: 1
      }
      let summary: CustomAuthCredentialVerificationSummary = {
        total: 2,
        attemptedCount: 1,
        successCount: 0,
        failureCount: 1,
        skippedCount: 1,
        results: [failure]
      }
      let message = buildCustomAuthVerificationFailureMessage(summary)
      expect(message).assertContain('用户 100')
      expect(message).assertContain('后续 1 个用户未验证')
      expect(message).assertContain('绑定/系统凭据不匹配')
    })

    it('rejects_wrong_password_once_before_multi_user_custom_auth', 0, async () => {
      let verifier = new CountingCredentialVerifier()
      let passcodeVerifier = new FakePasscodeVerifier({
        success: false,
        locked: false,
        failedAttempts: 2,
        remainingAttempts: 3,
        fingerprint: 'SN:FIRST',
        reason: 'mismatch'
      })
      let service = new LockScreenCustomAuthEnrollmentService(
        new FakeBindingRepository(),
        new FakeDeviceProvider(),
        new FakeCredentialManager(),
        new FakeActiveCredentialRepository(activeCredential()),
        new FakeUserProvider(),
        verifier,
        passcodeVerifier
      )
      let result = await service.verifyActiveCredentials({} as common.Context, '111111')
      expect(result.success).assertFalse()
      expect(result.userMessage ?? '').assertEqual('UKey 密码错误，剩余 3 次')
      expect(passcodeVerifier.verifyCalls).assertEqual(1)
      expect(verifier.calls).assertEqual(0)
    })
  })
}

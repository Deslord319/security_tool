import localUnitTest from './LocalUnit.test';
import lockScreenUKeyDeviceServiceTest from './LockScreenUKeyDeviceService.test';
import lockScreenUKeyBindingPolicyTest from './LockScreenUKeyBindingPolicy.test';
import lockScreenCustomAuthVerificationTest from './LockScreenCustomAuthVerification.test';

export default function testsuite() {
  localUnitTest();
  lockScreenUKeyDeviceServiceTest();
  lockScreenUKeyBindingPolicyTest();
  lockScreenCustomAuthVerificationTest();
}

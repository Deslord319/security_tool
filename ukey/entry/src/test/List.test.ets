import localUnitTest from './LocalUnit.test';
import lockScreenUKeyDeviceServiceTest from './LockScreenUKeyDeviceService.test';
import lockScreenUKeyBindingPolicyTest from './LockScreenUKeyBindingPolicy.test';

export default function testsuite() {
  localUnitTest();
  lockScreenUKeyDeviceServiceTest();
  lockScreenUKeyBindingPolicyTest();
}

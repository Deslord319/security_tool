import localUnitTest from './LocalUnit.test';
import lockScreenUKeyDeviceServiceTest from './LockScreenUKeyDeviceService.test';

export default function testsuite() {
  localUnitTest();
  lockScreenUKeyDeviceServiceTest();
}

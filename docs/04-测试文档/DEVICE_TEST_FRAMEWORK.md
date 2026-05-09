# Device Test Framework

This document records the validated HarmonyOS device-side test framework setup for this project.

## Verified Layout

- Main-module test runner entry: `entry/src/main/ets/testrunner/OpenHarmonyTestRunner.ets`
- Main-module test runner declaration: `entry/src/main/module.json5`
- ohosTest runner source: `entry/src/ohosTest/ets/testrunner/OpenHarmonyTestRunner.ets`
- ohosTest suite dispatcher: `entry/src/ohosTest/ets/test/List.test.ets`
- ohosTest test ability: `entry/src/ohosTest/ets/testability/TestAbility.ets`

## Verified Commands

```bash
# local unit tests
hvigorw test --mode module -p product=default -p module=entry@default

# compile ohosTest
hvigorw test --mode module -p product=default -p module=entry@ohosTest

# package the device-side test hap
hvigorw assembleHap --mode module -p product=default -p module=entry@ohosTest
```

The test hap is generated at:

```text
entry/build/default/outputs/ohosTest/entry-ohosTest-unsigned.hap
```

## Signing And Install Order

Both packages must be installed on the device:

1. Install the signed main hap.
2. Install the signed `entry_test` hap.
3. Run `aa test`.

Example:

```bash
hdc install hapsigner/signApp.hap
hdc install entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -w 60000
```

## Verified Smoke Result

The default device-side smoke suite has been reduced to a stable baseline:

- Suite: `ActsAbilityTest`
- Case: `assertContain`
- Result: `Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0`

## Scenario Routing

The dispatcher in `entry/src/ohosTest/ets/test/List.test.ets` uses `mode` to select heavier scenarios:

```bash
# default smoke
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -w 60000

# route scenario
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode route_action -w 60000

# peripheral contract scenario
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode peripheral_contract -w 60000

# theme menu scenario
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode theme_menu -w 60000

# firewall subroute restore scenario
hdc shell aa test -b com.huawei.securitytool -m entry -s unittest OpenHarmonyTestRunner -s mode firewall_subroute -w 60000
```

## Community-Aligned Setup Notes

This setup follows the common community pattern for Stage-model HarmonyOS tests:

- `module.json5` declares `testRunner`
- the runner starts `TestAbility` through `AbilityDelegator`
- `ohosTest` is packaged as a separate test hap and installed independently
- `aa test` is run against the main module name `entry`

## Known Limits

- The route scenario still emits ArkTS warnings in `entry/src/ohosTest/ets/test/simple/RouteAction.test.ets`
- The default device suite intentionally stays small; heavier UI scenarios are selected explicitly through `mode`

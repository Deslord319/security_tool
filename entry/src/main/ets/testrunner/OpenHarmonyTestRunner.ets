import { TestRunner, abilityDelegatorRegistry } from '@kit.TestKit'

async function onAbilityCreateCallback(): Promise<void> {
}

async function addAbilityMonitorCallback(_err: Error): Promise<void> {
}

export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {
  }

  async onRun(): Promise<void> {
    const args = abilityDelegatorRegistry.getArguments()
    let abilityDelegator = abilityDelegatorRegistry.getAbilityDelegator()
    const testAbilityName = 'TestAbility'

    let monitor: abilityDelegatorRegistry.AbilityMonitor = {
      abilityName: testAbilityName,
      onAbilityCreate: onAbilityCreateCallback
    }
    abilityDelegator.addAbilityMonitor(monitor, addAbilityMonitorCallback)

    abilityDelegator.startAbility({
      bundleName: args.bundleName,
      abilityName: testAbilityName
    }, (_err, _data) => {
    })
  }
}

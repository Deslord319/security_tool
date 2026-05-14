# Peripheral USB Default Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Change `接口管控 > USB接口` from system-level restrictions control to a persisted application-side USB default policy.

**Architecture:** Keep the existing external UI text and black/white list model. Store `usb_default_policy` in the existing `peripheral_device_policy` Preferences store owned by `PeripheralDevicePolicyRepository`, and use it only to decide whether unknown USB devices should be auto-denied on first connect. Existing deny hits continue to use the current connection-record-only behavior and do not replay `addDisallowedUsbDevices`.

**Tech Stack:** HarmonyOS ArkTS, PreferencesAccessor, MVVM ViewModel layer, MDM `usbManager`, local Hypium/Hamock tests, hvigor.

---

## Work Area

- Workspace: `D:\project\ai\security_tool`
- Branch: `codex/peripheral-usb-default-policy`
- If execution starts on `master`, create the branch first:

```powershell
git checkout -b codex/peripheral-usb-default-policy
```

## Background

Peripheral management currently includes interface control, connection records, and black/white list policy. The current `接口管控 > USB接口` implementation calls `restrictions.setDisallowedPolicy(..., 'usb', ...)`, which means system-level global USB disablement. Black/white list policy is separately maintained by `PeripheralDevicePolicyRepository`, and system USB type deny is applied by `usbManager.addDisallowedUsbDevices` during first-connect auto-deny or manual deny.

The specification changes the USB interface switch meaning while keeping the product text unchanged. `接口管控 > USB接口` now means an application-side USB default policy. It no longer directly calls restrictions; it decides whether an unknown USB device should be automatically added to the local deny policy when it first connects.

## Purpose

- Persist USB interface default policy as application data.
- Use default `allow` for upgrades and empty stores.
- When default policy is `allow`, an unknown USB first connect does not auto-deny.
- When default policy is `deny`, an unknown USB first connect calls `addDisallowedUsbDevices`; after success it saves local `deny`.
- Existing local deny hit keeps current implementation: show `device_deny / BLOCKED` and do not call `addDisallowedUsbDevices` again.
- Manual black/white list behavior and clear-all restore behavior continue to use the existing policy repository and dispatch flow.

## Storage Constraint

Project storage rules require `PreferencesAccessor + single-owner Repository` for small configuration. The existing `peripheral_device_policy` Preferences store is already owned by `entry/src/main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository.ets`.

Therefore, add `usb_default_policy` to the existing store and owner repository. Do not create a new RDB table, new store, or separate repository that writes the same store.

## File Scope

Docs:

- Modify: `docs/03-模块设计/外设管理组件设计说明.md`
- Create: `docs/superpowers/plans/2026-05-14-peripheral-usb-default-policy.md`

Code:

- Modify: `entry/src/main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository.ets`
- Modify: `entry/src/main/ets/services/peripheral/interface-control/PeripheralService.ets`
- Modify: `entry/src/main/ets/viewmodels/peripheral/interface-control/InterfaceControlViewModel.ets`
- Modify: `entry/src/main/ets/viewmodels/peripheral/overview/PeripheralViewModel.ets`
- Modify: `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets`
- Modify: `entry/src/main/ets/services/peripheral/device-policy/peripheral_device_policy_dispatch_service.ets`
- Modify: `entry/src/main/ets/runtime/ApplicationRuntimeManager.ets`

Tests:

- Modify: `entry/src/test/peripheral/device-policy-repository.test.ets`
- Modify: `entry/src/test/peripheral/connection-record-usb-consumer.test.ets`
- Modify: `entry/src/test/peripheral/device-policy-dispatch-service.test.ets`
- Modify: `entry/src/test/peripheral/service.test.ets`
- Modify: `entry/src/test/viewmodels/InterfaceControlViewModel.test.ets`
- Modify: `entry/src/test/viewmodels/PeripheralViewModel.test.ets`

## Corrupt Old Code To Remove

- Remove or make unreachable `PeripheralService.setUsbInterfaceDisabledWithCleanup(...)`. It exists for the old USB restrictions behavior: read USB storage policy, possibly restore it to `READ_WRITE`, then call `restrictions.setDisallowedPolicy(..., 'usb', disallow)`.
- Remove the `FEATURE_USB` branch in `PeripheralService.setInterfaceDisabledWithResult(...)` that calls the old cleanup method.
- Change the `FEATURE_USB` branch in `PeripheralService.getInterfaceDisabledWithResult(...)` so it reads `PeripheralDevicePolicyRepository.isUsbDefaultDeny()` instead of `restrictions.getDisallowedPolicy(..., 'usb')`.
- Remove the USB restrictions global-disabled conflict check from `PeripheralDevicePolicyDispatchService.dispatchUsbPolicy(...)`. USB storage `DISABLED` conflict checks remain.

## Implementation Pseudocode

Repository:

```ts
export type PeripheralUsbDefaultPolicy = 'allow' | 'deny'
const PREF_KEY_USB_DEFAULT_POLICY = 'usb_default_policy'
let usbDefaultPolicy: PeripheralUsbDefaultPolicy = 'allow'

static getUsbDefaultPolicy(): PeripheralUsbDefaultPolicy {
  return usbDefaultPolicy
}

static isUsbDefaultDeny(): boolean {
  return usbDefaultPolicy === 'deny'
}

static async setUsbDefaultPolicy(policy: PeripheralUsbDefaultPolicy): Promise<boolean> {
  usbDefaultPolicy = policy === 'deny' ? 'deny' : 'allow'
  await saveUsbDefaultPolicy()
  notifyChanged()
  return true
}
```

Interface toggle:

```ts
async toggleInterface(feature: string, disallow: boolean): Promise<string | null> {
  processingKey = feature
  try {
    if (feature === PeripheralService.FEATURE_USB) {
      const ok = await PeripheralDevicePolicyRepository.setUsbDefaultPolicy(disallow ? 'deny' : 'allow')
      if (!ok) {
        return PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED
      }
      updateInterfaceState(feature, disallow)
      return null
    }

    const result = PeripheralService.setInterfaceDisabledWithResult(feature, disallow)
    if (!result.success) {
      return normalizeReason(result.stage, PeripheralReasonCodes.TOGGLE_INTERFACE_FAILED)
    }
    updateInterfaceState(feature, disallow)
    return null
  } finally {
    processingKey = ''
  }
}
```

USB auto-deny:

```ts
if (action !== 'connect') return not_applicable
if (invalidVidPid) return skipped_invalid_device_id
if (PeripheralDevicePolicyRepository.get(info.deviceId)) return skipped_existing_policy
if (!PeripheralDevicePolicyRepository.isUsbDefaultDeny()) return skipped_default_allow

const dispatchResult = await PeripheralDevicePolicyDispatchService.dispatch({ policy: 'deny', ... })
if (!dispatchResult.success) return dispatch_failed

const saved = await PeripheralDevicePolicyRepository.set({ policy: 'deny', ... })
return saved ? saved : save_failed
```

Existing deny hit:

```ts
if (snapshot.devicePolicies.get(info.deviceId.toUpperCase()) === 'deny') {
  return {
    policyHit: 'deny',
    result: SecurityEventResult.BLOCKED,
    matchedPolicyKind: 'device_deny'
  }
  // Do not call addDisallowedUsbDevices again.
}
```

## Tasks

### Task 1: Branch And Documentation Lock

**Files:**
- Modify: `docs/03-模块设计/外设管理组件设计说明.md`
- Create: `docs/superpowers/plans/2026-05-14-peripheral-usb-default-policy.md`

- [ ] **Step 1: Create branch**

Run:

```powershell
git checkout -b codex/peripheral-usb-default-policy
```

Expected: branch created unless already on `codex/peripheral-usb-default-policy`.

- [ ] **Step 2: Update module design**

Update `docs/03-模块设计/外设管理组件设计说明.md` so it states:

- USB interface text remains, meaning changes to app-side `usb_default_policy`.
- `usb_default_policy` is stored in `peripheral_device_policy`.
- `PeripheralDevicePolicyRepository` is the only owner.
- Default value is `allow`.
- Unknown USB only auto-denies when policy is `deny`.
- Existing deny hit does not replay `addDisallowedUsbDevices`.
- Clear-all still restores system side through allow/remove before clearing local records.

- [ ] **Step 3: Commit docs**

Run:

```powershell
git add docs/03-模块设计/外设管理组件设计说明.md docs/superpowers/plans/2026-05-14-peripheral-usb-default-policy.md
git commit -m "docs: lock peripheral usb default policy design"
```

Expected: docs commit succeeds.

### Task 2: Repository Persistence

**Files:**
- Modify: `entry/src/main/ets/services/peripheral/device-policy/PeripheralDevicePolicyRepository.ets`
- Modify: `entry/src/test/peripheral/device-policy-repository.test.ets`

- [ ] **Step 1: Add tests**

Add tests that verify:

```ts
expect(PeripheralDevicePolicyRepository.getUsbDefaultPolicy()).assertEqual('allow')
await PeripheralDevicePolicyRepository.setUsbDefaultPolicy('deny')
expect(PeripheralDevicePolicyRepository.isUsbDefaultDeny()).assertTrue()
await PeripheralDevicePolicyRepository.setUsbDefaultPolicy('allow')
expect(PeripheralDevicePolicyRepository.isUsbDefaultDeny()).assertFalse()
```

- [ ] **Step 2: Implement repository methods**

Add `PeripheralUsbDefaultPolicy`, `PREF_KEY_USB_DEFAULT_POLICY`, cached value, load in `doInit`, save method, and public getters/setter.

- [ ] **Step 3: Verify repository tests**

Run entry unit tests or the narrow test command supported by this repo.

Expected: repository tests pass.

### Task 3: Interface Control Switch

**Files:**
- Modify: `entry/src/main/ets/services/peripheral/interface-control/PeripheralService.ets`
- Modify: `entry/src/main/ets/viewmodels/peripheral/interface-control/InterfaceControlViewModel.ets`
- Modify: `entry/src/test/peripheral/service.test.ets`
- Modify: `entry/src/test/viewmodels/InterfaceControlViewModel.test.ets`

- [ ] **Step 1: Add tests**

Verify:

- `reloadState()` reads USB disabled from `PeripheralDevicePolicyRepository.isUsbDefaultDeny()`.
- USB toggle saves `deny` or `allow` through `PeripheralDevicePolicyRepository.setUsbDefaultPolicy(...)`.
- USB toggle does not call restrictions.
- Non-USB toggles keep current `PeripheralService.setInterfaceDisabledWithResult(...)` behavior.

- [ ] **Step 2: Implement switch behavior**

Move USB handling into `InterfaceControlViewModel.toggleInterface(...)` and `reloadState()`. Remove old USB restrictions handling from `PeripheralService`.

- [ ] **Step 3: Verify interface-control tests**

Expected: USB tests pass and non-USB behavior remains unchanged.

### Task 4: USB Consumer Auto-Deny Condition

**Files:**
- Modify: `entry/src/main/ets/services/peripheral/connection-record/peripheral_connection_record_usb_consumer.ets`
- Modify: `entry/src/test/peripheral/connection-record-usb-consumer.test.ets`

- [ ] **Step 1: Add tests**

Verify:

- default `allow` + unknown USB: no dispatch, no local deny.
- default `deny` + unknown USB: dispatch deny and save local deny.
- existing local deny: no dispatch replay, record remains `device_deny`.
- USB storage disabled path still skips auto-deny.

- [ ] **Step 2: Implement condition**

Add `PeripheralDevicePolicyRepository.isUsbDefaultDeny()` as a required condition in first-connect auto-deny.

- [ ] **Step 3: Verify USB consumer tests**

Expected: all USB consumer tests pass.

### Task 5: Dispatch Service Restrictions Cleanup

**Files:**
- Modify: `entry/src/main/ets/services/peripheral/device-policy/peripheral_device_policy_dispatch_service.ets`
- Modify: `entry/src/test/peripheral/device-policy-dispatch-service.test.ets`

- [ ] **Step 1: Add tests**

Verify:

- USB deny no longer fails because restrictions USB is disabled.
- USB storage `DISABLED` still fails.
- allow keeps get-then-remove behavior.

- [ ] **Step 2: Remove old conflict check**

Delete `getUsbDisabledState()` usage from USB dispatch flow and remove unused restrictions import/helper if no longer referenced.

- [ ] **Step 3: Verify dispatch tests**

Expected: dispatch tests pass.

### Task 6: Initialization And Full Verification

**Files:**
- Modify: `entry/src/main/ets/viewmodels/peripheral/overview/PeripheralViewModel.ets`
- Modify: `entry/src/main/ets/runtime/ApplicationRuntimeManager.ets`
- Modify: `entry/src/test/viewmodels/PeripheralViewModel.test.ets`

- [ ] **Step 1: Confirm initialization paths**

Ensure `PeripheralDevicePolicyRepository.init(context)` runs before UI state reload and before runtime USB consumer processes events.

- [ ] **Step 2: Run consistency and unit tests**

Run:

```powershell
python scripts/check_docs_consistency.py
hvigorw test --mode module -p product=default -p module=entry@default
```

Expected: consistency check and tests pass.

- [ ] **Step 3: Build, sign, install**

Run the project build/sign/install flow from `AGENTS.md`:

```powershell
hvigorw assembleHap --mode module -p product=default -p module=entry
Copy-Item entry/build/default/outputs/default/entry-default-unsigned.hap hapsigner/entry-default-unsigned.hap -Force
Push-Location hapsigner
.\2-debug-sign.bat
Pop-Location
hdc install hapsigner/signApp.hap
hdc shell edm enable-admin -n com.huawei.securitytool -a EnterpriseAdminAbility -t super
```

Expected: build, sign, install, and admin activation complete.

- [ ] **Step 4: Commit code**

Run:

```powershell
git add entry/src/main/ets entry/src/test
git commit -m "feat: persist usb default peripheral policy"
```

Expected: code commit succeeds and `git status --short -uno` is clean.

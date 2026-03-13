# E2E Backend Adaptation Notes

## Background

This note captures the practical lessons from debugging and fixing the
`firewall/domain_browser.json` case on a real HarmonyOS device.

The main issues were not caused by MCP atomic tools themselves. They were
caused by adapter/backend assumptions that were too weak for a real UI:

- same-text nodes existed in different scopes
- form structure changed after rule type switching
- "input succeeded" was treated as "submit succeeded"
- "button clicked" was treated as "result applied"

The fixes added more adaptation code, but most of that code is reliability
logic rather than feature bloat.

## What Was Fixed

### 1. Rule type selection was selecting the wrong node

The firewall dialog contains:

- page-level filter tabs such as `IP 规则 / 域名规则 / DNS 规则`
- dropdown option items with the same labels

A plain text match could hit the page tab instead of the dropdown option.

Fix:

- scope option selection to the active select area
- prefer candidates aligned with the current select's left edge
- verify that the select value actually changed after clicking

### 2. Select changes now require readback verification

For firewall dialog selects:

- rule type
- direction
- protocol
- policy

the backend now follows:

1. open select
2. choose target option
3. read back the select value
4. fail immediately if the value did not change

This prevents silent drift into the wrong form state.

### 3. Policy selection could not use a fixed select index

After switching to `域名规则`, the dialog no longer has the same number of
`Select` controls as the default IP form.

Fix:

- do not assume policy is always the 4th select
- resolve policy using the last select in the current form layout

### 4. Dialog submit must target the real dialog button

The backend previously allowed loose confirmation behavior.

Fix:

- prefer the dialog's bottom action button such as `添加 / 确定`
- keep submit evidence in the result payload

### 5. Rule creation must be verified after submit

Closing the dialog is not enough.

Fix:

- after submit and dialog dismissal, verify that the target firewall rule
  actually appears in the rule list

### 6. Browser URL input must explicitly submit navigation

The old logic had a gap:

- URL input could be read back successfully
- but Enter might never actually be sent

Fix:

- browser URL input now reuses `_input_text_with_commit(...)`
- browser case uses forced commit enter
- browser submit currently sends Enter twice because a single Enter may be
  dropped on some real devices
- submit evidence is kept in the result payload

## General Backend Patterns

### Selection pattern

Every select-like interaction should follow:

1. open the control
2. choose the target option within a scoped region
3. read back the selected value
4. fail immediately if the value did not change

Do not treat "clicked something" as success.

### Input pattern

Every text input should follow:

1. focus the target `TextInput`
2. input once
3. read back the field value
4. if the scene requires submit, explicitly commit
5. preserve both input and commit evidence

Do not mix "input succeeded" and "submit succeeded" into one notion.

### Submit pattern

Every submit-like action should follow:

1. click the concrete submit button
2. verify dialog/page state changed
3. verify target result exists

Success should be defined by the final state, not by the click itself.

### Scoped matching pattern

When the UI contains same-text nodes, matching must use scope:

- region boundaries
- relative position to the active control
- alignment
- visibility and clickability

Text-only matching is not reliable enough for complex pages.

### Dynamic form pattern

Do not hardcode field indexes across different form modes.

Examples:

- IP rule form
- domain rule form
- DNS rule form

The backend should derive control positions from the current layout after the
mode switch is complete.

## Coding Guidelines For Future Adaptation

### 1. Prefer "action + verification" helpers

Instead of writing raw click/input sequences inside each action, keep building
small helpers such as:

- `select_and_verify(...)`
- `input_and_verify(...)`
- `submit_and_verify(...)`
- `wait_for_state_change(...)`

This keeps action code shorter and makes failure behavior consistent.

### 2. Keep adaptation logic close to backend, not MCP

MCP should continue exposing generic atomic tools:

- click
- input
- wait
- find
- get UI tree

Business-page adaptation should stay in the E2E backend layer.

### 3. Preserve rich evidence on every non-trivial action

For debugging real-device instability, always keep:

- chosen target node
- readback result
- submit result
- final verification result

If an action fails, evidence should explain whether the problem happened at:

- control discovery
- click
- input
- commit
- state update
- final result observation

### 4. Avoid hidden retries

Retries should be explicit and justified.

Good example:

- browser submit sends Enter twice because real-device behavior proves the
  first one may be lost

Bad example:

- silently re-inputting the same field multiple times without evidence

### 5. Treat each page as a state machine

For complex pages, actions should assume the page can be in different states:

- list page
- dialog open
- mode switched
- submit pending
- result visible

Each action should first detect current state, then operate, then verify the
next state.

## Recommended Refactoring Direction

The current backend is workable, but it is growing. Future refactoring should
focus on extracting repeated reliability patterns rather than moving logic into
MCP.

### A. Extract selection helpers

Candidate module direction:

- `selection_helpers`

Suggested responsibilities:

- open select
- locate option in scoped overlay area
- verify selected value

### B. Extract form helpers

Candidate module direction:

- `form_helpers`

Suggested responsibilities:

- locate current form fields
- adapt to dynamic layouts
- input values with readback
- map current form mode to required fields

### C. Extract submit helpers

Candidate module direction:

- `submission_helpers`

Suggested responsibilities:

- locate concrete submit button
- submit dialog/page action
- wait for dismissal
- verify result landed

### D. Extract browser helpers

Candidate module direction:

- `browser_helpers`

Suggested responsibilities:

- locate address bar
- input URL with forced submit
- verify navigation signal
- normalize host/url matching

## Practical Rule

For future E2E backend work, define success using this rule:

`Action succeeded` only when:

1. the intended control interaction happened
2. the target UI state changed as expected
3. the expected end result became observable

If only step 1 happened, the action is not done.

## Refactoring Task List

### Phase 1: stabilize repeated interaction patterns

1. Extract select operations into a shared helper
   - target:
     - open select
     - choose scoped option
     - verify selected value
   - expected outcome:
     - firewall/tool-settings/peripheral select logic stops duplicating

2. Extract dialog submit operations into a shared helper
   - target:
     - pick concrete submit button
     - click submit
     - wait dialog disappear
     - verify result landed
   - expected outcome:
     - add/save/confirm flows use the same success definition

3. Extract browser-specific input and submit helper
   - target:
     - locate address bar
     - input URL
     - force double-enter submit when required
     - verify navigation signal
   - expected outcome:
     - browser actions stop carrying page-specific submit logic inline

### Phase 2: reduce form-specific branching

4. Extract dynamic firewall form resolver
   - target:
     - identify current rule form mode
     - map visible controls for ip/domain/dns forms
   - expected outcome:
     - no more fixed assumptions about select/input indexes across rule types

5. Add form field mapping layer
   - target:
     - convert case params into current visible form fields
   - expected outcome:
     - actions fill fields by meaning, not by raw index

### Phase 3: improve observability

6. Normalize action evidence payloads
   - target:
     - chosen node
     - input/readback result
     - submit evidence
     - final verification evidence
   - expected outcome:
     - failures become easier to diagnose from result JSON alone

7. Add lightweight debug snapshot hooks
   - target:
     - optional snapshots before select
     - after select
     - after submit
   - expected outcome:
     - real-device flaky issues can be reproduced faster

### Phase 4: control file growth

8. Split `real_harmonyos_mcp_backend.py` by helper domain
   - suggested modules:
     - `selection_helpers.py`
     - `form_helpers.py`
     - `submission_helpers.py`
     - `browser_helpers.py`
   - expected outcome:
     - backend action methods stay thin

9. Keep action methods orchestration-only
   - target:
     - each action should read like:
       - navigate
       - operate
       - verify
   - expected outcome:
     - new page adaptation remains readable and reviewable

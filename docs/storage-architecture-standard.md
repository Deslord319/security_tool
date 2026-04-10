# Storage Architecture Standard

## Goal

Establish a long-term storage standard for the project to solve:

- scattered `preferences.getPreferences/get/put/flush`
- multiple owners writing the same store
- repeated type normalization glue such as `startupAuthRaw`
- oversized JSON payload persistence for logs and traces
- UI blocking during export
- lack of migration and cleanup rules

## Architecture

All persistence must follow these two primary tracks:

1. Small configuration and small object data
   - `PreferencesAccessor + single-owner Repository`
2. High-growth record data
   - `@ohos.data.relationalStore + Repository + Maintenance Service + Export Service`

## Layers

Use exactly these layers:

1. Accessor / Provider
   - wraps low-level APIs only
   - examples:
     - `PreferencesAccessor`
     - `RdbStoreProvider`
2. Repository
   - one repository owns one store or one table
   - examples:
     - `ToolSettingsRepository`
     - `FirewallModeRepository`
     - `LogEntryRepository`
3. Service
   - orchestrates business flow only
   - examples:
     - `LogStorageMaintenanceService`
     - `LogExportService`
     - `FirewallUserModeService`
4. ViewModel / UI
   - must not access Preferences or SQL directly

## Hard Rules

1. One store or table must have exactly one owner repository.
2. Page, ViewModel, strategy, and service layers must not call `preferences.getPreferences(...)` directly.
3. Page, ViewModel, strategy, and service layers must not call SQL directly.
4. `JSON.parse/stringify` is only allowed in accessor or repository layers.
5. Small configuration remains in Preferences.
6. Log and trace records must move to relational storage.

## Data Classification

### Preferences

Keep these in Preferences:

- Tool Settings
- Theme Settings
- Firewall Mode
- Firewall Auth State
- Log Settings
- Firewall User Bindings
- Firewall Custom Rules (phase 1; reevaluate later)

### Relational Database

Move these to `@ohos.data.relationalStore`:

- Log Entries
- Peripheral Trace Entries

## PreferencesAccessor

Add:

- `entry/src/main/ets/storage/preferences/PreferencesAccessor.ets`

Responsibilities:

- cache multiple store instances
- typed reads:
  - `getString`
  - `getBoolean`
  - `getNumber`
  - `getJsonArray`
  - `getJsonObject`
- typed writes:
  - `setValue`
  - `setJson`
  - `setMany`
  - `flush`
- default fallback
- unified error logging

### Why `setMany`

`setMany` groups multiple `put` calls and performs one final `flush`.

Use it for:

- saving multiple configuration fields
- authentication state updates
- migrations

Do not use it for:

- high-frequency log writes
- large append-only record persistence

## Relational Storage Design

Add:

- `entry/src/main/ets/storage/rdb/RdbStoreProvider.ets`
- `entry/src/main/ets/storage/rdb/DatabaseVersionManager.ets`

Use a project database such as:

- `security_tool.db`

### Log Table

Table: `log_entries`

Required columns:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `record_id TEXT UNIQUE`
- `timestamp INTEGER NOT NULL`
- `event_type TEXT NOT NULL`
- `result TEXT NOT NULL`
- `source TEXT NOT NULL`
- `detail TEXT NOT NULL`
- `process_name TEXT`
- `file_path TEXT`
- `extra_json TEXT`

Required indexes:

- `idx_log_entries_timestamp`
- `idx_log_entries_event_type`
- `idx_log_entries_result`

### Peripheral Trace Table

Table: `peripheral_trace_entries`

Required columns:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `record_id TEXT UNIQUE`
- `occur_at INTEGER NOT NULL`
- `collect_at INTEGER NOT NULL`
- `device_name TEXT NOT NULL`
- `device_type TEXT NOT NULL`
- `device_id TEXT NOT NULL`
- `action TEXT NOT NULL`
- `decision TEXT NOT NULL`
- `result TEXT NOT NULL`
- `source TEXT NOT NULL`
- `summary TEXT NOT NULL`
- `detail TEXT`
- `process_name TEXT`
- `raw_payload TEXT`
- `extra_json TEXT`

Required indexes:

- `idx_peripheral_trace_occur_at`
- `idx_peripheral_trace_device_id`
- `idx_peripheral_trace_action`

## Log Module Long-Term Design

Split log management into:

1. `LogSettingsRepository`
   - Preferences-backed
2. `LogEntryRepository`
   - relational data owner
3. `LogStorageMaintenanceService`
   - retention and max-entry cleanup
4. `LogExportService`
   - background export only

### Mandatory retention rules

After append, data must satisfy both:

- retain only records within `retentionDays`
- keep at most `maxEntries`

Cleanup order:

1. delete expired by time
2. trim oldest by count

### Export rules

Exports must:

- run off the UI thread
- paginate queries
- write file in chunks
- avoid building one giant string in the UI thread

## Peripheral Trace Long-Term Design

Current state:

- `PeripheralTraceEntryRepository` is the relational owner of `peripheral_trace_entries`
- `PeripheralTraceMaintenanceService` owns initialization, append, retention cleanup, max-entry trimming, and clear-all flow
- the old Preferences payload path for peripheral traces has been removed
- the old `PeripheralTraceRepository` compatibility owner has been retired from the runtime storage path

Remaining alignment work:

- move peripheral statistics from in-memory aggregation to SQL aggregation
- add pagination-oriented query flow for connection record pages instead of always loading the full record set
- upgrade peripheral maintenance results from raw `boolean` to typed result objects aligned with log maintenance
- make peripheral pipeline return semantics distinguish between "handled by consumer" and "persisted successfully"

## Firewall Long-Term Design

Split storage ownership into:

- `FirewallModeRepository`
- `FirewallAuthRepository`
- `FirewallCustomRulesRepository`
- `FirewallUserBindingsRepository`

Keep business orchestration separate:

- `FirewallUserModeService`

`FirewallModeStrategyFactory`, `CustomModeStrategy`, and `FirewallStore` must stop directly owning Preferences stores.

## Failure Handling Standard

Use a unified result model such as:

```ts
interface StorageResult<T> {
  success: boolean
  code: 'ok' | 'read_failed' | 'save_failed' | 'storage_init_failed' | 'data_corrupted' | 'export_failed'
  message?: string
  data?: T
}
```

Rules:

- config read failure: fallback to default
- list read failure: fallback to empty collection
- write failure: return explicit failure, never fake success
- JSON parse failure: treat as corrupted data
- append-type persistence failure: may keep in-memory state, but must mark degraded and log it

## Migration Standard

Add:

- `entry/src/main/ets/storage/preferences/PreferencesMigrationService.ets`

Migration responsibilities:

- old key/store rename migration
- old Preferences payload to RDB migration for logs
- old Preferences payload to RDB migration for peripheral traces
- migration markers

## Naming Standard

- low-level wrappers:
  - `XxxAccessor`
  - `XxxProvider`
- configuration owners:
  - `XxxRepository`
- record owners:
  - `XxxEntryRepository`
- maintenance:
  - `XxxMaintenanceService`
- export:
  - `XxxExportService`

## File-by-File Migration Targets

### Keep and refactor internally

- `entry/src/main/ets/services/tool-settings/system-settings/ToolSettingsRepository.ets`
- `entry/src/main/ets/theme/ThemeManager.ets`
- `entry/src/main/ets/services/firewall/stores/FirewallAuthStateStore.ets`

### Split ownership and thin out

- `entry/src/main/ets/services/firewall/mode-strategies/FirewallModeStrategyFactory.ets`
- `entry/src/main/ets/services/firewall/mode-strategies/CustomModeStrategy.ets`
- `entry/src/main/ets/services/firewall/stores/FirewallStore.ets`

### Replace long-term persistence approach

- `entry/src/main/ets/services/log-manage/repository/LogConfigRepository.ets`
- `entry/src/main/ets/services/log-manage/repository/LogRepository.ets`
- `entry/src/main/ets/services/peripheral/connection-record/PeripheralTraceRepository.ets`

Current runtime status:

- `entry/src/main/ets/services/log-manage/repository/LogConfigRepository.ets` has been replaced by `LogSettingsRepository`
- `entry/src/main/ets/services/log-manage/repository/LogRepository.ets` has been removed from the runtime path
- `entry/src/main/ets/services/peripheral/connection-record/PeripheralTraceRepository.ets` is no longer the runtime storage owner; the runtime path uses `PeripheralTraceEntryRepository + PeripheralTraceMaintenanceService`

## Removable Glue

Remove or eliminate patterns such as:

- `startupAuthRaw`
- `authMethodRaw`
- `failedCountRaw`
- `lockUntilRaw`
- repeated `rawValue`
- repeated `serialized`
- repeated local `normalizeNumber`
- repeated direct `JSON.parse/stringify` around Preferences payloads

## Migration Phases

### Phase 1: foundation

- add `PreferencesAccessor`
- add `RdbStoreProvider`
- add `DatabaseVersionManager`
- define unified storage result model

### Phase 2: small config migration

- refactor `ToolSettingsRepository`
- refactor `ThemeManager`
- refactor `FirewallAuthStateStore`

### Phase 3: firewall owner cleanup

- add firewall repositories
- remove direct Preferences ownership from factory/strategy/store classes

### Phase 4: log migration

- convert `LogConfigRepository` into `LogSettingsRepository`
- add `LogEntryRepository`
- add maintenance and export services
- migrate old Preferences log payload into RDB

### Phase 5: peripheral trace migration

- migration completed for runtime storage ownership:
  - `PeripheralTraceEntryRepository` owns relational persistence
  - `PeripheralTraceMaintenanceService` owns append and cleanup flow
- follow-up work:
  - SQL-backed statistics
  - paged list queries for peripheral record pages
  - typed maintenance result model
  - stricter pipeline persistence result semantics

### Phase 6: global cleanup

Search and eliminate direct persistence leakage:

- `preferences.getPreferences`
- `store.get(`
- `store.put(`
- `store.flush(`
- `JSON.parse(`
- `JSON.stringify(`

## Acceptance Criteria

1. One store or table has one owner repository only.
2. UI, ViewModel, strategy, and service layers no longer directly use Preferences or SQL.
3. Small configuration uses `PreferencesAccessor`.
4. Log and peripheral trace records use relational storage.
5. Log append enforces both time retention and max count.
6. Export runs in the background and does not block the UI.
7. Glue variables such as `startupAuthRaw` are removed from repository implementations.

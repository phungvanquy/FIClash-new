# Tasks

## 10. Import, refresh, and replacement performance

- [x] 10.1 Reuse source-matched, integrity-checked geographic data with bounded freshness across immutable generations; correct restored resource paths and stream snapshot integrity checks without weakening validation or rollback.
- [x] 10.2 Bound resource downloads, propagate cancellation to HTTP, and add request-scoped stage/provisioning progress for import/replacement and manual update. Keep cancellation busy until cleanup finishes and protect final commit interactions.
- [x] 10.3 Add cache, timeout, replacement/cancellation, and progress regressions; regenerate affected output, verify Flutter checks, and synchronize specifications and device acceptance guidance.

## 9. Post-build usability and reliability review

- [x] 9.6 Stabilize Android run-state serialization in minified builds, bound initial status checks, and provide safe retry/disconnect recovery without assuming a disconnected tunnel.
- [x] 9.7 Make measured latency prominent and connected feedback bright green; display the Core-observed current node, including Auto/Fallback changes, with lifecycle and stale-result protection.
- [x] 9.8 Add release-wire, status-recovery, current-node, and accessible UI regression coverage; regenerate output and synchronize specifications and the device checklist.

- [x] 9.1 Review Home/import/Settings feedback; add semantic connection colors, distinct transition/error presentation, transition action guards, and responsive accessibility tests.
- [x] 9.2 Add snapshot-scoped, single-flight node latency tests with bounded concurrency, measured milliseconds, timeout/unreachable/test-failure outcomes, stale-result rejection, and fastest-node highlighting without changing selection or connection intent.
- [x] 9.3 Harden Android teardown and notification cleanup, preserve native lifecycle ownership, retain truthful failed-stop observations, and test repeated stop, revoke, service loss, and reattachment.
- [x] 9.4 Regenerate models/providers/localizations; run Flutter, Go, and available Android JVM checks; synchronize specifications, architecture, usage instructions, and device acceptance checklist. Record hardware-only checks as outstanding, not passed.
- [x] 9.5 Block false successful starts after incomplete Android teardown, clear stale stop failures after successful delayed cleanup, and verify retry/latest-intent behavior with regression tests and synchronized specifications.

## 1. Single-profile storage foundations

- [x] 1.1 Add profile revision/content-generation metadata, typed simple selection, routing preference, and cached server-catalog models with backward-compatible serialization; regenerate model output and verify legacy/current JSON round trips in `test/models/`.
- [x] 1.2 Add the required Drift migration and awaited single-profile repository operations, including profile-owned rules/groups and durable migration state; verify transaction rollback, sole-profile cardinality, and preservation of shared data in `test/database/`.
- [x] 1.3 Implement unpublished generation directories, stable candidate paths, flush/journal writes, and recovery decisions based on the committed database revision; verify simulated interruption before and after every commit boundary in storage tests.
- [x] 1.4 Teach source-path lookup, cached catalog loading, and `StoreAction.shakingStore` about generations and journal-pinned resources; verify offline catalog loading and that cleanup preserves active, rollback, and migration-backup data.

## 2. Candidate preparation and activation through Core

- [x] 2.1 Add typed prepare/activate/discard requests and results across the Core facade, interface, method dispatch, and wrapper handlers; verify Dart/Go envelope compatibility in `test/core/protocol_contract_test.dart` and wrapper contract tests.
- [x] 2.2 Add detached full-parser preparation in the maintained `core/Clash.Meta` fork and integrate it with the wrapper's candidate validation and required-provider preparation using isolated generation paths/identities, without the legacy fallback apply; verify malformed YAML, unsupported adapters, invalid references, provider fetch failures, and empty inventories leave the active tunnel unchanged.
- [x] 2.3 Keep candidate parsing settings and resources local until activation; separate provider loading from active refresh/health-check scheduling, connection closing, and events, and release partial resources on every error/discard path. Verify live mode, resolver/dialer settings, proxy names, and connections during preparation and after late-rule failure/discard, provider-name collisions, and valid prepared activation in fork and wrapper tests.
- [x] 2.4 Implement session/revision-scoped prepared handles, activation without remote re-fetch, and restoration from the previous committed snapshot; verify stale handles, Core restart, activation failure, and restoration failure with deterministic tests.
- [x] 2.5 Extend Core/profile source resolution and generated configuration persistence for immutable generations while preserving legacy reads and lock ordering; verify both old and new fixtures plus `CGO_ENABLED=0 go test .` and `CGO_ENABLED=0 go vet .` from `core/`.

## 3. Unified server inventory and routing

- [x] 3.1 Build normalized server identities/catalogs from inline and provider-backed proxies, excluding built-ins and group containers; verify nested groups, repeated references, equal display names, and ambiguous duplicate identities with fixture-based tests.
- [x] 3.2 Generate collision-free managed selector, URL-test, and fallback groups over the same eligible inventory, with reject-only empty fallback and stable fallback order; verify configs without automatic groups and name collisions in `test/common/task_test.dart` and wrapper tests.
- [x] 3.3 Implement simple routing through GLOBAL and the managed selector while retaining original configuration/advanced selections for custom routing; verify effective generated YAML, actual target resolution, mode round trips, and preservation of protocol-specific fields.
- [x] 3.4 Add profile/selection revision checks to selection persistence and RPC rollback in proxy actions; verify disconnected selection, connected switching, rejected selection, and rapid A/B selections in `test/providers/proxies_action_test.dart`.
- [x] 3.5 Integrate app-coordinated provider inventory updates with committed revisions, stable selection retention, and Auto fallback when a selected server disappears. Pause content refresh while Flutter is closed, prevent native writes into committed generations, retain native health checks/failover, and resume due refreshes when Flutter returns; verify stale loaded-provider events, failed/empty refreshes, offline reopening, and successful removal of a selected node.

## 4. Shared import and refresh coordinator

- [x] 4.1 Implement common URL normalization and typed intake results, preserving embedded tokens and accepting existing installation-link wrappers; verify manual/paste/QR equivalence, whitespace, encoded queries, invalid schemes, multiple URLs, and malformed subscription metadata.
- [x] 4.2 Implement the staged fetch/prepare/activate/database-commit flow with explicit success/error/cancel results; verify byte-for-byte preservation of the old profile, metadata, and selection for HTTP, validation, preparation, disk, and database failures.
- [x] 4.3 Add latest-submitted import arbitration and stale-refresh rejection, including cancellation/disposal cleanup; verify that A cannot commit after superseding B fails and that a late old-profile refresh cannot resurrect it.
- [x] 4.4 Integrate coordinator commits with `SetupAction`, compatibility preferences/shared state, and `CoreManager` so publication does not trigger duplicate setup; verify one activation per commit, repair of failed preference mirrors, disconnected imports, and latest disconnect intent during replacement.
- [x] 4.5 Route URL/file/deep-link imports, automatic/manual refreshes, and configuration editing through the same repository/coordinator contract; remove append and early-metadata-write bypasses, and verify every retained entry path enforces one profile and failure preservation.

## 5. Upgrade, backup, and restore

- [x] 5.1 Create and verify an app-private migration archive before pruning multi-profile records, preserving YAML, provider resources, associated rules/groups, scripts, and settings; verify offline migration, archive-write failure, and archive export round trips.
- [x] 5.2 Select the current usable legacy profile or first usable ordered fallback and commit migration idempotently before auto-start/refresh; verify missing selection, no usable profiles, repeated startup, interrupted migration, and crash-recovery intent preservation.
- [x] 5.3 Refactor `restoreTask`/`BackupAction.applyRestore` to stage files and choose one candidate from old or new backups before changing active data; verify failed restore preserves the current profile and settings, successful restore keeps one profile, and new backups include required generation resources.
- [x] 5.4 Add recovery/export and single-profile refresh/replace/edit actions for Settings, with archive retention outside routine cleanup; verify these actions never expose a switchable multi-profile list or discard the migration archive.

## 6. Confirmed connection state

- [x] 6.1 Expose Android `ServiceState` run-state snapshots/events and failure information through the service bridge without changing optimistic start/stop acknowledgements; verify STARTING/STARTED/STOPPING/STOPPED, permission denial, stale events, and attach/detach in Android JVM and Dart bridge tests.
- [x] 6.2 Publish desktop listener/TUN/system-proxy outcomes, including proxy installation failure and proxy-only fallback, through observed state while keeping lifecycle/Helper ownership intact; verify these paths in setup, proxy-manager, and desktop lifecycle tests.
- [x] 6.3 Build the derived connection presentation model and route connect/disconnect/cancel through existing latest-intent actions; verify Core-ready-but-disconnected, pending permission, rapid start/stop, external stop/revoke, suspension, and failed recovery in provider tests.
- [x] 6.4 Apply fresh-install VPN/TUN defaults on the user connect path, preserve migrated platform preferences, and synchronize attach/resume state without polling a mutating runtime query; verify import causes no VPN permission prompt and failed TUN authorization displays the actual operating mode.

## 7. Import-first Home and Settings interface

- [x] 7.1 Add the common intake surface with manual URL entry, explicit Paste, loading/retry/cancel feedback, and a compact replacement entry after setup; verify no automatic clipboard reads and success/failure/disposal behavior in import widget tests.
- [x] 7.2 Adapt Android camera/image intake to return payloads through the shared validator with one-shot scan submission and permission/cancel recovery; verify duplicate detections, invalid QR contents, scanner disposal, and return navigation.
- [x] 7.3 Add the desktop QR-image adapter with a decoder compatible with the pinned Dart/Flutter toolchain; verify dependency resolution and valid/invalid PNG/JPEG, no-code, oversized-image, and picker-cancel fixtures on Windows/macOS/Linux-capable paths.
- [x] 7.4 Replace the primary paged shell with responsive Home, the central circular button, truthful status, and a separately scrollable unified server list; verify empty/configured states, long lists, large text, narrow/wide layouts, and selection persistence in `test/pages/home_test.dart` and focused widget tests.
- [x] 7.5 Build the gear-accessed Settings route from existing Tools/configuration/diagnostic destinations, including custom routing and configuration recovery; verify back navigation, custom-mode indication, return to simple selection, and preservation of the running connection.
- [x] 7.6 Update tray menus, hotkey/navigation destinations, persisted page labels, and old profile/dashboard entry points to fit Home/Settings; verify no multi-profile switcher or old primary navigation remains and desktop window/header/focus behavior still passes its suites.
- [x] 7.7 Localize new copy in all four ARBs, add semantic names/tooltips and keyboard/touch behavior, and regenerate localization output; verify locale key parity, accessibility semantics, focus traversal, and relevant lint tests.

## 8. Integration validation and handoff

On 2026-09-21 the user approved deferring native compilation and device/platform testing to CI-built artifacts and later manual testing outside this development VPS. Tasks 8.3 and 8.4 remain unchecked until results are available; they do not require provisioning native test environments on this host. See `validation.md` for the artifact handoff and remaining checks.

- [x] 8.1 Run an integrated import-select-connect flow plus connected replacement and all failure/recovery boundaries using fake HTTP/storage/Core dependencies; verify each specification scenario is covered by an automated test or a named platform smoke check.
- [x] 8.2 Regenerate affected model/provider/Drift output, run `flutter pub get`, repository formatting checks, `flutter analyze --no-fatal-infos`, and `flutter test --reporter expanded`; record results and resolve failures introduced by the change without manually editing generated files.
- [ ] 8.3 Run Go wrapper checks, Android JVM tests and compilation for touched modules, and relevant changed-plugin checks; verify cross-language compatibility and record any unavailable native build prerequisites.
- [ ] 8.4 Smoke-test Android camera/permission/revoke/Quick Settings/reattachment and Windows/macOS/Linux QR image import, TUN authorization or proxy-only fallback, connected replacement, and window resizing; record results per available platform and explicitly identify untested host/device paths.
- [x] 8.5 Update repository architecture guidance and user-facing usage/migration documentation to describe Home/Settings, URL token meaning, single-profile replacement, routing modes, and recovery backup behavior; verify documentation matches implemented flows and preserves the earlier disclaimer removal.

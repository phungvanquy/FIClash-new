# Implementation checkpoint

## 2026-09-22 import, update, and replacement follow-up

Progress: 48/50 tasks complete. Follow-up tasks 10.1–10.3 are complete; native gates 8.3/8.4 remain open.

The user approved improving the replacement process together with import/update performance. The implementation preserves detached Core validation, immutable snapshots, the serialized activation/database commit, and rollback. It does not change native lifecycle ownership or the Core submodule.

- Geographic resources now reuse verified bytes from the committed generation when their source-URL hash and original fetch timestamp permit it. Online freshness is the positive configured interval in hours, or 24 hours. Offline edits can reuse older verified data; corrupt/mismatched data cannot fall back to unrelated global files. Legacy global files remain available for offline preparation without a committed generation. Copies never renew freshness, and unstamped restored data must be downloaded on a later online update.
- Restored geographic files now go into `geo/`, where detached parsing expects them. Backup restoration reads both current `geo/` and legacy generation-root resources, with checksum verification.
- Snapshot hashing streams file contents. Provider preparation retains four workers, stops dequeuing on failure, and awaits active workers before cleanup. HTTP transfers have 15-second connect, 30-second send/receive inactivity, and 90-second whole-transfer limits; cancellation reaches the actual transfer. No timer abandons a commit or rollback.
- Import/replacement and manual update show request-scoped stages and provider counts. Cancellation holds controls until cleanup returns; final commit blocks cancellation/back dismissal. The dialog has an idle Close action and cannot be dismissed by outside taps. Localized timeout guidance does not expose download credentials. Existing UI tokens/patterns are retained and all four ARBs regenerated.
- Sanitized stage-duration summaries identify slow downloads, preparation, snapshot saving, activation, or finalization without logging URLs, tokens, or resource names. Real-device speedups have not been measured.

Verification: all 110 focused storage/staging/coordinator/HTTP/import-widget/manual-update/action/backup tests pass. They include current and legacy backup layouts, cache expiry/source mismatch/corruption, offline compatibility, cancellation cleanup, queue failure, timeout propagation, and connected replacement rollback. The final full Flutter suite against the finished code passed **2,117 tests with 3 existing skips and no failures** (`/tmp/flclash-replacement-final-full-tests.log`). An earlier overlapping run mixed newly edited test expectations with older compiled production code; the fresh full run supersedes it. Dependency resolution, generation, formatting (545 files unchanged), strict OpenSpec validation, and comment-density/whitespace checks pass. Analysis has no errors/warnings and only the existing `scrollbar_inset_test.dart:18` const info (`/tmp/flclash-replacement-analyze.log`).

Android/Windows native timing, slow-network, large-text, live connected replacement, and offline backup restore checks remain artifact/device gates in `validation.md`, as the user previously requested. No commit or push has been performed for this follow-up.

## 2026-09-22 Android status and current-node display follow-up

Progress: 45/47 tasks complete. Follow-up tasks 9.6–9.8 are complete; native gates 8.3/8.4 remain open.

The reported permanent Checking connection was not reproduced on hardware here. Inspection found that Android release minification can rename the reflectively serialized run-state DTO outside the protected model packages; Flutter requires its original field/state names. Both event and snapshot paths now use an explicit wire encoder. Initial status checks coalesce and fail visibly after five seconds, with guarded retry and safe Disconnect; valid observations recover without inventing STOPPED or overwriting unrelated failures.

Connected Home uses a bright-green button/status badge with black foreground. Latency measurements use bold title-sized, contrasting badges. Current node comes from a read-only Core target-chain observation, not the persisted choice; Auto/Fallback show their observed leaf and provider. Queries fence Core identity/configuration, reject cycles/mismatches, and cannot write selection or interrupt traffic. Disposable polling pauses outside foreground Home, clears unavailable observations, and rejects stale profile/connection results. Custom routing explains that nodes depend on rules.

Verification for this follow-up:

- Focused Home/status/current-node/setup/bridge/manager/connection/controller regression run: 148 passed. The final current-node suite passed all 12 tests, including Settings pause/return.
- Portable Kotlin/JVM: 112 passed, including explicit field/state/default-snapshot contracts. This does not compile Android framework/plugin code or run R8.
- `flutter pub get`, provider generation, all four locale generation, formatting, strict OpenSpec validation, comment-density and whitespace checks passed.
- Analysis has no errors or warnings; only the existing const-constructor info in `test/widgets/scrollbar_inset_test.dart:18` remains.
- Full Flutter suite: 2,097 passed, 3 existing skips, 1 failure in the unchanged `NetworkDetection provider ignores a canceled stale check after a newer check succeeds` test (`test/providers/app_test.dart:509`). The test uses fixed-delay waits; this failure is consistent with timing sensitivity under full-suite load. An immediate isolated rerun of the entire `app_test.dart` suite passed all 47 tests, including that case. No network-detection code/test changes were made; the full run is not reported as green.

Native gates 8.3/8.4 remain open. The next minified Android artifact must verify import→Connect/Disconnect, reattachment and actual status recovery; Android/Windows device testing must confirm current-node failover and readability. No native-device result is inferred from these automated tests. No commit or push was requested for this follow-up; Core/submodule pins and unrelated tooling files are unchanged.

## 2026-09-22 Android disconnect follow-up

Progress: 42/44 tasks complete. Task 9.5 resolves the two additional state-machine bugs reproduced during the read-only review. Native compilation/device gates 8.3/8.4 remain open.

- Unresolved cleanup failure is retained independently of observations. Native starts, including proxy-only and background preparation paths, are rejected with a retryable disconnect error until cleanup succeeds; retained runtime/binding bookkeeping cannot be adopted as a healthy service. Permission denial and service loss do not hide cleanup still requiring retry. After successful Disconnect retry, an explicit start establishes the service normally.
- Successful delayed cleanup clears the resolved `stop_failed` error without clearing unrelated configuration/startup errors. Failure remains retryable and late cleanup cannot overwrite a newer request.
- Eight regression cases cover partial VPN/proxy teardown, zero-runtime cleanup, denied starts/service loss, blocked background preparation, successful/failed delayed cleanup, preserved configuration failure, and a newer start during cleanup. The first two regressions failed before the production fix; all 110 portable JVM tests pass afterward using the real state-machine sources and interface-only host scaffold.
- The focused Flutter connection-presentation, Android service-bridge, and Android-manager run passes all 37 tests. Strict OpenSpec validation, comment-density and diff-whitespace checks pass. No Dart model/provider/localization source changed in this follow-up, so no additional code generation was required.
- Specifications, architecture guidance, validation mapping and Android usage instructions describe retry-before-reconnect behavior. These tests reproduce code-level edge cases, not the user's device symptom. Actual VPN-key/notification removal and Android framework compilation still require CI/artifact validation; no commit or push was requested or performed.

## 2026-09-22 post-build UX, latency, and Android reliability

Progress: 41/43 tasks complete. Post-build implementation tasks 9.1–9.4 are complete; native compilation/device gates 8.3/8.4 remain open for this revision.

The user's Android symptom has not been reproduced on this VPS; Android version and Always-on settings were requested but are not available here. Code inspection identified failure paths, not proof that one particular path caused that report:

- Home's button stayed enabled during transitions. It now has a synchronous submission guard, disabled working states, explicit startup cancellation, semantic light/dark colors, and text/icons. Initial Android attachment shows Checking connection instead of assuming Disconnected.
- Android stop skipped cleanup with zero runtime and swallowed controller/module cleanup errors. Actual service instances are now inventoried independently of bindings, partial resources are cleaned, failures remain retryable, and runtime/binding ownership is released only after successful cleanup. The Go stop path also closes tracked traffic connections.
- Notification updates could race cancellation and recreate foreground state after removal. Publication/stop is serialized; partial module startup and failed cleanup retain retry ownership, and late network callbacks cannot repopulate stopped state.
- Background stops depended on Flutter callbacks. They now run through native arbitration directly. Stops coalesce, background setup cannot override a newer stop, and running bindings survive Flutter detachment. Native requested intent is carried separately from runtime; failed-stop observations no longer become reconnect intent in Flutter.
- Home latency uses unique catalog targets and a bounded, single-flight batch. Results distinguish timeout/unreachable/test failures, reject stale generation/URL/Core/disposal completions, and highlight the fastest node without selection writes or traffic resets. Loopback tests caught sub-millisecond success being converted to failure; successful probes now display at least 1 ms.

Verification on the Linux arm64 development host:

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed; dependencies not upgraded. |
| Model/provider and four-locale generation | Passed; generated output not hand-edited; localization output normalized by formatter. |
| Full `flutter test --reporter expanded` | 2,071 passed, 3 existing skips. |
| Focused run after final theme/attachment/retry refinements | 121 passed: Home, latency, setup, connection, protocol, service bridge, Android manager. |
| `flutter analyze --no-fatal-infos` | No errors/warnings; one pre-existing const-constructor info in `test/widgets/scrollbar_inset_test.dart:18`. |
| Go wrapper tests and vet | Passed with `CGO_ENABLED=0`, dropping `CAP_CHOWN` for the existing non-root ownership assertion. The unrestricted-root run fails that assertion because root can chown the fixture. No Core coverage instrumentation. |
| Probe tests | Real loopback normal/slow HTTP, silent deadline and refused sockets, plus failure classification/wire compatibility. |
| Portable Kotlin/JVM | 102 passed using real state-machine/model, module lifecycle/gate and registry sources with an interface-only host scaffold. Not an Android framework/binder/plugin build. |
| Formatting, comment density, diff whitespace, strict OpenSpec validation | Passed. |

Actual VPN-key/foreground notification removal, OS route/FD/socket cleanup, Always-on, process termination and native UI rendering still require CI-built artifacts and devices. See `validation.md` for acceptance cases. No commit or push was requested or performed for this round. Unrelated pre-existing OpenSpec/Claude skill files were preserved.

## Initial redesign available-host verification (historical)

Progress: 37/39 tasks complete. Implementation, documentation, and task 8.2 are complete. Task 8.3 stays open because the touched Android modules/Flutter service bridge could not be compiled against an Android SDK; task 8.4 stays open because actual platform smoke tests could not run. On 2026-09-21 the user approved handing these checks off to CI-built artifacts and later manual testing outside this development VPS. Native validation is deferred, not passed; no native environment provisioning on this host is required for the development handoff. The change is not archived or declared fully verified.

| Check | Result |
| --- | --- |
| `flutter pub get` | Passed with the pinned toolchain/dependency constraints. |
| Model/provider/Drift generation and four-locale generation | Passed; generated outputs were not manually edited. |
| Repository `dart format --output=none --set-exit-if-changed lib test tool plugins setup.dart` | Passed, 599 files unchanged at the full-run checkpoint. |
| `flutter analyze --no-fatal-infos` | No errors or warnings; one pre-existing `prefer_const_constructors` info at `test/widgets/scrollbar_inset_test.dart:18`. |
| Full `flutter test --reporter expanded` | **2,049 passed, three skipped**, exit 0. |
| Final recovery/import/restore regression run | **48 passed** after the final post-commit recovery-read guard and invalid-manual-input cancellation change. A recovery-check read failure cannot turn a durable successful commit into an “import failed” result. |
| Final Apply/intake/cleanup focused run | **17 passed**. |
| Go wrapper tests and `CGO_ENABLED=0 go vet .` | Passed; tests compiled then executed unprivileged for the ownership test. No coverage instrumentation. |
| Changed fork packages with `go test -race` | `config`, `adapter/provider`, `component/resource`, `listener`, `rules/provider` all passed. |
| Portable Kotlin/JVM state/arbitration/model compilation and tests | **61 passed**, with an interface-only service-host scaffold. Not a native Android application build. |
| Proxy plugin tests | **21 passed**. No local plugin implementation was changed. |
| Comment-density gate | Passed after removing unused OpenSpec template comments. |
| OpenSpec strict validation | Passed. |
| `git diff --check` | The initial tracked-file check reported four whitespace-only warnings in `profile.freezed.dart` and `state.freezed.dart`; the pre-commit staged check includes ten more in the newly added `vpn.freezed.dart`. All 14 are pinned Freezed output; generated formatting-off files were not hand-edited. |
| Android build attempt | Blocked before compilation: Android SDK not installed. |
| Linux build attempt | Blocked: CMake absent; doctor also reports missing clang/Ninja/GTK, and AppIndicator development files are absent. No GUI is available. |
| Real Android/Windows/macOS/Linux smoke checks | Not run. `validation.md` records exact checks, coverage boundaries, and prerequisites. |

The native checks above remain production-release gates; the user will test build artifacts later. The artifact prerequisites and current workflow publication behavior are recorded in `validation.md`. No new commit, push, tag, workflow dispatch, or workflow change was made for this handoff. The obsolete `KeepScope` helper was removed after its last use disappeared; it remains recoverable from Git history. Existing OpenSpec skill/Claude files outside this implementation were preserved.

The descriptions and measurements below are historical checkpoints.

## Restore and integration checkpoint

Progress: 36/39 tasks complete. Tasks 4.5, 5.3, 8.1, and 8.5 are now complete. Final whole-project verification (8.2) is running; Android module compilation (part of 8.3) and actual native smoke tests (8.4) remain unverified.

- All retained imports, profile-content edits, override Save, Apply saved configuration, and provider/subscription refresh use the same staged replacement contract. The obsolete app-shell refresh timer and unused append helpers were removed. Shared rules/scripts remain separately saved libraries; applying them rebuilds the immutable snapshot explicitly. Configuration-only runtime controls keep their existing serialized update path.
- Backup uses a verified archive with a consistent SQLite snapshot and generation/provider/geodata resources. Restore has private extraction paths, path/size validation, deterministic one-profile fallback, fresh shared identities, and an atomic database publication record for restored settings/scripts. No source files are copied over the live setup during decoding. Schema 5 persists publication for crash repair; pending publication blocks later replacement. Library fingerprints reject concurrent edits, and cleanup serializes with commits/publication.
- Restore tests cover preparation/activation/database failures, settings-only backups, both shared-data strategies, a newer import winning, post-commit preference repair, and an offline backup/export/decode/restore round trip containing provider and geo files. The focused restore/archive/draft run passed 46 tests before later path/metadata guards; the integrated follow-up passed its production flow and exposed only stale schema-version expectations and two widget-fixture issues, which were corrected.
- The production-adapter integration imports a token-bearing URL, selects a server, connects from native observations, replaces while running, rejects a failed replacement without changing runtime bytes/profile, and disconnects. `validation.md` maps all 52 specification scenarios to automated coverage or explicit named native smoke checks.
- The two new Apply widget tests pass after creating their completion gate in the widget test's async zone. Analyzer has no errors/warnings and only the pre-existing scrollbar-test info. The Go wrapper suite, vet, changed-fork race suites, and 61 portable Kotlin/JVM tests pass. Full Android compilation and GUI/device tests have not run; `flutter doctor -v` confirms missing prerequisites.
- `VPN_GUIDE.md`, both README entry points, and `.agents/architecture.md` describe the implemented behavior and limitations. No disclaimer UI/text was reintroduced. No new commit or push was made.

Older checkpoints below are historical; they do not describe remaining work at this checkpoint.

## Home, connection observation, and editor checkpoint

Progress: 32/39 tasks complete. Tasks 5.4, 6.1–6.4, and 7.1–7.7 are implemented. Tasks 4.5 and 5.3 remain open for shared settings/script/rule writers and transactional backup restoration; final integration/platform verification and documentation remain open under section 8.

- Home now provides explicit manual/paste/QR intake, a central connect/disconnect control, observed status, and one independently scrollable Auto/Fallback/server list. Responsive layouts, large text, keyboard activation, selection persistence across resizing, and pushed Settings navigation have focused coverage.
- Android publishes passive, session/revision-scoped service observations. Desktop publishes actual listener/TUN state, and the proxy manager reports installation/removal outcomes. Core readiness and optimistic start acknowledgements cannot claim an established VPN. Suspension, permission failures, external stops, proxy-only mode, restart intent, failed recovery, and late proxy installation are covered without adding lifecycle ownership to Home.
- Fresh-install VPN/TUN defaults apply on explicit Connect. Imports do not request VPN permission. Failed defaults persistence remains retryable, and failed recovery prevents a new start while still permitting Stop.
- Settings offers replacement, coordinated refresh/edit, original-source export, verified migration-archive export, recovery, custom routing, existing advanced settings, and diagnostics. Persistent exports use a non-deleting helper; the old temporary-file export helper is unsuitable for immutable source/archive files.
- Profile-specific override editors now hold a draft until explicit Save. Candidate rules/groups feed preparation and join the profile transaction after activation. Failed saves retain the draft; leaving does not apply it. Group renames update draft references. A concurrent committed-profile or metadata change rejects an old draft. Direct managed-profile metadata helpers no longer publish optimistically, and managed rules reject writes outside an editor.
- Shared global rules/scripts and backup restore have not yet been brought into this contract. This checkpoint is not a claim that task 4.5 or 5.3 is complete.

Verification at this checkpoint:

- 229 connection, QR, bridge, protocol, and desktop lifecycle tests passed; 88 Home/intake/tray/export/setup tests passed before the two additional Home tests.
- 62 production-adapter/coordinator/migration/Home tests passed after editor integration, including delayed activation, failed override preparation, metadata supersession, and resizing.
- The expanded editor/provider/manager run passed 125 tests with one localization-initialization test-fixture failure. After correcting that fixture, all 76 setup/action/export tests passed. The draft-provider, nested editor, preview, and proxy-disposal tests passed in the expanded run.
- Full Go wrapper tests passed using the existing unprivileged harness, and `CGO_ENABLED=0 go vet .` passed. Portable Kotlin/JVM service/state/arbitration tests passed all 61 cases. Full Android application compilation and real device/desktop OS integration smoke tests remain unavailable/unperformed.
- Model/provider/Drift and four-locale output regenerated. Analyzer reports no errors/warnings; a final whole-project test run and lint pass are still required after the remaining writers and restore implementation.

Earlier checkpoints below record historical results, not completion claims for the current whole change.

## Completed

Progress: 5/39 tasks complete (1.1–1.4 and 2.1).

- Backward-compatible snapshot models retain typed selection, routing preference, revision, generation, and cached catalog metadata.
- Schema version 4 persists snapshots and the single-profile commit/migration state. Awaited repository transactions replace profile-owned data, preserve shared data, reject stale revisions, and enforce sole-profile cardinality after migration. Schema upgrade alone does not prune legacy profiles; committing their migration requires an archive reference from the migration coordinator.
- Request-owned generation directories support sealed manifests, checksummed resources, flushed journal/runtime writes, revision-based recovery decisions, and protected cleanup. Legacy source reads remain supported, but generation-backed files cannot be overwritten through legacy save methods. Physical power-loss durability has not been tested; interruption tests model application termination at file/commit boundaries.
- Typed prepare/activate/discard requests cross the Dart facade and shared Go dispatch, with one fixture checked in both languages.

Verification:

- Full `flutter test --reporter expanded`: 1,875 passed, 3 skipped at the storage/protocol checkpoint, before the subsequent URL-intake and immutable-provider-refresh additions. `flutter pub get` completed without changing the dependency manifests/lockfile.
- `flutter test test/core/protocol_contract_test.dart test/models --reporter expanded`: 112 tests passed before the later generation-path test was added.
- `flutter test test/database --reporter expanded`: 38 tests passed, including schema v3→v4, durable migration state, sole-profile enforcement, shared-data preservation, stale revisions, and a transaction failure after replacement writes.
- `flutter test test/common/profile_store_test.dart test/models/profile_save_test.dart test/providers/store_action_test.dart --reporter expanded`: 22 tests passed. Includes interruption around resource flush, journal flush/publication, runtime replacement, database commit, journal removal, and generation-aware reads/cleanup.
- Fork configuration/provider/resource suites passed under `CGO_ENABLED=1 go test -race`. Detached parsing preserves live mode, resolver/dialer settings, proxy names, matching connections, and provider events during preparation/failure/discard; activation reuses staged data. Scoped geodata refresh tests preserve private generation bytes and last usable matchers after invalid updates.
- Full Go wrapper tests passed as an unprivileged process after compiling with `CGO_ENABLED=0 go test -c`; `CGO_ENABLED=0 go vet .` passed. The existing ownership test assumes non-root execution and fails when run directly as root, because root can perform the intentionally forbidden `fchown`.
- `flutter analyze --no-fatal-infos`: exit 0; one existing `prefer_const_constructors` information-level finding at `test/widgets/scrollbar_inset_test.dart:18:24`.
- Generation also synchronized existing stale enum mappings in `lib/models/generated/clash_config.g.dart`; its source was not changed. The action generator hash now also reflects the generation-aware cleanup change.
- Focused Dart formatting passed without changes. `git diff --check` reports two trailing-whitespace lines emitted by Freezed in `profile.freezed.dart`; its generated `dart format off` directive leaves them unchanged. Generated output was not manually edited.

Core preparation/activation is partially implemented but not yet connected to normal profile imports. Task 2.2–2.5 remain unchecked: production staging integration, activation outcomes/rollback, and remaining lifetime/source-resolution work are unfinished. No commit or push has been made for this implementation.

The subsequent domain checkpoint completes tasks 3.1, 3.2, and 4.1–4.3 (10/39 total). Shared intake preserves URL credentials/encoding; inventory retains source ordering and qualified identities; managed groups use provider-specific aliases. Shared Dart/Go YAML fixtures verify actual target resolution, identical Auto/Fallback inventories, and reject-only empty fallback. Hidden group names avoid source proxy, group, and provider identifiers. Source rules, protocol fields, and advanced selections survive simple/custom effective builds.

The stager downloads confined provider resources and needed private geodata, probes a private `candidate.yaml`, discards the non-activatable probe, and prepares/seals the final `effective.yaml`. Probe/final catalogs must match. It never activates or publishes a profile. Core preparation namespaces provider runtime/cache identities while source-facing lookups retain original names. Generation-aware setup does not fall back to the root configuration or the built-in default.

The coordinator uses a supplied setup scheduler and activation/restoration adapters. It journals before activation, commits the database last, restores old runtime bytes/configuration on failure, retains the journal/resources when recovery fails, and treats post-commit mirror failure as repairable maintenance. Explicit imports supersede older imports even if the newer intake fails; automatic refresh cannot overtake an explicit import. Cancellation and disposal invalidate pending work. These domain components are tested with actual generation storage/Drift and fake HTTP/Core adapters; production SetupAction/CoreManager wiring is task 4.4 and remains unfinished. Migration/restore, observed connection state, and Home/Settings remain unimplemented.

Additional verification at this checkpoint:

- 43 focused Dart routing/intake/model/protocol tests passed.
- 39 coordinator/staging/repository/storage tests passed, including HTTP, invalid configuration, disk, activation, database, cancellation, supersession, failed restoration, and failed preference publication.
- Full compiled Go wrapper tests passed unprivileged and `CGO_ENABLED=0 go vet .` passed after the generation loader and missing-geodata protocol additions.
- Changed fork configuration/provider/resource race suites passed after the namespace/refresh changes; the later strict classical-rule error propagation should be included in the next race run.
- `flutter analyze --no-fatal-infos` passed with only the existing scrollbar test information-level finding. `yaml` 3.1.3 moved from a dev dependency to a runtime dependency for staging; no package version changed.

## Application-adapter checkpoint

Progress: 15/39 tasks complete. Tasks 2.2–2.5 and 4.4 are now implemented and verified. The normal import/edit/refresh entry points still need task 4.5; migration/restore and the new interface are not enabled yet.

- `VpnAction` constructs the production coordinator around the existing `SetupAction` queue, actual Core facade, repository, and generation store. Committed publication includes managed selections and generation/revision in Android shared state. Older database emissions cannot overwrite a published newer snapshot, and `CoreManager` does not apply it again.
- Preference persistence reports failure; committed imports retain a repairable journal. A subsequent import repairs an in-process mirror failure without reactivating the preceding commit. Startup recovery remains to be integrated before auto-start in task 5.2.
- Explicit cancellation before async coordinator creation is respected. Configuration-setting changes invalidate pending imports. A specifically typed stale-handle response permits one local re-preparation; other activation failures are not retried as if they were stale handles.
- Generation-aware setup reads and verifies the immutable effective configuration, preserves simple GLOBAL routing, and does not rebuild or overwrite its source/provider files. Disconnected setup does not ask for TUN authorization.
- Native listener setup now reports errors instead of silently accepting failed binds. A failed candidate is consumed; restoring the prior immutable generation rebinds its listener. Missing restoration resources report failure rather than applying the root/default configuration. Custom named/tunnel listeners and iptables run only under the existing native running intent, and stop releases them. Invalid iptables setup returns an error rather than exiting the process.

Verification at this checkpoint:

- 83 state/database/config-generation tests passed, including managed native selections, stale profile-stream suppression, and no provider-cache mutation during staging.
- 75 coordinator/manager/setup/preferences tests passed, including no duplicate setup on publication and rejection of late legacy provider events.
- 55 production-adapter/coordinator/setup tests passed after generation-aware setup was added.
- The full compiled Go wrapper suite passed unprivileged; `CGO_ENABLED=0 go vet .` passed. Fork listener/config/resource/proxy-provider/rule-provider suites passed with the race detector, including the later strict classical-rule error propagation.
- Analyzer passed with only the pre-existing scrollbar-test info before the latest setup/archive additions. Full final verification is still pending. Android device and desktop OS integration smoke tests have not run.

## Migration, selection, and app-owned refresh checkpoint

Progress: 20/39 tasks complete. Tasks 3.3–3.5 and 5.1–5.2 are implemented. Advanced editor/restore writers, confirmed platform connection state, and the Home/Settings interface remain unfinished.

- Startup creates and verifies a private archive containing a consistent SQLite export, settings, source/provider/generation files, scripts, and cached geodata before removing any legacy rows. Offline migration prefers the selected usable profile, falls back deterministically, preserves fetch timestamps and compatible manual selection, and retains all archives outside cleanup. Archive, disk, or Core availability failures preserve legacy records and remain retryable.
- Recovery runs before automatic setup or refresh; an interrupted legacy activation restores the previous runtime bytes and selections. Bootstrap no longer rewrites profile order before archiving. A disconnect requested during initialization prevents later automatic connection.
- Normal URL/file imports and profile URL/content edits now await coordinated replacement. The edit view retains the form on failure, disables duplicate saves, and cancels its own request on disposal. Advanced overwrite editors and backup restoration still require task 4.5/5.3 work.
- Simple/custom routing changes stage offline generations and retain independent advanced selections. Managed selection RPCs serialize with commits, check content and selection revisions, await database persistence, handle explicit Core rejection, and restore the previous runtime after failed/superseded selection. Offline selection is included in the next setup parameters.
- Each HTTP provider's interval and successful-fetch timestamp is stored with the snapshot. Flutter schedules subscription/provider refreshes, fetching only due provider resources, pausing on detach/disposal, and resuming due work on attachment. Native content writers remain disabled for managed generations; reachability health checks/failover are unchanged. Manual provider update/side-load uses staged replacement. A removed selected server changes to Auto only after successful commit and displays localized feedback.

Verification:

- 80 production-adapter/setup/profile-action tests passed after import/edit and initialization wiring.
- 176 tests passed in the migration/archive/staging/provider/setup/manager run; three scheduler test-harness failures were corrected (explicit zero-duration timer pumping and disposal before widget invariants). The isolated scheduler suite then passed all 5 tests.
- 66 selection/production-adapter/scheduler/snapshot-model tests passed, including rapid A/B selection, rejected selection, old-profile requests, custom/simple round trips, failed/empty refresh preservation, removal fallback, and provider side-load without native mutation.
- Model/provider/Drift and localization output regenerated. Final whole-project verification remains pending.

## Design issue: candidate parsing changes active process state

The original decision 4 excluded changes to the vendored Core and proposed containing parser side effects in the FlClash wrapper. Serializing wrapper operations does not isolate a candidate from traffic-processing goroutines. The approved adjustment below supersedes that original assumption.

Evidence at pinned Mihomo revision `70f0570405c3c2c47bb113b88db95006d239b346`:

- `core/Clash.Meta/config/config.go:633` temporarily applies candidate general settings during `ParseRawConfig`.
- `core/Clash.Meta/hub/executor/executor.go:388` delegates that operation to `updateGeneral`, which changes the live tunnel mode at line 397 and also changes resolver, dialer, and other process-global settings. A deferred rollback cannot undo traffic decisions made during parsing.
- `core/Clash.Meta/config/config.go:992` publishes candidate proxy names before subsequent rule validation. Failed parsing does not restore that list.

A standalone diagnostic process used only synthetic SOCKS5 endpoints at `127.0.0.1:1080`, with no live VPN or user configuration. Starting from rule mode and a proxy-name list containing `Existing`, it parsed a candidate with `mode: direct`, 10,000 synthetic proxies, and an invalid final rule. A concurrent observer checked the tunnel mode during the parse. The full parser rejected the candidate, but the observer saw direct mode and the published names remained changed:

```text
parse rejected candidate: true
error: rules[0] [INVALID-RULE,example.test,DIRECT] error: unsupported rule type: INVALID-RULE
observed candidate DIRECT mode during failed preparation: true
mode after failed preparation: rule
proxy names after failed preparation: count=10002 first=[DIRECT REJECT Candidate0]
```

The diagnostic was run with `CGO_ENABLED=0 go run /tmp/flclash-parser-check.nExD8A/main.go` from `core/`. Its temporary source is a local investigation aid, not a required build input or an automated regression test. This reproduces process-state mutation; it does not claim real user traffic was sent directly during the diagnostic.

## Approved adjustment

On 2026-09-21 the user approved updating the design and continuing with the narrowly scoped Core preparation feature below. Design decision 4, the proposal impact, and tasks 2.2–2.3 now include this scope. The user-visible requirements are unchanged.

Permit a narrowly scoped candidate-preparation feature in the maintained `core/Clash.Meta` fork, instead of assuming the wrapper alone can isolate the existing parser. This is a new preparation capability required by the failure-preservation contract, not an unrelated upstream bug repair or a transport/engine replacement.

The adjusted design should provide a detached preparation path with candidate-local parsing settings and owned resources. It must not publish tunnel mode, proxy names, resolver/dialer settings, provider events, or background work into the active runtime. Explicit activation is the publication boundary; discard and every error path release candidate-owned resources. Existing normal apply behavior and platform lifecycle ownership must remain intact.

Add deterministic tests that inspect active state while preparation is in flight, after rejection, and after discard, including an invalid late rule, provider-name collisions, candidate resource cleanup, and activation of a valid prepared candidate. Merely asserting the restored final mode would miss the reproduced failure.

An isolated validation process is an alternative, but it changes the cross-platform architecture and cannot transfer a prepared in-memory candidate directly into the existing Core. It should not be substituted silently for the planned prepare/activate contract.

Implementation resumes with the approved detached-preparation scope; no task is complete until its implementation and verification are finished.

## Approved decision: provider refresh while Flutter is absent

The immutable-generation requirement also applies after activation. Native provider refresh currently bypasses the planned Drift/coordinator commit:

- `component/resource/fetcher.go` starts the provider timer/watcher from `Initial`; `Update` and `SideUpdate` call `loadBuf` with file writes enabled, then publish changed provider contents.
- `component/resource/vehicle.go` writes the same provider path with `os.WriteFile`. Pointing that path at a sealed generation means a later successful refresh invalidates its manifest without a new committed profile/catalog revision.
- Android `MainActivity.onDestroy` detaches Flutter from `ServiceState`; `ServiceStateHost.detachFlutterEngine` clears the Flutter reference without stopping the native service. Native refresh therefore has a lifetime beyond the Dart coordinator.

The design permits coordinated provider refresh or a validated inventory revision, but it does not specify who can durably commit such a revision when Flutter is absent. Merely suppressing loaded-provider events would not stop the file mutation. Merely disabling native timers would silently remove that background behavior.

Requested choice:

1. Route provider refresh through the app coordinator and pause refresh while Flutter is absent. Keep the current VPN snapshot usable and refresh when the app returns. This is the simpler recommended design, but its closed-app refresh behavior needs explicit approval.
2. Preserve provider refresh after the Android UI/engine closes, adding native/headless coordination that still respects one authoritative commit/recovery protocol. This expands the background architecture beyond the approved detached-parser feature.

On 2026-09-21 the user selected option 1: pause content refresh while Flutter is closed and keep the current VPN configuration working. The design, unified-server-selection spec, and task 3.5 now require this policy. Native health checks and Auto/Fallback failover continue; only content refresh moves to the app coordinator. Implementation resumes without adding a background commit owner.

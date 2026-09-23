# Validation and platform handoff

This matrix names coverage for every delta-spec scenario. Automated tests use temporary files/SQLite and fake HTTP/Core/platform boundaries unless explicitly identified as Go or JVM tests. They do not replace native GUI/device smoke tests.

## 2026-09-23 archive acceptance

[CI run 35728945241](https://github.com/phungvanquy/FIClash-new/actions/runs/35728945241) for commit `6a0ceff692481851a0fe654363964a9002883045` completed successfully. Dart, Go core, Plugins, Android unit tests, Rust, Windows helper tests, and Android/Windows artifact builds all passed. Release publication was intentionally skipped. This supplies the compilation and automated checks required by task 8.3; earlier statements about unavailable local toolchains remain historical host limitations, not missing CI results.

The user reported successful testing on 2026-09-23 and approved synchronization and archive with the unverified smoke-test matrix deferred. The report did not enumerate devices, OS versions, or individual scenarios, so no blanket Android/Windows/macOS/Linux scenario pass is inferred. Task 8.4 remains unchecked as the explicit follow-up record, including native screen-reader, revoke/Always-on, failover, backup interruption, and platform-specific scenarios without recorded results. The matrices below retain their per-host evidence and pending procedures.

## Compact Home and sticky current node

`test/pages/home_test.dart` covers compact header/row proportions, named 48-pixel touch targets, retained keyboard actions, sticky-node/list bounds before and after scrolling, observed-node changes without selection commands, immediate card removal outside Connected, light/dark connected glow, error interruption, reduced motion, and long names at 250% text scaling in narrow/short/wide windows. Existing current-node and latency provider suites cover stale observation rejection and non-mutating single-flight probes. Settings navigation and committed selection remain covered. Local light/dark Flutter-rendered previews were visually inspected with fonts and shadows enabled; these are not native-device screenshots.

For Android and Windows artifacts, verify all of the following under native screen readers, keyboard/touch input, both themes, and reduced motion:

- Import, connect, scroll far down the inventory, and force Auto/Fallback failover. The card stays above the rows, names Core's current outbound, and never overlaps content or changes selection. Disconnect/error removes it immediately.
- Use long server/provider names and 250% text scaling; rotate a phone and resize a short desktop window. Controls remain scrollable, rows stack latency where needed, and full names are available through tooltip/semantics. The latency toolbar stays reachable even at the bottom of a long list.
- Confirm the connected glow is soft and static, color changes are brief, status/action guards do not wait for animation, and reduced motion removes decorative transitions. Repeated Connect/Disconnect/Test taps still do not submit duplicates.
- Check bold measured latency and explicit failure states, selected-row feedback, Settings width/back navigation, and unchanged active traffic while scrolling, measuring, or opening Settings.

Native rendering, assistive technology and actual tunnel behavior remain deferred artifact gates; no native pass is inferred from widget tests.

## Deferred native validation and artifact handoff

On 2026-09-21 the user approved continuing with this VPS as a development-only host and testing CI-built artifacts on native devices later. Native compilation and smoke checks are deferred, not assumed to have passed. Tasks 8.3 and 8.4 stay open until their results are recorded; missing local SDKs, GUI sessions, and devices do not require further provisioning here.

The current `.github/workflows/build.yaml` provides this handoff:

- Branch pushes run validation jobs, including Android JVM tests. Pushes to `main` and manual `workflow_dispatch` runs additionally build Android and Windows after every prerequisite job succeeds.
- Test builds upload `artifact-android` and `artifact-windows-amd64` from `dist/`, use the `pre` application environment, and do not publish a release. Android test APKs use debug signing, so they may not install over an existing release with a different signing key; export a backup before changing installations.
- `v*` tag pushes retain Android, Windows AMD64, and Linux AMD64 artifacts and release publication. Tags containing a hyphen publish a prerelease; other matching tags publish a regular release. Manual runs never publish, even when targeting a tag. The matrix has no macOS build, so macOS verification needs a separate host/build.
- On 2026-09-22 the user provided `phungvanquy/FlClash-core` for the modified Core. The app pins Core commit `10a96da7b65faf1f1c4afd764ec115c333021c1d`; `.gitmodules` uses the public HTTPS repository URL and `main` branch so CI can fetch it without a cross-repository SSH key. Future Core changes must be pushed there before the app's new submodule reference is pushed.

After a build is available, record the parent and submodule commit IDs, CI run/artifact, device/OS, and results for A1/A2, D1/D2 per tested desktop platform, and R1 below. A green build establishes compilation, not successful device behavior. Keep untested paths explicit and complete native validation before treating the redesign as production-ready.

## Single-profile import

Paths below are relative to `test/` unless prefixed with `core/`.

| Spec scenario | Coverage |
| --- | --- |
| Equivalent inputs | `common/vpn_intake_test.dart`, `widgets/vpn_import_test.dart`, `common/vpn_qr_test.dart`, `common/link_test.dart`; installation-link native launch: D1 |
| Unsupported or empty input | `common/vpn_intake_test.dart`, `widgets/vpn_import_test.dart` |
| Clipboard privacy | `widgets/vpn_import_test.dart`, `pages/home_test.dart` |
| First successful import | `providers/vpn_action_test.dart`: import/select/connect integration and single activation; `pages/home_test.dart` |
| Replacement succeeds | `providers/vpn_action_test.dart`, `common/vpn_coordinator_test.dart`, `database/single_profile_test.dart` |
| Empty or semantically invalid configuration | `common/vpn_staging_test.dart`; `core/prepared_test.go`, fork `config/prepared_test.go` |
| Required provider fetch fails | `common/vpn_staging_test.dart`, `common/vpn_coordinator_test.dart`; fork provider preparation tests |
| Failed replacement while connected | `providers/vpn_action_test.dart`: integrated failed download while running; `common/vpn_coordinator_test.dart`; real traffic: D2/A2 |
| Final storage or activation failure | `common/vpn_coordinator_test.dart`, `providers/vpn_action_test.dart`, `database/single_profile_test.dart`, `core/prepared_activation_test.go` |
| First import fails | `widgets/vpn_import_test.dart`, `providers/vpn_action_test.dart` |
| Replacement while running | `providers/vpn_action_test.dart`: integrated connected replacement; native traffic continuity: D2/A2 |
| Disconnect during import | `providers/vpn_action_test.dart`: disconnect during activation; `providers/setup_action_test.dart` |
| Newer import fails before an older one completes | `common/vpn_coordinator_test.dart`, `providers/vpn_action_test.dart` |
| Refresh overlaps replacement | `common/vpn_coordinator_test.dart`, `providers/vpn_action_test.dart` |
| Process interruption during commit | `common/profile_store_test.dart`, `common/vpn_coordinator_test.dart`, `common/vpn_migration_test.dart`, `providers/backup_action_test.dart` publication repair; OS/process smoke: R1 |
| Existing user upgrades offline | `common/vpn_migration_test.dart`, `common/vpn_archive_test.dart`, `database/migration_v4_test.dart` |
| Selected legacy profile is missing | `common/vpn_migration_test.dart` |
| No legacy profile is usable | `common/vpn_migration_test.dart`, `pages/home_test.dart` |
| Restore contains several profiles | `providers/backup_action_test.dart`, `common/backup_task_test.dart`; new generation/provider/geodata archive round trip uses the real archive reader and coordinator |

## Unified selection

| Spec scenario | Coverage |
| --- | --- |
| Flutter closes while the VPN remains connected | `common/vpn_refresh_test.dart`; wrapper/fork immutable provider tests; native continuation/health checks: A2/D2 |
| Flutter resumes with a refresh due | `common/vpn_refresh_test.dart`, `providers/vpn_action_test.dart` |
| Configuration contains nested groups and provider servers | `common/task_test.dart`, `core/prepared_inventory_test.go`, shared `fixtures/vpn_inventory.yaml` |
| Subscription uses an automatic-mode label as a server name | `common/task_test.dart`, `pages/home_test.dart` identity/disambiguation |
| Imported configuration has no automatic groups | `common/task_test.dart`, `core/prepared_inventory_test.go`, shared `fixtures/vpn_managed.yaml` |
| Automatic mode changes its underlying server | Stable mode identity in `providers/proxies_action_test.dart`; live URL-test/Fallback transitions: A2/D2 |
| No server responds to health checks | Reject-only generated groups in `common/task_test.dart` and `core/prepared_inventory_test.go`; confirmed local state in `common/vpn_connection_test.dart`; blocked-remote smoke: A2/D2 |
| Subscription contains a different default outbound | `common/task_test.dart`, `providers/vpn_action_test.dart`, `core/prepared_inventory_test.go` actual managed target resolution |
| New profile is imported | `providers/vpn_action_test.dart`, `common/vpn_coordinator_test.dart` |
| User enables configuration routing | `pages/home_test.dart`, `providers/vpn_action_test.dart` simple/custom round trip |
| User returns to simple selection | `providers/vpn_action_test.dart`, `providers/proxies_action_test.dart`, `pages/home_test.dart` |
| Select before connecting | `providers/vpn_action_test.dart`: integrated select/connect; `providers/proxies_action_test.dart` offline persistence |
| Selection fails while connected | `providers/proxies_action_test.dart` rejected RPC and rollback |
| Rapid selections overlap | `providers/proxies_action_test.dart` late selection supersession |
| Open without network access | `pages/home_test.dart` cached catalog; `common/profile_store_test.dart`, `providers/vpn_action_test.dart` sealed setup |
| Selected server is removed by a successful refresh | `providers/vpn_action_test.dart` refresh/removal/Auto notification |

## Simplified interface

| Spec scenario | Coverage |
| --- | --- |
| First launch | `pages/home_test.dart`, `widgets/vpn_import_test.dart` |
| Successful onboarding | `pages/home_test.dart`, `widgets/vpn_import_test.dart`, integrated `providers/vpn_action_test.dart` |
| Camera permission is denied | `pages/scan_test.dart`; real permission dialog: A1 |
| Desktop user imports a QR image | `common/vpn_qr_test.dart`: real PNG/JPEG decoding with fake picker; native picker: D1 |
| Scanner detects the same code repeatedly | `pages/scan_test.dart` one-shot submission |
| Long server list | `pages/home_test.dart` independent list scrolling and large catalog |
| No usable profile | `pages/home_test.dart` missing generation/recovery guards |
| Core is ready but VPN is off | `common/vpn_connection_test.dart`, `pages/home_test.dart` |
| Start awaits platform permission | `providers/setup_action_test.dart`, `common/vpn_connection_test.dart`; portable `android/tests/app/ServiceStateMachineTest.kt`; native prompt: A1/D1 |
| Permission or startup fails | Same state/setup/JVM suites; `manager/proxy_manager_test.dart`; native permission failure: A1/D1 |
| Desktop falls back to proxy-only operation | `common/vpn_connection_test.dart`, `providers/setup_action_test.dart`, `manager/proxy_manager_test.dart`; real OS proxy/TUN: D1 |
| Cancel an in-progress connection | `providers/setup_action_test.dart`, `pages/home_test.dart`, Android JVM arbitration and `core/desktop/` lifecycle tests |
| Stop from outside Home | `plugins/service_test.dart`, `common/vpn_connection_test.dart`, Android JVM revoke/service-loss tests; notification/tile/tray: A1/D1 |
| Start is requested after incomplete teardown | `android/tests/app/ServiceStateMachineTest.kt`: partial VPN/proxy cleanup, zero runtime, permission denial/service loss, blocked background preparation, explicit stop retry then start |
| Delayed cleanup resolves a stop failure | Same JVM suite: resolved stop error, repeated cleanup failure, retained configuration failure, newer start superseding cleanup; real service teardown: A1/A2 |
| Open advanced options | `pages/home_test.dart`, `widgets/tv_search_back_test.dart`, `common/tray_menu_test.dart` |
| Back from Settings | `pages/home_test.dart`, `widgets/tv_search_back_test.dart` |
| Large text and assistive technology | `pages/home_test.dart`, `widgets/vpn_import_test.dart`, localization/lint suites; native screen reader: A1/D1 |
| Resize a desktop window | `pages/home_test.dart`, window/header/widget suites; native chrome/focus: D1 |

Additional writer/restore guards: `providers/profile_draft_test.dart`, `features/overwrite_view_test.dart`, `views/vpn_configuration_test.dart`, `providers/backup_action_test.dart`, `database/single_profile_test.dart`, and `common/backup_task_test.dart` cover unpublished drafts, explicit Apply, cancellation/disposal, script/settings publication repair, concurrent library edits, restore strategies, and archive path rejection.

## Native smoke checks still required

### Post-build review acceptance

The 2026-09-22 feedback adds these checks. They apply to the next build containing this working-tree revision, not the earlier successful CI artifact.

| Scenario | Automated coverage | Device acceptance still required |
| --- | --- | --- |
| Import/update/replacement stage feedback, cancellation cleanup and final commit guard | `widgets/vpn_import_test.dart`, `views/vpn_configuration_test.dart`, coordinator/action suites | Use a slow disposable subscription on Android/Windows; verify stage text, counts, disabled repeated actions, cancellation cleanup, back/outside-tap handling, timeout retry, and narrow/large-text layout |
| Geographic cache reuse, expiration, source change, corruption and offline backup compatibility | `common/vpn_staging_test.dart`, `common/profile_store_test.dart`, `providers/backup_action_test.dart` | Compare first versus repeated update stage timings for a geodata-using configuration; confirm successful/failed connected replacement, provider traffic and active node remain correct; restore an old and new backup offline |
| Per-resource download deadlines and failed provider queue | `common/request_test.dart`, `common/vpn_staging_test.dart`, `common/vpn_coordinator_test.dart` | Slow/black-holed network while VPN is connected: transfer ends with retry guidance, old profile persists, and no unexpected reconnect. Overall operation may exceed 90 seconds because the deadline is per transfer, not per transaction |
| Import leaves Android Checking connection | Explicit wire keys/default STOPPED/all states in `ServiceStateMachineTest.kt`; malformed/default bridge snapshots in `plugins/service_test.dart`; bounded/coalesced recovery in `providers/android_status_test.dart`; Home retry/disconnect UI | Install the minified release artifact; import then Connect/Disconnect, close/reopen, airplane mode, and retry a failed status check. Confirm no permanent Checking state or inferred Disconnected |
| Prominent delay and bright green successful connection | Home light/dark badge/foreground and bold milliseconds assertions; large-text/narrow widget tests | Android/Windows light/dark readability, large text and screen reader |
| Current node in manual/Auto/Fallback and custom routing | `providers/vpn_active_node_test.dart` tests raw Core targets, alias identity, automatic changes, wrong generation/session, cycles, timeouts, failures, background/resume, replacement and disposal; Home node/mode/custom copy | Force real Auto/Fallback failover; compare Core's selected target and new traffic; verify old sessions may retain old routes and read-only refresh does not interrupt them |
| Green connected / gray disconnected, transitions, error retry, repeated taps | `pages/home_test.dart`, `common/vpn_connection_test.dart` | Light/dark, small window, Android large text/TalkBack and Windows keyboard |
| Normal/slow probes, timeout, unreachable, test failure | `providers/vpn_latency_test.dart`, `core/delay_failure_test.go` (real loopback HTTP, delayed response, silent socket, refused connection), model/protocol suites | Real nodes on Wi-Fi/mobile data; offline and reconnect; verify ms values and retry |
| Duplicate batch, bounded probes, fastest without selection changes | Provider/widget latency suites | Keep a transfer running on a pinned server while testing; route and transfer must not reset |
| Late result after profile/test-URL/Core change or disposal | `providers/vpn_latency_test.dart` | Replace configuration during a slow batch, reopen, verify no old measurements |
| Partial startup, repeated stop, failed stop/retry, delayed startup superseded by stop | `android/tests/app/ServiceStateMachineTest.kt`, `providers/setup_action_test.dart` | Foreground and background repeated connect/cancel/stop; no unexpected reconnect |
| Start after partial teardown and delayed cleanup recovery | State-machine failure injection: retained timer is not a healthy service, cleanup success clears only the stop error | After a disconnect error, retry Disconnect before reconnecting; verify no false Connected and no stale disconnect error after successful cleanup |
| Module cleanup failure, late notification update, unbound resource cleanup | `android/tests/service/ModuleLifecycleTest.kt`, `ManagedServiceRegistryTest.kt` | Confirm tunnel/key, app foreground notification, interfaces/routes and sockets are released |
| Native revoke/service loss and reattachment | State-machine, service bridge, setup suites | Android settings revoke/forget; close/reopen Flutter; kill/force-stop process; confirm no stale Connected |
| Always-on independent of app auto-connect | Localized Settings help and `VPN_GUIDE.md`; state owner remains native | Test Always-on and block-without-VPN both off/on; distinguish Android's warning from FlClash's notification |

For Android record `adb shell dumpsys connectivity`, `adb shell dumpsys activity services <application-id>`, and `adb shell dumpsys notification` before/after stop, plus logcat with secrets redacted. Check that this app's VPN network/foreground service and notification disappear; another app's VPN or Android's Always-on warning must not be mistaken for FlClash resources. Inspect per-process sockets/FDs where device permissions permit. Do not infer resource release merely from a gray button. The portable JVM harness does not run Android framework service/binder/notification code; new app/service module compilation and device checks remain CI/artifact gates.

Use non-production subscription credentials and keep a backup. Record OS/device/build, result, and any logs with URLs/tokens redacted.

| ID | Run on | Procedure and expected result | This host |
| --- | --- | --- | --- |
| A1 | Android device/emulator | Fresh import; deny/grant camera and VPN permission; repeated QR detection; connect/cancel; notification and Quick Settings stop/start; permission revoke; reopen/reattach; large text/TalkBack. Observe truthful state without losing profile. | Not run: no Android SDK, emulator, or device. |
| A2 | Android device | Connect using a disposable multi-server subscription. Close Flutter without stopping native VPN; verify traffic/health-check failover, unchanged snapshot/catalog, and no content fetch. Reopen after refresh interval; verify staged refresh, connected replacement, failed refresh, and latest Stop. | Not run: same prerequisites. |
| D1 | Each of Windows, macOS, Linux | QR PNG/JPEG picker, cancel/bad image, installation link; TUN authorization allow/deny and system-proxy fallback; rapid connect/cancel; tray stop; gear/back; resize narrow/wide; keyboard and screen reader; native title controls. | Not run: no Windows/macOS host; Linux has no GUI, clang/CMake/Ninja/GTK or AppIndicator development dependencies. |
| D2 | Each desktop OS | Confirm captured traffic follows selected server, Auto, and Fallback; force automatic failover and all-remotes-down; verify no direct fallback; successful/failed connected replacement and stop-during-import; close/reopen Flutter and check refresh lifetime. | Not run: native host/toolchain prerequisites above. |
| R1 | Android and one desktop | Export migration backup, restore a multi-profile old backup and a generation-backed new backup offline; interrupt around activation/publication using a test build, reopen, and verify one complete snapshot or explicit recovery-required state. | Automated boundary injection only; real process interruption not run. |

`flutter doctor -v` on the Linux arm64 host confirms the missing Android SDK and Linux build dependencies. Portable Kotlin compilation uses the real state-machine/model sources with an interface-only host scaffold; it is not an Android application/Flutter-plugin build. No native smoke result is inferred from a passing mocked test.

Native build attempts: `flutter build apk --debug --no-pub` stops with “No Android SDK found”; `flutter build linux --debug --no-pub` stops because CMake is unavailable. Flutter's cached engine downloads do not supply either the Android SDK/NDK or the missing Linux application toolchain.

The final command results and remaining OpenSpec tasks are recorded in `implementation-review.md`. Native smoke checks and Android module compilation remain release gates.

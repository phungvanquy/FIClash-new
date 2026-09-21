# Validation and platform handoff

This matrix names coverage for every delta-spec scenario. Automated tests use temporary files/SQLite and fake HTTP/Core/platform boundaries unless explicitly identified as Go or JVM tests. They do not replace native GUI/device smoke tests.

## Deferred native validation and artifact handoff

On 2026-09-21 the user approved continuing with this VPS as a development-only host and testing CI-built artifacts on native devices later. Native compilation and smoke checks are deferred, not assumed to have passed. Tasks 8.3 and 8.4 stay open until their results are recorded; missing local SDKs, GUI sessions, and devices do not require further provisioning here.

The current `.github/workflows/build.yaml` provides this handoff:

- Branch pushes run validation jobs, including Android JVM tests; packaged application builds require a `v*` tag push and successful prerequisite jobs. There is no manual `workflow_dispatch` trigger.
- Tag builds upload `artifact-android`, `artifact-windows-amd64`, and `artifact-linux-amd64` from `dist/`. The matrix has no macOS build, so macOS verification needs a separate host/build.
- A successful tag build also runs the release job. Tags containing a hyphen publish a prerelease; other matching tags publish a regular release. This is not an artifact-only test workflow. Do not create or push a tag just to obtain test binaries without explicit approval for that publication.
- The implementation includes uncommitted `core/Clash.Meta` changes. Before a remote build can include them, commit the fork changes, make that commit available to CI's configured submodule checkout, and update the parent repository's submodule reference together with the app changes. A parent commit alone does not capture a dirty submodule's files. Publishing either repository remains a separate authorized action.

After a build is available, record the parent and submodule commit IDs, CI run/artifact, device/OS, and results for A1/A2, D1/D2 per tested desktop platform, and R1 below. A green build establishes compilation, not successful device behavior. Keep untested paths explicit and complete native validation before treating the redesign as production-ready. No workflow changes or remote actions were performed for this handoff.

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
| Open advanced options | `pages/home_test.dart`, `widgets/tv_search_back_test.dart`, `common/tray_menu_test.dart` |
| Back from Settings | `pages/home_test.dart`, `widgets/tv_search_back_test.dart` |
| Large text and assistive technology | `pages/home_test.dart`, `widgets/vpn_import_test.dart`, localization/lint suites; native screen reader: A1/D1 |
| Resize a desktop window | `pages/home_test.dart`, window/header/widget suites; native chrome/focus: D1 |

Additional writer/restore guards: `providers/profile_draft_test.dart`, `features/overwrite_view_test.dart`, `views/vpn_configuration_test.dart`, `providers/backup_action_test.dart`, `database/single_profile_test.dart`, and `common/backup_task_test.dart` cover unpublished drafts, explicit Apply, cancellation/disposal, script/settings publication repair, concurrent library edits, restore strategies, and archive path rejection.

## Native smoke checks still required

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

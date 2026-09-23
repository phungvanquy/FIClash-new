# Integration validation

Validated on 2026-09-23 on Linux arm64 with Flutter 3.47.1 / Dart 3.13.1 and Go 1.26.4.

## Completed checks

- The maintained fork branch `update-core-xray-compatibility` is published, and its final commit `b2facd1ef0c3c319f1d5c5c43eaa124b6b2fb85c` can be fetched anonymously through the declared HTTPS submodule URL. A fresh parent checkout with the staged parent patch initialized that exact recursive submodule successfully.
- Both module graphs resolve the same pinned uTLS and CIRCL versions. The parent also applies the fork's protobuf replacement.
- Wrapper `CGO_ENABLED=0 go test -count=1 .` and `go vet .` pass, including preparation/activation rollback, frozen providers, rejected malformed REALITY providers, listener failures, and event contracts. On this root host, the tests run with `setpriv --bounding-set=-chown` because an existing ownership test expects an unprivileged `fchown` failure. CI runs as its ordinary unprivileged user. No Core coverage instrumentation was used.
- Fork tests pass for `component/tls`, `adapter/outbound`, `common/convert`, `config`, `adapter/provider`, `rules/provider`, `listener`, `transport/vless`, and `transport/vmess`. TLS/JLS/Vision integration compiles against the selected dependency graph.
- All 179 interoperability subcases in [results.md](results.md) pass, including a fresh checkout using the published submodule. The IPv6 fixture validates the automatically bracketed HTTP authority, independently of SNI. The harness also explicitly fails without required version/binary inputs. Official server artifact SHA-256 identities are in [releases.json](releases.json).
- `flutter pub get` and `flutter analyze --no-fatal-infos` pass. Analysis reports one existing `prefer_const_constructors` info in `test/widgets/scrollbar_inset_test.dart:18`.
- The full `flutter test --reporter expanded` suite passes: 2,140 tests passed and 3 skipped. The native bundle was built and verified separately; the suite used the repository's `build_assets: false` test setting, restored afterward without a tracked configuration change.
- The focused Flutter workflow, opaque profile-field preservation, protocol contract, and provider tests pass: 88 tests. The existing network-detection test exposed a fixed-sleep race under build contention. Its synchronization now waits for request/state signals and delayed cancellations, preserving both stale-result assertions; all 47 tests in that provider file pass. The CI prerequisite assertion was updated for the new `xray-interop` job and passes.
- Setup-hooks `dart test` passes all 43 tests. Source-generated Dart files were not changed; no models/providers/schema were modified, so generation was unnecessary.
- Existing Go build hooks compile macOS arm64/amd64, Windows arm64/amd64, and Linux arm64/amd64 Core executables with production tags. These are compile checks; cross-built executables are not represented as runtime-tested platforms.
- The Linux Core/Helper bundle is rebuilt through `buildPlatform`; the subsequent unchanged build reports cache reuse. The Core SHA-256, manifest value, and Helper's embedded expected hash match: `9843b7153e7d184d291867a2721c7fa8a574da40cca5b03e05bdf0a8b4a7df06`. Rebuilding after module/source changes invalidated the previous bundle (`8a7840431ec95cc740e4e56cbc6d671172d0f7f0aa9df179bba258b51a34a298`). Generated manifests were produced by the hooks.
- The rebuilt Linux Core passes four native IPC/profile smoke cases against Xray 26.3.27 and 26.9.9: activation, REALITY TCP/Vision and XHTTP payloads, failed replacement preserving traffic, stop/start, and shutdown.
- OpenSpec strict validation, formatting, and staged whitespace/comment-density checks pass.

## Original host validation gaps

- Android CGO/NDK builds for armv7, arm64, and amd64: this Linux arm64 environment has no Android SDK/NDK. The existing CI Android/NDK jobs remain required; host-only Go tests do not compile Android's CGO/JNI files.
- Actual Android application/VPN traffic, lifecycle transitions, and replacement failure handling on a device or emulator.
- Actual Windows application/Helper launch, executable identity/hash checks, and start/stop/restart behavior. Cross-compiling the Windows Core does not exercise the Windows service or named pipes.
- Desktop GUI/TUN smoke checks, including macOS, beyond the verified Linux Core IPC path.

Tasks 6.3 and 6.4 remain open until these host checks are completed. This update does not claim that the user's original server configuration or incident has been reproduced.

## Fresh-import and browser follow-up — 2026-09-24

The user reports HTTPS import failing at “Checking configuration → Preparing…” on a fresh Windows installation. No exact profile or log is available, so this incident remains unconfirmed. The stager previously fetched default geographic databases again during first import even though the app already ships them. First imports now stage the bundled GeoSite, GeoIP, country, and ASN databases when using default sources. Custom sources and subsequent refreshes retain their network semantics; bundled data receives an epoch timestamp instead of being represented as freshly downloaded. Failure diagnostics record stage, error class, and HTTP/Core/OS codes without URLs, bodies, paths, or credentials.

- Fork `7672fceac1ffd16209fe84243a398caa966f4211` is published and available anonymously through the declared submodule URL. TLS/outbound/converter/VMess package tests pass. All eight canonical fingerprints pass both transports across the five modern releases; see the follow-up matrix in [results.md](results.md).
- Wrapper tests and vet pass, including actual bundled-database preparation from a fresh data directory in both geodata modes. An initial run hit the existing 200-ms delay-queue test's timing limit during concurrent builds and blocked in its failure cleanup; a bounded full rerun passed in 3.4 seconds. No production timing behavior was changed.
- The Linux native bundle rebuilt successfully, then reused its cache. Core, manifest, and Helper agree on SHA-256 `3e3c973a43d6d01c2bc13bb7c4a723376c4012da4ffcfb43f9b9f3190beae47a`. Four native IPC/profile smoke cases pass on Xray 26.3.27 and 26.9.9.
- `flutter pub get`, repository-wide formatting, and the full Flutter suite pass: 2,143 passed, 3 skipped. The temporary native-hook test setting was restored.
- Riverpod generation was run after the import-diagnostic change. Only the generated VpnAction hash changed. Analysis passes with the same pre-existing lint info.
- The Windows AMD64 Go test binary cross-compiles successfully. CI now runs Core preparation and Flutter import/storage regressions on Windows before packaging. This Linux host cannot reproduce Windows GUI import or Helper service behavior.

The previous parent update's [CI run 35883781855](https://github.com/phungvanquy/FIClash-new/actions/runs/35883781855) passed all validation jobs and produced Android and Windows AMD64 test artifacts. That run closes the earlier build availability gap for that revision; it does not constitute device/GUI smoke testing of this follow-up.

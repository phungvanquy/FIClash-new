# Tasks

## 1. Establish reproducible server fixtures

- [x] 1.1 Add a parent-owned local Xray harness and synthetic REALITY target/echo fixtures with pinned versions, verified checksums or image digests, bounded timeouts, and process cleanup; verify missing prerequisites fail explicitly and fallback web responses cannot pass a proxy-data assertion.
- [x] 1.2 Capture the current Core's behavior against Xray 26.3.27 with omitted and explicit `minClientVer: "26.3.27"`, plus the July minimum-version and September key-share policies; verify the report records each result and labels the user's incident unconfirmed.

## 2. Update the maintained Core baseline

- [x] 2.1 Integrate mihomo v1.19.31 commit `ab405bad5beeeac8b003bb01f60f134f6df54471` while retaining FlClash integration and detached preparation; verify fork API compilation and the existing config/provider/geodata/listener preparation tests.
- [x] 2.2 Pin the compatible uTLS candidate `2aa631698733a602acb2d998b9e7df2e6a446dd2` by resolved pseudo-version and reconcile both Go module graphs; verify module resolution, TLS/JLS/Vision compilation, and Chrome/Firefox/Safari ClientHello key shares with the current CI toolchain.
- [x] 2.3 Integrate upstream XHTTP header conversion after the stable baseline and retain stable's IPv6 and explicit ML-KEM conversion changes; verify focused converter and IPv6 authority regressions against the selected upstream patches.

## 3. Implement modern REALITY semantics

- [x] 3.1 Replace the `1.8.2` wire advertisement with the named tested 26.3.27 compatibility baseline; verify accepted and rejected version-policy fixtures plus real application-data transfer, independently of key-share tests.
- [x] 3.2 Make omitted/true ML-KEM modern and explicit false legacy at the shared outbound boundary, including XHTTP download connections; verify option parsing, exact key-share order, legacy operation, and absence of automatic authentication downgrade.
- [x] 3.3 Add REALITY-specific default/random fingerprint selection and incompatible explicit-fingerprint errors; verify every eligible random choice and process restart, explicit old fingerprints, and unchanged generic TLS selection behavior.
- [x] 3.4 Add optional `mldsa65-verify` parsing and a pinned CIRCL verifier following Xray's certificate/transcript semantics; verify valid, wrong, malformed, absent-signature, and omitted-option cases without panic or weakened authentication.

## 4. Preserve configuration semantics

- [x] 4.1 Map provider-link `pqv`, `pbk`, `sid`, and explicit ML-KEM mode, and propagate malformed recognized security options instead of dropping them; verify converter and required-provider preparation failures preserve the working profile.
- [x] 4.2 Preserve nested XHTTP REALITY `password`/`publicKey` precedence, SNI, fingerprint, short ID, and additional verification options; verify independent upload/download fixture values reach their respective connections.
- [x] 4.3 Extend the existing opaque-field preservation test in `test/common/task_test.dart` for advanced REALITY/XHTTP/VLESS fields and explicit false; verify simple/custom mode preparation and activation retain the values without adding direct proxy-link UI intake.

## 5. Complete interoperability coverage

- [x] 5.1 Run TCP/Vision and XHTTP REALITY payload tests on Xray 26.3.27 with both minimum-version policies; verify both cases pass and keep the unknown user-specific failure separate from fixture results.
- [x] 5.2 Run the July and September version matrix, modern browser fingerprints, negative credentials/SNI/version/key-share cases, and a checksum-pinned older server with explicit legacy mode; verify expected success/failure for every required matrix row.
- [x] 5.3 Run optional ML-DSA tests against 26.3.27 and 26.9.9, and XHTTP auto/packet-up/stream-up/stream-one, header, IPv6, and independent-download tests; verify authenticated payloads and enforced failures, with unavailable coverage identified explicitly.
- [x] 5.4 Add and run regressions for VLESS encryption native/xorpub/random in 0-RTT and 1-RTT, Vision, XUDP, VLESS TLS/WS/gRPC, VMess TLS/WS, and Trojan TLS/gRPC on versions supporting each combination; verify stream/datagram payloads and document actual upstream removals separately.
- [x] 5.5 Add an explicit CI interoperability job using the harness and pinned artifacts; verify the required matrix runs from a clean checkout while ordinary wrapper unit tests require no external server downloads.

## 6. Verify application and native integration

- [x] 6.1 Run `CGO_ENABLED=0 go test .` and `CGO_ENABLED=0 go vet .` from `core/`, plus focused changed-package tests from the submodule; verify prepared activation/rollback, frozen providers, event contracts, and listener failures remain correct without adding Core coverage instrumentation.
- [x] 6.2 Run `flutter pub get`, `flutter analyze --no-fatal-infos`, and `flutter test --reporter expanded`, including protocol/task/profile regressions; verify no generated-file drift or changed lifecycle ownership. Run code generation only if an implementation change actually touches models/providers/schema.
- [ ] 6.3 Run the setup-hooks package's `dart test` and build the desktop Core targets and Android CGO/NDK variants with existing hooks; verify cold-build output, cache invalidation after a Core change, and matching rebuilt Core/manifest/Helper hashes.
- [ ] 6.4 Smoke-test profile activation and REALITY traffic through actual Android and desktop bundles, including Windows Helper launch; verify start/stop/restart and failed replacement preserve their contracts, and record any host validation still outstanding.

## 7. Record and package the verified update

- [x] 7.1 Deliver compatibility documentation with exact Core/uTLS/ML-DSA dependency revisions, server artifact identities, per-case results, explicit legacy migration, supported/unsupported Xray options, and diagnostic guidance for `minClientVer`; verify every support claim points to a passing fixture and the user's unconfirmed diagnosis stays qualified.
- [x] 7.2 Prepare the final maintained-fork commit and parent gitlink/module update, ensure that commit is available from the declared submodule URL before release, and rebuild the native bundle; verify clean recursive checkout reproducibility and document the paired gitlink/module rollback.

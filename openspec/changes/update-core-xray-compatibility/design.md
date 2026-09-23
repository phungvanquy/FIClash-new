# Design

## Context

See `proposal.md` for motivation and `specs/xray-core-compatibility/spec.md` for the behavior contract. This is a Core interoperability change with protocol, dependency, and native-build consequences, so a design is required.

The inspected gitlink is `10a96da7b65faf1f1c4afd764ec115c333021c1d`. Its upstream ancestor is `ac017cdd` (2026-08-16); `70f05704` carries FlClash integration and `10a96da7` adds detached preparation. Their combined patch touches 58 files, including Android socket protection, process attribution, event hooks, prepared providers/geodata, listener outcomes, and activation. Replacing the submodule with unmodified upstream would remove required APIs.

The latest stable mihomo found on 2026-09-23 is **v1.19.31**, commit `ab405bad5beeeac8b003bb01f60f134f6df54471`, 51 commits ahead of the upstream ancestor. Its REALITY implementation and options are byte-identical to the checkout: it advertises `1.8.2`, strips ML-KEM unless explicitly enabled, and has no ML-DSA verifier. The existing Core already implements XHTTP, Vision, XUDP, and VLESS `mlkem768x25519plus` encryption; these are validation targets, not missing protocols to reimplement.

The user's confirmed server version is **26.3.27**. They suspect `minClientVer` but do not know the transport or error. Source inspection establishes the following independently of that report:

| Area | Observed behavior | Consequence |
| --- | --- | --- |
| Xray 26.3.27 | Applies `minClientVer` only when explicitly configured | `1.8.2` can fail an explicit 26.3.27 minimum; the release number alone does not diagnose the user's failure |
| Xray 26.7.11 / 26.7.28 | Unset minimum becomes 26.3.27 | Current advertisement is rejected by default |
| Xray 26.9.8 / 26.9.9 | Default minimum assignment is commented out; REALITY requires the hybrid share before optional X25519 | Version and TLS key-share failures must be tested separately |
| uTLS v1.8.7 | Chrome auto is 133; Firefox is 120; Safari is 16; iOS is 14 | Only the listed Chrome default supplies the required modern share; generic random selection includes incompatible choices |
| Provider conversion | No `pqv`; nested download REALITY reads only `publicKey` and `shortId`; top-level XHTTP `extra.headers` is dropped | Supported server settings can be lost before dialing |
| Existing Go integration tests | `test/` is a nested module using floating `teddysun/xray:latest`; VLESS fixture includes obsolete `xtls-rprx-direct` | These tests do not establish current REALITY compatibility and are not run by `go test .` in the wrapper |

The latest Xray release entry is **26.9.9**, marked prerelease; GitHub's latest stable endpoint still returns **26.3.27**. Neither endpoint alone defines this change's test coverage.

Relevant upstream sources:

- [26.3.27 configuration](https://github.com/XTLS/Xray-core/blob/v26.3.27/infra/conf/transport_internet.go), [26.7.28 security configuration](https://github.com/XTLS/Xray-core/blob/v26.7.28/infra/conf/transport_security.go), and [26.9.9 security configuration](https://github.com/XTLS/Xray-core/blob/v26.9.9/infra/conf/transport_security.go).
- [REALITY September key-share change](https://github.com/XTLS/REALITY/commit/8cdf7bf9c7f09cb9814bf08c3eb877f68b85fba8) and [Xray REALITY authentication/ML-DSA verification](https://github.com/XTLS/Xray-core/blob/v26.9.9/transport/internet/reality/reality.go).
- [Mihomo stable comparison](https://github.com/MetaCubeX/mihomo/compare/v1.19.30...v1.19.31), [current REALITY implementation](https://github.com/MetaCubeX/mihomo/blob/v1.19.31/component/tls/reality.go), and [XHTTP header conversion change](https://github.com/MetaCubeX/mihomo/pull/3230).
- [Candidate uTLS revision](https://github.com/MetaCubeX/utls/commit/2aa631698733a602acb2d998b9e7df2e6a446dd2) and [Xray share-link field definitions](https://github.com/XTLS/Xray-core/discussions/716).

## Goals / Non-Goals

**Goals:**

- Keep protocol ownership inside the maintained mihomo fork, configuration orchestration in the existing application boundary, and reproducible test evidence in the parent repository.
- Exercise both authentication and real stream/datagram transfer; successful parsing, a latency result, or contact with a REALITY fallback target is insufficient.
- Make modern defaults and explicit legacy behavior deterministic, including nested XHTTP downloads and random fingerprints.

**Non-Goals:**

- Replacing mihomo with Xray, adding a second runtime, or changing desktop/Android lifecycle ownership.
- Altering the user's server, disabling authentication checks, or requiring a server downgrade.
- Full Xray JSON import, direct `vless://` UI intake, and unrestricted parity with Xray-specific finalmask, fragmentation, or server-only options. Existing provider conversion remains in scope.
- Treating the user's failure as reproduced without evidence. A passing 26.3.27 fixture establishes support for that fixture only.

## Decisions

### 1. Integrate a fixed stable upstream into the maintained fork

Merge the fixed v1.19.31 commit into the existing fork history and preserve both application-specific changes. Prefer this over resetting the submodule or replaying unrelated repairs individually: the update is requested, its 51-commit range is bounded, and keeping fork ancestry makes lost integration visible. Carry the specific upstream XHTTP `extra.headers` conversion feature after stable as an identified patch, without following the moving alpha branch.

Audit merge conflicts around `config`, providers, geodata, rules, and listener activation using the fork's existing preparation tests. Stable also migrates its YAML dependency to `go.yaml.in/yaml/v3`; validate wrapper boundaries rather than mechanically changing every `gopkg.in/yaml.v3` import. New hand-maintained changes in the submodule are the REALITY/Xray compatibility capability, which cannot be implemented by Flutter configuration rewriting. Do not add unrelated repair work to the fork.

The declared submodule URL is `https://github.com/phungvanquy/FlClash-core.git`; this checkout's `origin` points elsewhere and `publish` points to that declared URL. Keep repository identity stable. The final gitlink must reference a commit available through the declared URL before release; an unpushed local commit is not a reproducible dependency.

### 2. Implement complete REALITY compatibility at the TLS boundary

Use a named wire-compatibility baseline `{26, 3, 27}` in the authenticated session ID. This is a tested protocol advertisement, not the app version or a claim that mihomo is Xray. Do not set a client-side `minClientVer` option: that setting belongs to the server. Explicit server minima above this baseline and maxima below it remain outside the promised policy range.

Change the existing ML-KEM option to distinguish omission from explicit false and resolve omission to true at the shared outbound boundary. Both the main REALITY connection and an independent XHTTP download connection must use the same option semantics. Keep false as an explicit legacy escape hatch. Do not infer legacy mode from a failed authentication or mutate saved profile data to simulate defaults.

Pin uTLS to the immutable candidate `2aa631698733a602acb2d998b9e7df2e6a446dd2` using its resolved Go pseudo-version, subject to compilation and wire-format tests. It supplies Firefox 148 and Safari 26.3 while keeping Chrome 133. Preserve the existing TLS-fork APIs, including JLS and Vision's connection handling. The candidate declares Go 1.20; there is no evidence requiring an application toolchain bump just to obtain these fingerprints.

Resolve modern REALITY's omitted fingerprint to Chrome and its random pool to tested Chrome/Firefox/Safari. Scope that pool to REALITY; retain generic TLS selection semantics. Validate explicit fingerprint key shares and return a useful error for unsupported modern choices. Do not inject ML-KEM into an arbitrary legacy browser identity or silently replace a requested fingerprint.

A version-byte-only patch would still fail the September key-share rule. A config-only `support-x25519mlkem768: true` patch would still fail restrictive version policies, lose omission/false semantics, and leave most current browser aliases incompatible. Neither is sufficient.

### 3. Add optional ML-DSA verification without changing ordinary authentication

Add `reality-opts.mldsa65-verify`, mapped from `pqv` in provider links and `mldsa65Verify` in nested Xray settings. Validate base64url encoding and the ML-DSA-65 public-key size during preparation. Use a pinned compatible release of the maintained CIRCL ML-DSA implementation used by Xray; do not implement signing primitives locally.

Follow the referenced Xray verifier's authenticated certificate/transcript semantics. Normal REALITY authentication remains mandatory. If the option is present, successful additional verification is also mandatory; missing or incorrect signatures never become an accepted proxy connection. Without it, keep ordinary REALITY behavior. Test malformed certificates/extensions as well as valid/wrong keys so verifier errors return normally rather than panicking.

This closes a separate security-option gap. Its absence does not by itself establish why the user's server rejects the current client, because the additional verification is optional client behavior.

### 4. Preserve options at their existing conversion boundaries

Update `common/convert/v.go` and associated provider parsing, not `lib/common/converter.dart` (which is a byte converter). Include:

- Existing `pbk`/`sid` and the upstream explicit ML-KEM query mapping, plus `pqv` to `mldsa65-verify`.
- Nested `downloadSettings.realitySettings.password` overriding legacy `publicKey`, and REALITY's own `serverName`, `fingerprint`, `shortId`, and `mldsa65Verify` fields. Currently SNI/fingerprint are read from `tlsSettings` even when security is REALITY.
- XHTTP `extra.headers`, preserving independent upload/download options and the existing path/host/mode/reuse mapping.
- Correct propagation of malformed recognized security fields. The existing converter can skip bad entries; required provider preparation must not silently replace a configured security constraint with its absence.

Continue to pass opaque proxy maps through `lib/common/task.dart`. Extend its existing advanced-field preservation test for the new nested fields and explicit false rather than introducing typed Flutter protocol models. Preserve the `single-profile-import` contract and frozen provider snapshots.

The upstream XHTTP IPv6 correction is part of the stable update. VLESS encryption/flow/XUDP already exist; add regression fixtures rather than independent protocol implementations. Document `spx`/spider behavior and other unimplemented Xray-only fields as limitations instead of pretending every link parameter is supported.

### 5. Use a controlled interoperability suite and a release matrix

Add a parent-owned harness under `tool/` with synthetic fixtures under `core/testdata/xray/` and an explicitly invoked integration test. Exercise the public mihomo outbound/config boundary using the selected fork, with the actual built wrapper covered by startup/profile activation smoke tests. Keep normal wrapper `go test .` independent of Docker and external downloads. CI installs checksum-verified official Xray binaries or digest-pinned official images for the integration job; tests themselves use local endpoints and generated test credentials only.

Run a local TLS 1.3 REALITY target with the capabilities the server expects, plus local TCP/UDP echo destinations. Bound startup, handshake, test, and shutdown times, and clean up every owned process. Assert known response payloads and REALITY authentication; fallback web traffic cannot satisfy the assertion. Missing Xray artifacts or IPv6 support must be reported as unavailable coverage, never a passing test; release CI must provide prerequisites for required rows.

Required matrix:

| Test group | Server baseline | Cases |
| --- | --- | --- |
| Reported release | 26.3.27 | Minimum omitted and explicitly 26.3.27; TCP/Vision and XHTTP; payload success |
| Version-policy regression | 26.7.11 and 26.7.28 | Default policy succeeds; known lower advertisement is rejected in a controlled negative fixture |
| Modern REALITY | 26.9.8 and 26.9.9 | Omitted/true ML-KEM; Chrome/Firefox/Safari; all random choices; correct share order; legacy shares rejected |
| Explicit legacy mode | Pinned older REALITY server fixture | False with a legacy fingerprint succeeds; record exact selected version/checksum before running |
| Additional verification | 26.3.27 and 26.9.9 | Valid, wrong, malformed and missing ML-DSA verification material |
| XHTTP and conversion | 26.3.27 and 26.9.9 | Supported modes, extra headers, IPv6 authority, independent download credentials/SNI/fingerprint |
| Existing Xray protocols | Versions supporting each row | VLESS TLS/WS/gRPC, Vision, XUDP, VLESS encryption native/xorpub/random with 0-RTT and 1-RTT; VMess TLS/WS; Trojan TLS/gRPC |

Record which version supports each regression row; a transport removed upstream is an explicit limitation on that version, not an excuse to silently drop the older compatibility test. The user's exact incident remains unconfirmed unless later diagnostics or a fixture reproduce it.

## Risks / Trade-offs

- **Modern default changes older profiles** → Mark as breaking, retain explicit false, document a tested legacy fingerprint, and avoid automatic downgrade. A server with a restrictive maximum version can still reject the new advertisement.
- **uTLS branch pin and certificate verification affect sensitive code** → Use immutable dependencies, focused malformed-input tests, known upstream verification semantics, and real Xray handshakes. Verify Vision and non-REALITY TLS regressions too.
- **Upstream integration removes a fork hook or changes preparation side effects** → Preserve named fork commits, run detached preparation/activation tests, and exercise failed replacement while connected.
- **Server errors look alike** → Keep version, key-share, credentials, SNI, clock skew, and transport cases separate. Do not label every authentication failure a version mismatch.
- **Native builds diverge from a host test** → Build desktop targets and Android CGO/NDK variants through existing hooks; run actual Windows/Android smoke checks before claiming those hosts verified.
- **Dependency or build-cache drift** → Reconcile both module graphs; verify a cold build and cache invalidation, and regenerate the Core hash/Helper artifacts as one bundle. Do not hand-edit generated manifests or reuse an old Helper with a new Core.

## Migration Plan

1. Introduce pinned server fixtures and capture existing behavior, especially 26.3.27 with explicit minimum and modern key-share rejection.
2. Integrate the stable upstream and feature patches in the maintained Core fork. Reconcile parent module files; retain CI Go 1.26.4 unless compilation proves a documented dependency requirement.
3. Run focused Go, conversion, profile-preparation, Flutter contract, setup-hook, and native-build checks. Run the full pinned interoperability matrix and record pass/fail/unsupported results.
4. Ensure the final Core commit is fetchable from the declared submodule URL before distributing the parent gitlink. Stage the rebuilt Core, manifest and Helper together through the existing build hooks.
5. Publish compatibility guidance with the explicit legacy option and validated versions. Do not rewrite users' stored credentials or lower their server policy.
6. Roll back by reverting the parent gitlink and matching module/build changes together and rebuilding the whole native bundle. Leave stored profiles and committed snapshots intact.

## Open Questions

- The user's error, transport, and actual `minClientVer` value remain unknown. They can refine the incident reproduction later without changing the required version-policy and modern-handshake tests. No acceptance claim about that incident is made from the hypothesis alone.

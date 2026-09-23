# Proposal

## Why

The user reports a REALITY connection failure against Xray-core **26.3.27**, possibly involving `minClientVer`; the transport, server policy, and error are not yet known, so the specific failure is not reproduced. The bundled mihomo fork has confirmed compatibility gaps in REALITY version advertisement, modern TLS fingerprints, and XHTTP configuration conversion, and updating to the latest stable mihomo alone does not close them.

## What Changes

- Advance the maintained Core fork from upstream base `ac017cdd` to mihomo **v1.19.31**, preserving its FlClash integration and detached profile preparation changes, and pin the resulting fork commit and Go dependencies reproducibly.
- Add tested REALITY compatibility with Xray **26.3.27**, including an explicit server `minClientVer: "26.3.27"`, and with newer **26.7.11**, **26.7.28**, **26.9.8**, and **26.9.9** server behavior. Treat these as distinct cases, not evidence that the reported server has a newer default policy.
- Replace the hardcoded REALITY `1.8.2` advertisement with a named, tested compatibility baseline of `26.3.27`; verify the complete handshake rather than changing version bytes alone.
- **BREAKING:** Default an omitted `reality-opts.support-x25519mlkem768` to enabled. Preserve explicit `false` for older servers, use current compatible browser fingerprints, and keep REALITY random selection within the compatible set. Unsupported explicit fingerprints receive an actionable error rather than silent substitution.
- Add optional REALITY ML-DSA-65 verification, including configuration validation and preservation through supported subscription/provider conversion. A supplied verification key must never be silently discarded.
- Carry upstream XHTTP IPv6 and ML-KEM conversion improvements; preserve XHTTP `extra.headers` and nested REALITY `password`/`publicKey`, SNI, fingerprint, short ID, and verification options. Verify existing VLESS encryption, Vision, XUDP, TLS, WebSocket, and gRPC behavior without claiming universal Xray feature parity.
- Add a reproducible local-server interoperability suite, field-preservation regressions, and a compatibility report separating verified support, explicit legacy behavior, unsupported features, and the unconfirmed cause of the user's failure.

## Capabilities

### New Capabilities

- `xray-core-compatibility`: REALITY handshake and option semantics, preservation of supported Xray configuration fields, and reproducible compatibility validation for the bundled Core.

### Modified Capabilities

None. The existing `single-profile-import` guarantees remain constraints: direct proxy share-link intake stays unsupported, provider content conversion remains supported, and failed preparation preserves the committed profile and running session.

## Impact

- Core fork: `core/Clash.Meta/component/tls/`, `adapter/outbound/`, `common/convert/`, associated Go modules and tests; upstream integration also touches configuration/provider code and must preserve fork APIs.
- Parent repository: the Core gitlink, `core/go.mod`, `core/go.sum`, focused interoperability fixtures/tests, `test/common/task_test.dart`, build-hook checks, CI, and compatibility documentation. The current CI Go version is `1.26.4`; toolchain changes require dependency evidence rather than following Xray's separate build requirement.
- Dependency candidate: immutable commit `2aa631698733a602acb2d998b9e7df2e6a446dd2` from MetaCubeX/uTLS's `v1.9.0-mod-meta` branch supplies newer Firefox/Safari fingerprints. ML-DSA verification uses a pinned maintained implementation rather than custom cryptographic primitives.
- Retain mihomo as the application core. Desktop lifecycle ownership, Android service arbitration, IPC envelopes, Helper integrity verification, and the user-facing import/navigation model stay intact.

Research was performed on 2026-09-23. [Mihomo v1.19.31](https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.31) is the selected stable upstream baseline. [Xray 26.3.27 configuration](https://github.com/XTLS/Xray-core/blob/v26.3.27/infra/conf/transport_internet.go) applies a minimum client version only when configured; the [September REALITY key-share change](https://github.com/XTLS/REALITY/commit/8cdf7bf9c7f09cb9814bf08c3eb877f68b85fba8) is a separate, newer incompatibility.

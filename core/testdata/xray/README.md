# Xray interoperability

Run `GOTOOLCHAIN=go1.26.4 python3 tool/xray_interop.py` from the repository root on Linux amd64 or arm64. `releases.json` pins official release archives by SHA-256. The harness verifies each archive, extracts its binary into `.dart_tool/xray-interop/`, and runs the opt-in `xrayinterop` Go tests. Ordinary wrapper tests do not download or launch Xray.

The servers, TLS fallback targets, and echo destinations run locally with synthetic credentials. A successful case must return a random proxy payload; a fallback website does not qualify. Missing binaries, failed startup, and transfer deadlines fail explicitly. `--download-only` prepares artifacts, `--versions` selects pinned releases, and `--run` selects Go tests.

Set `FLCLASH_INTEROP_CORE` to the absolute path of a built Linux Core to include native IPC/profile smoke tests; without it that group explicitly reports SKIP. CI builds the executable and sets this variable. The recorded full matrix includes these native cases.

## Original Core baseline

Recorded on 2026-09-23 with Core `10a96da7b65faf1f1c4afd764ec115c333021c1d`, Go 1.26.4, Linux arm64, using `--baseline`. Baseline mode records observations rather than asserting upgraded behavior; its Go PASS marker means observations were collected, not that all connections succeeded.

| Xray | TCP/Vision default | Explicit minimum 26.3.27 | XHTTP default |
| --- | --- | --- | --- |
| 26.3.27 | Connected and echoed payload | Rejected | Connected and echoed payload |
| 26.7.11 | Rejected | Rejected | Rejected |
| 26.7.28 | Rejected | Rejected | Rejected |
| 26.9.8 | Rejected | Rejected | Rejected |
| 26.9.9 | Rejected | Rejected | Rejected |

Xray 1.8.24 connected with `chrome120` and explicit `support-x25519mlkem768: false`. Rejected handshakes reached the synthetic fallback certificate and failed certificate verification. This demonstrates the configured minimum-version incompatibility on 26.3.27; the user's actual server policy and failure remain unconfirmed.

## Updated Core

The update merges mihomo **v1.19.31**, commit `ab405bad5beeeac8b003bb01f60f134f6df54471`, into the maintained FlClash fork. FlClash's API/event integration and detached config/provider preparation remain in the fork. The merge retains both upstream DNS-policy parsing changes and isolated preparation contexts. Go's newer printf checker also required a constant format in the provider expression parser.

Both module graphs select:

- uTLS `v0.0.0-20260726054410-2aa631698733`, commit `2aa631698733a602acb2d998b9e7df2e6a446dd2`.
- CIRCL `v1.6.5` for optional ML-DSA-65 verification. The minimum Go version becomes 1.25; validation uses the existing CI toolchain 1.26.4.

REALITY advertises the **26.3.27 compatibility baseline** in its authenticated session. This is a tested wire-compatibility value, separate from the mihomo or app version. A server requiring a later `minClientVer`, or a `maxClientVer` below this value, deliberately rejects it.

Omitting `support-x25519mlkem768`, or setting it to `true`, now sends the modern hybrid key share. Modern REALITY supports `chrome`, `firefox`, `safari`, `ios`, `android`, `edge`, `360`, and `qq`. It defaults to Chrome; `random` chooses among these eight tested presets. The iOS, Android, Edge, 360, and QQ aliases retain their browser-family extensions with REALITY-specific TLS 1.3/hybrid-key-share adaptations; these are not exact historical browser fingerprints. Versioned legacy presets such as `chrome120` remain unchanged and return an actionable error in modern mode when they lack the required hybrid share. Ordinary TLS fingerprint selection retains its previous behavior, with browser presets supplied by the updated uTLS dependency. Authentication failures never trigger an automatic legacy retry.

For an older server, explicitly use:

```yaml
client-fingerprint: chrome120
reality-opts:
  public-key: <server-public-key>
  short-id: <server-short-id>
  support-x25519mlkem768: false
```

Optional `reality-opts.mldsa65-verify` accepts the server's base64url ML-DSA-65 public verification key. A configured key requires the authenticated certificate extension and matching ClientHello/ServerHello transcript signature. Wrong keys, malformed keys, and absent signatures fail closed. Omitting this option preserves ordinary REALITY authentication, including when the server supplies an extra signature.

Provider links map `pqv`, `pbk`, `sid`, and explicit `support-x25519mlkem768`. For XHTTP `extra.downloadSettings.realitySettings`, nonempty `password` takes precedence over `publicKey`; `serverName`, `fingerprint`, `shortId`, `mldsa65Verify`, and explicit ML-KEM mode remain independent of upload settings. Malformed recognized security settings reject the provider instead of silently discarding a node or its authentication options. Flutter keeps these advanced fields opaque in both simple and custom profiles. This change does not introduce direct proxy-link intake in the app's profile URL field.

## Fixture interpretation

Each positive stream case must echo a random 2 KiB payload. Transport/encryption cases repeat the transfer on the same adapter so `0rtt` can reuse its ticket; XUDP also echoes an actual datagram. Negative tests require rejection after the server has started. Unit tests additionally check exact hybrid-share size/order, every eligible random preset, malformed certificate states, and security-option parsing.

The ML-DSA target uses a synthetic certificate with sufficient padding for REALITY's larger signed certificate record. The independent-download fixture uses two REALITY front doors into one XHTTP session endpoint. A local HTTP guard requires different upload/download headers. Only those raw front-door fixtures disable Xray's splice optimization to retain TLS framing; the ordinary Vision fixtures use Xray's defaults.

July and September fixtures explicitly permit loopback through Freedom `finalRules`, since their default private-destination blocking would otherwise hide a successful handshake behind an intentionally stalled outbound. All fixtures remain local and use disposable credentials.

The ordinary Go wrapper suite requires no Xray downloads. CI's separate `xray-interop` job downloads checksum-pinned archives, tests the fork packages, runs the matrix, uploads its log, and gates packaging. `releases.json` is the artifact identity record for both Linux architectures. Per-case results are in [results.md](results.md); host runs and device validation are tracked in [validation.md](validation.md).

## Diagnostic boundaries

A certificate/fallback error alone does not identify a minimum-version rejection. Check the server's exact release and `minClientVer`/`maxClientVer`, then compare public key, short ID, SNI, fingerprint, ML-KEM mode, and optional ML-DSA verification key. Collect the client error and a redacted configuration before attributing the user's incident to any one setting.

REALITY over QUIC/HTTP3, arbitrary Xray-only options, and unsupported legacy fingerprints are not promised by this update. The tested Xray releases warn that gRPC is deprecated but still accept it; VLESS and Trojan gRPC fixtures cover all five modern releases. Existing VLESS TLS/WS, VMess TLS/WS, Trojan TLS, VLESS encryption, and XUDP are checked separately from REALITY authentication.

Relevant upstream sources: [mihomo v1.19.31](https://github.com/MetaCubeX/mihomo/releases/tag/v1.19.31), [uTLS candidate](https://github.com/MetaCubeX/utls/commit/2aa631698733a602acb2d998b9e7df2e6a446dd2), [Xray REALITY client](https://github.com/XTLS/Xray-core/blob/v26.3.27/transport/internet/reality/reality.go), [REALITY server](https://github.com/XTLS/REALITY/blob/8cdf7bf9c7f0/handshake_server_tls13.go), and [Freedom policy](https://github.com/XTLS/Xray-core/blob/v26.9.9/proxy/freedom/freedom.go).

The final fork commit is `7672fceac1ffd16209fe84243a398caa966f4211` on `update-core-xray-compatibility` (stable merge: `ae8a361c`). The parent pins this commit and matching module sums. The wrapper also carries upstream's protobuf replacement `github.com/metacubex/protobuf-go@v0.0.0-20260306035419-7ceee0674686`, because Go does not inherit replacements from dependency modules.

`spx`/Xray's configurable spider paths are not implemented here; the existing Core fallback behavior remains. Generic Xray JSON is not an app profile format. Server options such as `minClientVer`, `maxClientVer`, and `mldsa65Seed` belong on the Xray server, while the documented public verification fields belong on the client.

## Packaging and rollback

Publish the fork commit to the declared `https://github.com/phungvanquy/FlClash-core.git` before distributing this parent gitlink. A local git bundle is also prepared at `.dart_tool/xray-interop/FlClash-core.bundle`; it requires the original fork history. A local-only commit is not sufficient for a fresh release checkout.

The previous parent baseline is `5098a83d8161991f59325edf2b154da2025b06a2`; its Core gitlink is `10a96da7b65faf1f1c4afd764ec115c333021c1d`. Roll back the gitlink **and** `core/go.mod`/`core/go.sum` together, restore the matching compatibility implementation/tests, and rebuild through the existing setup hooks. Distribute the newly matching Core, manifest, and Helper as a bundle. Keep stored profiles and frozen snapshots intact; explicit modern-only profiles can require migration when reverting to the old Core.

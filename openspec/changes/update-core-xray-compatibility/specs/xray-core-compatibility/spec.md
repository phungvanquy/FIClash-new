# Spec Delta

## Purpose

Enable the bundled Core to connect to supported Xray servers with current REALITY and VLESS settings, preserve those settings during configuration preparation, and make compatibility claims reproducible.

## ADDED Requirements

### Requirement: Tested REALITY client compatibility

The bundled Core SHALL establish authenticated VLESS REALITY connections to Xray 26.3.27 with both an omitted minimum client version and `minClientVer: "26.3.27"`, provided credentials, SNI, transport, and other server restrictions match. It SHALL also interoperate with the tested default REALITY policies of Xray 26.7.11, 26.7.28, 26.9.8, and 26.9.9. The advertised compatibility version SHALL be tied to verified protocol behavior; a version-byte change alone MUST NOT constitute acceptance.

#### Scenario: User's server version with an explicit minimum

- **WHEN** an otherwise valid Xray 26.3.27 server requires client version 26.3.27 and the client uses VLESS TCP/Vision with REALITY
- **THEN** authentication succeeds and proxied application data reaches the test destination

#### Scenario: User's server version without a minimum

- **WHEN** the same server omits `minClientVer`
- **THEN** the client also authenticates and transfers application data successfully

#### Scenario: Newer server policy

- **WHEN** the client connects to a supported REALITY configuration on each newer tested server version with its default client-version policy
- **THEN** authentication and application-data transfer succeed without weakening that server's settings

### Requirement: Modern and explicit legacy REALITY modes

An omitted or true `reality-opts.support-x25519mlkem768` SHALL enable modern REALITY operation with one X25519MLKEM768 key share preceding any X25519 share. An explicit false SHALL retain the legacy key-share behavior for servers that require it. The client MUST NOT automatically retry a failed modern authentication with weaker verification or legacy key shares. Unrelated TLS outbounds SHALL retain their configured behavior.

#### Scenario: Existing profile omits the option

- **WHEN** a valid REALITY profile omits `support-x25519mlkem768` and uses a compatible fingerprint
- **THEN** its handshake carries the modern key shares and succeeds against the tested September Xray servers

#### Scenario: Legacy compatibility is explicitly selected

- **WHEN** a profile sets `support-x25519mlkem768: false` with a compatible legacy fingerprint and a server accepting that mode
- **THEN** the client omits the hybrid key share and can authenticate to that server

#### Scenario: Modern authentication fails

- **WHEN** authentication fails because the public key, short ID, or verification key does not match
- **THEN** the connection fails without reporting the server's fallback website as a successful proxy connection or retrying with reduced verification

### Requirement: Compatible REALITY fingerprint selection

Modern REALITY SHALL support the tested `chrome`, `firefox`, and `safari` fingerprints. Omitted fingerprint selection SHALL resolve to a compatible default. A configured `random` selection SHALL choose only compatible modern REALITY fingerprints, including across process restarts. An explicitly selected incompatible fingerprint SHALL produce a clear configuration or connection error identifying the fingerprint constraint; it MUST NOT be silently replaced with another browser identity.

#### Scenario: Modern browser fingerprints

- **WHEN** a profile independently selects chrome, firefox, or safari in modern REALITY mode
- **THEN** each produces the required key-share format and authenticates against a tested modern server

#### Scenario: Random selection remains compatible

- **WHEN** random selection chooses any eligible fingerprint or the Core restarts
- **THEN** the chosen fingerprint remains compatible with modern REALITY

#### Scenario: Explicit old fingerprint

- **WHEN** a profile requests `chrome120` in modern REALITY mode
- **THEN** the client reports the incompatible fingerprint and identifies a compatible fingerprint or explicit legacy mode as the configuration choices

### Requirement: Optional post-quantum certificate verification

The Core SHALL support an optional REALITY ML-DSA-65 verification public key. A supplied key SHALL be validated and enforced in addition to normal REALITY authentication. Invalid keys, mismatched signatures, and missing required signatures MUST fail without silently ignoring the configured verification. Omitting the option SHALL preserve ordinary REALITY certificate authentication.

#### Scenario: Valid additional verification

- **WHEN** a configured verification key matches the server's valid ML-DSA-65 signature
- **THEN** the connection authenticates and transfers application data

#### Scenario: Wrong or missing signature

- **WHEN** additional verification is configured but the signature is absent, malformed, or signed by another key
- **THEN** the connection fails and no proxied application data is accepted through that connection

#### Scenario: Malformed verification key

- **WHEN** configuration preparation receives an invalidly encoded or incorrectly sized verification key
- **THEN** preparation returns an option-specific error and the current committed profile remains usable

### Requirement: Supported Xray options survive configuration conversion

Supported YAML profiles and provider content SHALL retain REALITY public keys, short IDs, SNI, fingerprints, explicit ML-KEM mode, optional ML-DSA verification, VLESS flow/encryption/packet encoding, and XHTTP settings through preparation and activation. For nested XHTTP download settings, REALITY `password` SHALL be accepted as the public-key alias with the same precedence as Xray, while legacy `publicKey` remains supported. XHTTP headers, path, host, mode, reuse settings, and separately configured download security SHALL retain their meaning. Invalid recognized security options MUST return an error rather than being discarded. These requirements SHALL NOT add direct proxy share-link intake to the application's URL import flow.

#### Scenario: Provider link carries current REALITY options

- **WHEN** supported provider content contains a VLESS link with explicit REALITY security options
- **THEN** conversion and activation preserve those options, including explicit false and any additional verification key

#### Scenario: Nested download REALITY uses the current key name

- **WHEN** XHTTP download settings contain REALITY `password`, `serverName`, `fingerprint`, `shortId`, and `mldsa65Verify`
- **THEN** those settings apply to the download connection, independently of the upload connection, with `password` taking precedence over `publicKey` when both exist

#### Scenario: XHTTP extra headers and IPv6

- **WHEN** an XHTTP configuration includes `extra.headers` and an IPv6 server address
- **THEN** the configured headers reach the server and the connection uses a valid IPv6 authority

#### Scenario: Invalid converted security option

- **WHEN** a required provider entry contains a malformed recognized security option
- **THEN** preparation fails with an actionable error, without silently omitting that option or publishing a weakened replacement

### Requirement: Existing Xray transport behavior remains usable

The Core update SHALL preserve tested VLESS Vision, XUDP, VLESS encryption, VLESS over TLS/WebSocket/gRPC, VMess over TLS/WebSocket, and Trojan over TLS/gRPC behavior where those combinations are supported by the selected Xray server. XHTTP SHALL support the tested auto, packet-up, stream-up, and stream-one modes and independent download settings. The compatibility record SHALL identify unsupported combinations explicitly rather than generalizing one successful handshake to all Xray features.

#### Scenario: Existing encrypted and UDP traffic

- **WHEN** a supported fixture uses VLESS encryption or XUDP
- **THEN** the expected stream or datagram payload reaches the destination and returns correctly after the Core update

#### Scenario: Existing TLS transports

- **WHEN** a previously supported TLS, WebSocket, or gRPC fixture is exercised against a server that still implements that transport
- **THEN** application data succeeds with unchanged credential and certificate-verification semantics

#### Scenario: XHTTP mode coverage

- **WHEN** each supported XHTTP mode is exercised with its matching server configuration
- **THEN** it transfers application data, including the independent download configuration where that mode supports it

### Requirement: Reproducible compatibility evidence

The release candidate SHALL have a recorded Core revision, dependency versions, exact Xray test versions and artifact identities, configuration cases, and test results. Interoperability checks SHALL use controlled local destinations and assert authenticated proxy data transfer, with explicit failures for unavailable test prerequisites. A reported failure lacking a reproduction MUST remain identified as unconfirmed even if related compatibility tests pass.

#### Scenario: Repeating the compatibility suite

- **WHEN** a developer runs the documented suite from a clean checkout with its declared prerequisites
- **THEN** the same pinned server artifacts and fixtures are used and pass/fail results are produced for each required case

#### Scenario: Server version alone is known

- **WHEN** the user's report identifies Xray 26.3.27 and a possible minimum-version issue but lacks a failing fixture or diagnostic log
- **THEN** the compatibility report distinguishes tested minimum-version behavior from an unconfirmed explanation of that user's failure

# Spec Delta

## Purpose

Make subscription import, server choice, and connection control directly accessible to new users while keeping advanced functionality in a dedicated Settings section.

## ADDED Requirements

### Requirement: Unambiguous connection feedback

The central button and status indicator SHALL be green when fully connected and neutral gray when disconnected. Connecting, disconnecting, suspended/proxy-only operation, and errors SHALL have distinct text, icons, and visual treatment in light and dark themes. Progress SHALL disable repeated connection actions while an explicit one-shot Cancel action permits stopping pending startup. A failed stop SHALL remain actionable and MUST NOT be presented as successful disconnection. Errors SHALL use actionable localized copy rather than raw platform exceptions.

#### Scenario: Repeated transition taps

- **WHEN** a user taps Connect or Disconnect repeatedly before the first request finishes
- **THEN** only one same-intent UI request is submitted, progress remains visible, and completed state comes from platform observation

### Requirement: Android disconnection releases owned resources

Native ServiceState SHALL remain the intent owner. Stop SHALL attempt cleanup even after partial startup, close the owned TUN and traffic resources, stop background modules, remove the foreground notification, and release service bindings. A late notification update MUST NOT recreate a stopped notification. STOPPED SHALL only be published after the owned cleanup succeeds; failed teardown SHALL report a retryable failure without converting it into a new start intent. Platform acknowledgements MUST NOT substitute for observed completion.

#### Scenario: Stop fails or a resource is partially initialized

- **WHEN** teardown fails or startup has not established a run timer
- **THEN** cleanup is still attempted, a failure is visible and retryable, and the app does not silently reconnect or claim confirmed disconnection

#### Scenario: Start is requested after incomplete teardown

- **WHEN** a start is requested after teardown failed, including proxy-only operation or startup without a run timer
- **THEN** native arbitration rejects the start with a retryable disconnect error until owned cleanup succeeds
- **AND** it does not reuse retained runtime/binding bookkeeping as proof of connection or begin background configuration preparation
- **AND** a successful Disconnect retry allows a later explicit start to establish the service normally

#### Scenario: Delayed cleanup resolves a stop failure

- **WHEN** superseded background startup finishes and its final cleanup succeeds after an earlier failed stop
- **THEN** the current stop intent becomes Disconnected without retaining the resolved stop error
- **AND** unrelated startup/configuration errors remain visible, failed cleanup remains retryable, and no late observation overwrites a newer request

#### Scenario: Background stop or permission revocation

- **WHEN** Android revokes the VPN or notification/system controls stop it while Flutter is absent
- **THEN** native cleanup runs and reattaching Flutter reads the resulting state without restarting a manually stopped VPN

#### Scenario: Android Always-on VPN controls the service

- **WHEN** Android Always-on VPN is enabled independently of app auto-connect
- **THEN** in-app guidance explains that Android may restart the service and that Always-on and blocking without VPN are controlled in Android VPN settings
- **AND** an Android-owned warning notification is not treated as proof that the app's tunnel is active

### Requirement: Import-first home

Without a usable profile, the initial screen SHALL present Scan QR, Paste from clipboard, and manual URL entry without requiring navigation to another primary section. A successful import SHALL reveal the connection controls and server list on Home. After setup, a visible compact Import/Replace action SHALL reopen the same intake flow. Importing SHALL show progress and recoverable errors without hiding or clearing a previously committed server list.

Import/replacement and Settings' manual update SHALL display the current preparation/commit stage, including completed/total provider resources where applicable. A cancelled import SHALL show cancellation cleanup before enabling another submission. The replacement dialog SHALL ignore outside taps, block back/cancel during final commit, and offer Close when idle. Errors SHALL not expose credential-bearing download details. A timeout SHALL provide localized connection-check/retry guidance. Replacement help SHALL explain both failure preservation and possible traffic interruption on successful activation.

#### Scenario: A slow import remains understandable

- **WHEN** required server/rule lists or geographic resources take time to prepare
- **THEN** the user sees the current stage rather than an unexplained generic import spinner, without a misleading overall percentage

#### Scenario: Manual update times out

- **WHEN** a download deadline expires during Settings' manual update
- **THEN** progress clears, the saved configuration remains unchanged, and localized retry guidance appears without exposing the subscription URL

#### Scenario: First launch

- **WHEN** a new user opens the app with no profile
- **THEN** the three import methods and the Settings gear are available on the initial screen

#### Scenario: Successful onboarding

- **WHEN** import succeeds
- **THEN** Home shows the server list with Auto selected and the connect control, without an intermediate profile-management screen

#### Scenario: Camera permission is denied

- **WHEN** a user denies camera permission or cancels scanning
- **THEN** they can return to the import surface and use Paste or manual entry without changing the existing profile

### Requirement: QR intake works across shipped platforms

Android SHALL offer live camera QR scanning and image import. Desktop SHALL offer QR decoding from a chosen image through the Scan QR action; a desktop camera SHALL NOT be required. Invalid QR content, missing codes, decoder failure, and picker cancellation MUST return the user to a usable import flow and MUST NOT change the committed profile. Repeated scanner detections SHALL produce at most one import submission for the accepted scan.

#### Scenario: Desktop user imports a QR image

- **WHEN** a user on Windows, macOS, or Linux chooses an image containing a configuration URL
- **THEN** the application decodes the URL and submits it through the same intake flow as manual entry

#### Scenario: Scanner detects the same code repeatedly

- **WHEN** multiple detections arrive before the scanner closes
- **THEN** the accepted scan submits only one import request

### Requirement: Focused main screen

With a usable profile, Home SHALL prominently display a compact circular connect/disconnect button, a text connection status, the selected target, and the unified server list. Phones SHALL use a compact connection header; wide and short landscape windows SHALL place controls beside the list. Control and inventory regions SHALL scroll independently when necessary. Node rows SHALL use consistent compact spacing and typography without reducing interactive targets below 48 logical pixels; names, selection, and latency MUST remain readable. Wide Home and top-level Settings content SHALL have bounded widths. Dashboard customization, traffic charts, routing toggles, profile lists, and diagnostic tools MUST NOT occupy the default Home surface.

#### Scenario: Long server list

- **WHEN** a profile contains enough servers to require scrolling
- **THEN** the user can scroll the list and still reach the connect/disconnect control without changing screens

#### Scenario: Short window with large text

- **WHEN** Home is displayed in a short landscape window or with text enlarged to 250%
- **THEN** controls remain independently scrollable, the server inventory retains usable space, and rows expand or stack latency without overlapping adjacent content
- **AND** the latency action remains accessible by its localized label or named icon without duplicate concurrent tests

#### Scenario: No usable profile

- **WHEN** there is no committed profile or import is not yet complete
- **THEN** the application does not start an empty VPN configuration from the connect control

### Requirement: Sticky observed connected node

While fully connected, Home SHALL keep a read-only current-node card above the scrolling inventory. It SHALL occupy its own layout space, include connected text and an icon, and display the leaf node reported by Core rather than assuming the selected server or automatic group is the active outbound. Auto/Fallback and provider context SHALL be shown where applicable. Resolving/unavailable observations and custom routing SHALL retain truthful explanations rather than stale node claims. Long names SHALL remain available through semantics and a tooltip. The card MUST NOT change selection, scroll position, or VPN state.

#### Scenario: Scroll while Auto or Fallback changes its outbound

- **WHEN** a connected user scrolls a long server list and Core reports a new active node
- **THEN** the fixed card updates to that observed node, remains visible without covering rows or controls, and does not switch the committed selection

#### Scenario: Connection leaves Connected

- **WHEN** the observed phase becomes disconnecting, disconnected, failed, suspended, or proxy-only
- **THEN** the connected-node card is removed immediately and the main status describes the current phase without waiting for decorative animation

#### Scenario: Active outbound is unknown or routing is custom

- **WHEN** the VPN is connected but the outbound cannot be resolved, or multiple routing rules can choose different nodes
- **THEN** the fixed card identifies that condition instead of claiming the selected node handles all traffic

### Requirement: Connection status reflects confirmed operation

The application SHALL display Connected, Connecting, and Disconnected, with Disconnecting or Suspended when needed to accurately represent a transition or configured pause. Core process readiness, an optimistic command acknowledgement, or a running timer alone MUST NOT be treated as confirmation that the VPN is connected. Connected SHALL mean the requested traffic-handling mode is established, not that every remote server or internet destination is reachable. If the platform operates only as a system proxy, the UI SHALL identify that mode instead of implying a full-device VPN is active.

#### Scenario: Core is ready but VPN is off

- **WHEN** the Core has initialized but no VPN connection is active
- **THEN** Home displays Disconnected

#### Scenario: Start awaits platform permission

- **WHEN** a connect request is waiting for permission or service/TUN setup
- **THEN** Home displays Connecting and does not display Connected until operation is confirmed

#### Scenario: Permission or startup fails

- **WHEN** VPN permission is denied or the current startup attempt fails
- **THEN** Home shows a useful retryable error without claiming successful connection, and retains the profile/selection

#### Scenario: Reattach before native state arrives

- **WHEN** Android Home has not yet received its native run-state snapshot
- **THEN** it displays Checking connection with repeated actions disabled rather than assuming the VPN is disconnected

#### Scenario: Initial Android status in a minified release

- **WHEN** a subscription is imported or the app attaches to Android's service in a release build
- **THEN** snapshot and event messages use explicit, stable JSON keys and state names independent of code obfuscation
- **AND** an observed STOPPED state enables Connect without starting the tunnel or requesting VPN permission

#### Scenario: Status check fails or never answers

- **WHEN** Android returns missing or malformed status, the channel fails, or a snapshot takes longer than five seconds
- **THEN** Home leaves Checking connection and shows an actionable status error with Try again and safe Disconnect
- **AND** the app does not assume Disconnected or offer Connect based on an unknown state
- **AND** concurrent status checks coalesce, a valid snapshot/event clears the status error, and late failure cannot replace a newer native observation or unrelated cleanup failure

### Requirement: Prominent successful connection and latency feedback

Confirmed VPN connection SHALL use a bright green circular control and status badge with contrasting text/icons in light and dark themes. Measured node latency SHALL use a larger bold milliseconds label on a contrasting badge. Timeout, unreachable, failure, and untested labels SHALL remain explicit and localized; fastest highlighting MUST NOT change selection. Layouts MUST remain usable with large text on narrow screens.

The confirmed-connected button SHALL have a soft, non-pulsing green glow adapted to the theme. Color, shadow, and ordinary status-size transitions SHALL be subtle and short, without delaying observed status text, errors, or action guards. Reduced-motion preferences SHALL disable decorative transitions and replace the connection/latency-toolbar spinning progress indicator with a static busy indicator. Leaving Connected SHALL remove the connected glow; an error MUST remain immediately visible even during an interrupted transition.

#### Scenario: Theme and motion preferences

- **WHEN** a confirmed connection is displayed in either light or dark theme
- **THEN** the glow remains subtle, foreground text/icons remain contrasting, and no continuous decorative animation runs
- **AND** with reduced motion enabled, connection and test actions preserve their guards and status feedback without decorative animation

#### Scenario: Read connected feedback and measured latency

- **WHEN** native observations confirm a VPN connection and latency testing returns a measurement
- **THEN** the connect control and status badge are bright green, the measured milliseconds are prominent, and the fastest result remains separately identified
- **AND** disconnecting removes the connected presentation only according to actual state transitions

#### Scenario: Desktop falls back to proxy-only operation

- **WHEN** full-device TUN cannot be established but the existing platform flow establishes system-proxy operation
- **THEN** Home identifies the active connection as proxy-only rather than reporting that full-device VPN coverage was established

### Requirement: Connection control follows latest intent

The central button SHALL connect when disconnected, disconnect when connected, and allow cancellation while connecting. Repeated taps and late completion events MUST converge on the latest user intent. Opening Settings or changing screens MUST NOT start, stop, or recreate the connection. External stop, revoke, suspension, and service-loss events SHALL update Home through the same state observation used for the button.

#### Scenario: Cancel an in-progress connection

- **WHEN** the user cancels a connection while startup is pending
- **THEN** a late start completion does not leave the VPN running or Home showing Connected

#### Scenario: Stop from outside Home

- **WHEN** the VPN stops through a notification, Quick Settings, tray action, permission revocation, or service failure
- **THEN** Home reflects the resulting state without waiting for another button tap

### Requirement: Advanced features live in Settings

A small gear icon in the top trailing corner SHALL open a dedicated Settings section from both empty and configured Home. Settings SHALL contain existing advanced network/DNS/routing options, configuration tools, diagnostics, application preferences, and backup/restore subject to platform availability. It SHALL provide refresh and replacement actions for the single profile without reintroducing profile switching. Returning from Settings SHALL return to the same Home selection and actual connection state. The primary interface SHALL NOT retain the former multi-section bottom bar or desktop sidebar.

#### Scenario: Open advanced options

- **WHEN** the user opens the gear icon
- **THEN** existing advanced configuration and diagnostic screens are reachable within Settings

#### Scenario: Back from Settings

- **WHEN** the user uses back navigation from Settings
- **THEN** Home reappears with the committed profile and current connection state intact

### Requirement: Accessible and localized controls

All new user-visible labels and errors SHALL support the app's existing locales. The gear, QR, paste, and connect controls MUST have accessible names and usable touch targets. Connection state and server selection MUST be conveyed by text/semantics as well as color. The layout SHALL support keyboard navigation, large text, narrow mobile screens, and resizable desktop windows without hiding essential controls or overlapping native window chrome.

#### Scenario: Large text and assistive technology

- **WHEN** the user enables large text or a screen reader
- **THEN** import, server selection, Settings, and connection state remain understandable and actionable

#### Scenario: Resize a desktop window

- **WHEN** a desktop window changes between narrow and wide sizes
- **THEN** Home keeps its selection and connection control accessible while preserving native window controls and keyboard focus

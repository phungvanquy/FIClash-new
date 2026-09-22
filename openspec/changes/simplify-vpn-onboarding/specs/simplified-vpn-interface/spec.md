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

With a usable profile, Home SHALL prominently display a large circular connect/disconnect button centered horizontally in the main control area, a text connection status, the selected target, and the unified server list. The connect control SHALL remain directly accessible while browsing a long list. Dashboard customization, traffic charts, routing toggles, profile lists, and diagnostic tools MUST NOT occupy the default Home surface.

#### Scenario: Long server list

- **WHEN** a profile contains enough servers to require scrolling
- **THEN** the user can scroll the list and still reach the connect/disconnect control without changing screens

#### Scenario: No usable profile

- **WHEN** there is no committed profile or import is not yet complete
- **THEN** the application does not start an empty VPN configuration from the connect control

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

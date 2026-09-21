# Spec Delta

## Purpose

Let users install and maintain one VPN subscription without risking a working configuration when a replacement or refresh fails.

## ADDED Requirements

### Requirement: Common URL intake

The application SHALL accept one HTTP or HTTPS configuration URL through manual entry, an explicit clipboard-paste action, or QR decoding. A token SHALL mean the credential embedded in that URL. All three methods and existing installation deep links MUST follow the same validation and replacement rules. Leading and trailing whitespace SHALL be removed without changing the URL's path, query values, or encoding.

#### Scenario: Equivalent inputs

- **WHEN** the same valid subscription URL is entered manually, pasted, scanned, or supplied through a supported installation link
- **THEN** each path fetches and prepares the same configuration and produces the same replacement outcome

#### Scenario: Unsupported or empty input

- **WHEN** intake receives empty clipboard contents, malformed text, a bare activation code, a proxy share link, or multiple URLs
- **THEN** the application reports a recoverable input error without fetching an inferred address or changing the current profile

#### Scenario: Clipboard privacy

- **WHEN** the app opens without the user invoking Paste
- **THEN** the application does not read the clipboard

### Requirement: One usable profile

The application SHALL expose and operate on at most one usable profile. There SHALL be no profile-switching list or add-another-profile behavior in Home, Settings, tray menus, or installation links. Before the first successful import the application SHALL remain in the import state.

#### Scenario: First successful import

- **WHEN** a valid configuration is imported with no existing profile
- **THEN** that configuration becomes the sole profile, its server list is shown, and the VPN remains disconnected until the user connects

#### Scenario: Replacement succeeds

- **WHEN** a new configuration is successfully prepared and committed
- **THEN** it immediately becomes the sole profile and its server list replaces the old list without another confirmation or profile-selection step

### Requirement: Replacement is committed only when usable

The application MUST prepare fetched content, required provider data, and the effective configuration before publishing a replacement. A usable configuration SHALL contain at least one supported proxy server; successful downloading or YAML decoding alone SHALL NOT constitute successful import. Unreachable latency probes alone SHALL NOT invalidate an otherwise usable configuration. Success SHALL be reported only after durable profile storage and required Core activation have succeeded.

#### Scenario: Empty or semantically invalid configuration

- **WHEN** fetching succeeds but the response is malformed, defines an unsupported proxy, has invalid references, or contains no usable servers
- **THEN** import fails and the previous profile remains selected and unchanged

#### Scenario: Required provider fetch fails

- **WHEN** the replacement depends on provider content that cannot be fetched or validated during preparation
- **THEN** the application rejects the replacement without replacing the current profile or applying an empty/default configuration

### Requirement: Failed imports preserve the working setup

Fetch, validation, preparation, cancellation, and storage failures MUST preserve the previous profile's URL, configuration content, metadata, and server selection. Preparation failures MUST NOT stop or reconfigure an existing VPN session. If a failure occurs during final activation or persistence, the application MUST retain or restore the prior committed configuration and report the actual connection state. A failure to restore the connection SHALL be surfaced without deleting the prior profile or claiming that it is connected.

#### Scenario: Failed replacement while connected

- **WHEN** a replacement download times out while the current VPN is connected
- **THEN** the existing configuration and VPN session continue, the previous server list remains visible, and the user can retry the import

#### Scenario: Final storage or activation failure

- **WHEN** final replacement activation or durable storage fails after preparation
- **THEN** import does not report success and the previous committed profile and selection remain available, with connection recovery attempted through the normal lifecycle

#### Scenario: First import fails

- **WHEN** import fails before any profile has been installed
- **THEN** the app remains in the import state with the error and import methods available

### Requirement: Replacement preserves connection intent

A successful replacement SHALL preserve the latest requested running state. Importing while disconnected MUST NOT connect automatically. Importing while connected SHALL apply the replacement through the existing connection lifecycle without requiring another connect action. A user disconnect request during import MUST take precedence over reconnecting after replacement.

#### Scenario: Replacement while running

- **WHEN** a replacement commits while the VPN is running and no newer stop request exists
- **THEN** the VPN uses the new configuration and the displayed status reflects any transition

#### Scenario: Disconnect during import

- **WHEN** the user disconnects before an in-flight import commits
- **THEN** the successful import installs the new profile without turning the VPN back on

### Requirement: Concurrent work cannot publish stale profiles

For overlapping explicit imports, only the latest submitted request SHALL be eligible to commit. A superseded or cancelled import MUST NOT replace the current profile later, even if the newer import fails. Refresh results SHALL be tied to the committed profile revision they started from and MUST NOT resurrect a replaced profile. Refreshes SHALL obey the same failure-preservation rules as imports.

#### Scenario: Newer import fails before an older one completes

- **WHEN** import A starts, import B supersedes it and fails, and A later completes
- **THEN** neither result replaces the profile that was committed before those requests

#### Scenario: Refresh overlaps replacement

- **WHEN** a refresh of the old profile finishes after a new import commits
- **THEN** its result is discarded and the new profile remains the sole profile

### Requirement: Restart recovers a complete committed profile

After interruption during replacement, the application SHALL recover either the previous committed profile or the fully committed replacement. It MUST NOT expose a partial file, missing active-profile reference, or two usable profiles. Recovery SHALL complete before automatic connection or background refresh begins.

#### Scenario: Process interruption during commit

- **WHEN** the application restarts after termination between configuration staging, persistent commit, and cleanup
- **THEN** it recovers one complete committed profile and a consistent selection before starting the VPN

### Requirement: Migration and restore enforce the single-profile contract

For existing multi-profile data, the application SHALL retain the selected usable profile, falling back to the first usable profile in the existing order. Selection SHALL use locally available data without requiring a successful network fetch. Before removing surplus active records or associated files, it MUST preserve the original profiles and associated data in a recovery backup available from Settings. If preservation fails, migration MUST retain the source data, expose at most the retained profile, and allow recovery to be retried. Backup restore and file import SHALL select and validate one candidate using the same replacement guarantees.

#### Scenario: Existing user upgrades offline

- **WHEN** the selected profile is locally usable and additional profiles exist during an offline upgrade
- **THEN** the selected profile remains usable and the surplus profiles are preserved in the migration backup rather than offered as switchable profiles

#### Scenario: Selected legacy profile is missing

- **WHEN** the selected profile cannot be used but another locally usable profile exists
- **THEN** migration retains the first usable profile in the existing order and preserves all source data in the recovery backup

#### Scenario: No legacy profile is usable

- **WHEN** migration finds no locally usable profile
- **THEN** the app opens the import state while preserving legacy data for recovery from Settings

#### Scenario: Restore contains several profiles

- **WHEN** a backup with several profiles is restored
- **THEN** its selected usable profile, or first usable fallback, is prepared as one replacement and an unsuccessful restore leaves the current profile unchanged

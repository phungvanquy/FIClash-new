# Proposal

## Why

FlClash currently separates configuration import, profile selection, proxy groups, and connection controls across several screens. A single-purpose home screen will let a new user import a subscription, choose a server, and connect without first learning the application's advanced controls.

## What Changes

- Replace the default dashboard and primary navigation with an import-first VPN home screen. Offer QR scanning, an explicit clipboard-paste action, and manual URL entry directly on first use; keep replacement import accessible after setup.
- Treat "VPN token" as a subscription/configuration URL containing its token, as clarified by the user. Continue supporting Mihomo-compatible configuration content and existing installation links; standalone activation codes and proxy share-link conversion are outside this change.
- **BREAKING**: Support one usable profile. A successful import immediately replaces it without an additional selection or confirmation step. Fetch, validation, preparation, cancellation, or persistence failures retain the previous profile and selection. Apply the same protection to refreshes and alternate import paths.
- Migrate existing installations by retaining the selected usable profile, or the first usable profile in the existing order if necessary. Preserve the old multi-profile data in a recovery backup before removing surplus active records.
- Show individual servers, `Auto`, and `Fallback` in one list. Provide app-managed automatic groups even when the subscription does not define them; default a newly imported profile to `Auto`.
- **BREAKING**: Use the chosen server or automatic group for all traffic handled by the VPN by default, as confirmed by the user. Preserve configuration routing and advanced proxy-group controls behind Settings.
- Place a large circular connect/disconnect control centrally above the server list. Display actual VPN connection progress and failures rather than interpreting Core readiness as a successful VPN connection.
- Move advanced configuration, diagnostics, appearance, backup/restore, and other existing tools into a Settings section reached through a small corner gear icon. Retain platform navigation, accessibility, and localization support.
- Post-build review: add explicit connected/disconnected colors, guarded transitions and retryable errors; snapshot-scoped node latency testing with fastest highlighting; and failure-preserving Android teardown, background stops, and Always-on guidance.

## Capabilities

### New Capabilities

- `single-profile-import`: Shared URL intake, staged replacement and refresh, failure preservation, concurrency control, and migration to one usable profile.
- `unified-server-selection`: A flat server inventory with operational Auto/Fallback entries, persistent selection, and explicit simple-versus-custom routing behavior.
- `simplified-vpn-interface`: Import-first home, central connection control, accurate connection status, and advanced settings navigation across supported platforms.

### Modified Capabilities

None. The project currently has no main OpenSpec specifications.

## Impact

- Flutter surfaces: `lib/pages/home.dart`, `lib/pages/scan.dart`, `lib/views/navigation.dart`, dashboard, profiles, proxies, and tools/settings views.
- State and storage: profile/setup/proxy/backup actions, derived providers, profile/config models, Drift DAOs, bootstrap migration, profile files, and cleanup/backup paths.
- Core integration: candidate configuration preparation and activation must avoid the existing failure path that replaces the running configuration with defaults. The current Core validator only unmarshals YAML; it is insufficient to establish that an imported profile is usable.
- Approved implementation adjustment: add a narrowly scoped detached preparation feature to the maintained Mihomo fork, since its ordinary parser mutates active process settings even before an invalid candidate is rejected. Keep normal apply compatibility and publish candidate state only during activation.
- Platform feedback: expose Android's existing service run state to Flutter and observe desktop listener/system integration outcomes while preserving lifecycle ownership. No replacement VPN engine or Mihomo transport changes are planned.
- Tests: import/storage failure injection, migration and restore, server generation/routing, connection state contracts, home/settings interactions, and platform smoke tests. Update all four ARB locales and generate affected output during implementation.
- Reuse existing Flutter, Drift, and Core facilities. The installed `mobile_scanner` supports Android/macOS but does not register Windows/Linux implementations, so add desktop-capable image QR decoding behind the same intake interface.

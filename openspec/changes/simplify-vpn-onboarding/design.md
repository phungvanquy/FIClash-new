# Design

## Context

See `proposal.md` for motivation and the three delta specifications for behavior. The user confirmed that tokens are credentials within subscription URLs and that simple selection should govern all captured VPN traffic by default.

Observed implementation constraints:

- `lib/pages/home.dart` builds a paged shell with bottom navigation or a desktop sidebar. `lib/views/navigation.dart` registers Dashboard, Proxies, Profiles, Tools, and diagnostic destinations. `ToolsView` already links most settings screens.
- `ProfilesAction.addProfileFormURL` downloads into a new `Profile`, then `putProfile` adds it to the list. `Profiles.put` publishes optimistically and does not return an awaitable durable commit. `updateProfile` publishes metadata before the download completes.
- `Profile.saveFile` validates a temporary file and copies it into the profile file. It does not coordinate source files, database rows, selection preferences, generated `config.yaml`, and running Core state as one operation.
- `core/hub.go:handleValidateConfig` only calls `config.UnmarshalRawConfig`. `core/common.go:applyConfig` substitutes the default configuration on parse failure. `SetupAction._setupConfig` also produces an empty configuration on build failure. Neither behavior is suitable for probing a replacement while preserving an active VPN.
- `CoreManager` automatically reapplies when `currentProfileIdProvider` changes. The existing listener would apply twice or race a staged replacement unless it is integrated into the new commit flow.
- Proxy selection is group/name based. `ProxiesAction.changeProxyDebounce` persists optimistically and its failure rollback lacks a revision check. `makeRealProfileTask` preserves arbitrary source keys while applying app overrides.
- Android already owns STARTING/STARTED/STOPPING/STOPPED in `ServiceStateMachine`; the Flutter service bridge exposes an optimistic start acknowledgement and runtime query, not that complete state stream. Desktop Core readiness is independent of listeners, TUN, and system-proxy establishment.
- `BackupAction.applyRestore`, bootstrap, automatic refresh, deep links, file import, tray menus, and store cleanup all assume multiple profiles and need to obey the new invariant.
- The installed `mobile_scanner` 7.4.0 registers Android/macOS implementations but none for Windows/Linux. The current desktop image path therefore cannot be reused unchanged on every shipped platform.

## Goals / Non-Goals

**Goals:**

- Keep one committed profile snapshot as the source of truth and give import/refresh one awaitable success boundary.
- Keep failure-prone preparation separate from active routing and preserve enough durable state to recover after interruption.
- Build Home as a projection of existing domain/platform state, with no widget-owned VPN lifecycle.
- Retain existing advanced functionality and source configurations under Settings while making simple routing deterministic.

**Non-Goals:**

- Implement Xray transport support, standalone proxy-URI conversion, activation-code redemption, a subscription backend, or a new VPN engine.
- Replace Android service arbitration, desktop process leases, or the Helper protocol.
- Promise seamless preservation of individual TCP sessions during a successful configuration replacement, or treat connection status as proof of internet reachability.
- Add iOS/web support or desktop live-camera capture. Desktop QR image import satisfies the common intake contract.

## Decisions

### 1. Replace the primary shell with Home and a pushed Settings route

Keep `HomePage` under the existing manager stack and desktop window header. Replace its multi-destination content with a dedicated VPN home view. Push Settings and its detail screens through the existing navigator; retain focus, back handling, overlays, platform chrome, and app-wide feedback helpers. Remove the bottom navigation/sidebar from the primary experience and migrate persisted page labels to Home.

The configured layout has a trailing gear and compact Import action, a centered connection area, and a separately scrollable server list. On a short window, scale the connection area's spacing and button size within accessible limits; do not let a long list push the control off-screen.

```text
FlClash               Import   [gear]

             Disconnected
            (   Connect   )
                 Auto

Servers
  selected  Auto       Best available
            Fallback   First available
            Server A
            Server B
```

With no profile, the same shell shows the three intake methods instead of a server list. There is no wizard, new-profile naming step, or success confirmation gate. Reuse Material You colors, `AppShape.circle`, shape tokens, list rows, and sheets. Keep dashboard-style statistics and customization out of Home; retain useful diagnostics within Settings.

Alternative considered: keep the current shell and add a beginner dashboard. Rejected because Profiles, Proxies, and Tools would still compete as primary destinations and retain the extra navigation steps.

### 2. Normalize all intake through one replacement coordinator

Introduce a provider-owned import coordinator, reached by manual input, explicit clipboard paste, camera/image QR results, existing `install-config` links, and advanced file import. It accepts an input source, validates one HTTP(S) URL where applicable, and delegates to a storage/preparation service. Existing methods can become adapters during the transition, but must not call the old append behavior.

Trim only surrounding whitespace; preserve credential-bearing URL bytes and avoid logging full URLs in the touched intake/deep-link paths. Use the existing request configuration, headers, and subscription metadata parsing. Make malformed subscription metadata a controlled result, never a partial profile mutation. Restore a usable import form after cancellation or failure.

Use a monotonically increasing request revision for explicit imports and a committed-profile revision for refresh. A newer explicit import invalidates the previous one even if it later fails. Check revisions after asynchronous boundaries and again before commit; serialize the final commit with setup/refresh writes. Keep request intent ownership in the coordinator and connection intent ownership in the existing lifecycle. A stop command is never blocked on a network download.

Alternative considered: remove old profiles after the existing add method returns. Rejected because its persistence is optimistic, activation is implicit, and competing imports or refreshes can republish stale data.

### 3. Use durable staging and an awaited commit, not delete-then-import

Add a narrow single-profile repository around Drift and profile storage. Existing `profiles` data can remain for compatibility, but normal writers must use an awaited transaction that produces one committed profile; ordinary metadata/selection edits may update only that profile. The committed row and revision become authoritative. Keep `currentProfileId` preferences only as a compatibility mirror, reconciled from durable state before startup.

Represent each candidate with a new immutable content generation: original YAML, confined provider resources, effective YAML, normalized server catalog, and source metadata. Add explicit revision/path metadata to the profile storage model instead of overwriting `<id>.yaml` before commit. Adjust Core source-file resolution and backup manifests accordingly, while reading legacy `<id>.yaml` during migration. Store the cached catalog with that same generation so Home can render offline.

The operation is:

1. Capture the committed snapshot and a connection-intent revision. Allocate a unique unpublished generation directory owned by this request. Its final paths stay stable through preparation and activation; publishing changes references, not the paths held by prepared providers.
2. Fetch the subscription and required provider resources into staging. Build the candidate source/effective configuration and catalog without publishing profile state.
3. Ask Core to prepare the candidate and validate its actual adapters/references and nonempty server inventory. No live apply, profile-pointer change, listener restart, or default-config fallback occurs here.
4. Recheck import/profile revisions. Under the setup commit scheduler, flush candidate files and persist a recovery journal referencing the old and candidate generations. Keep the old generation intact.
5. Activate the prepared candidate through the Core facade, preserving the latest running intent. Core loss invalidates preparation and requires retry; a disconnected VPN does not prevent its initialized Core from preparing a configuration without starting listeners. Update the sole profile, revision, selection/routing metadata, and associated profile-owned data in an awaited database transaction only after activation succeeds. A new import starts with Auto/simple routing; a refresh preserves compatible preferences.
6. Publish the committed snapshot, synchronize the compatibility preference/shared state, and report success. Suppress the old profile-ID listener's duplicate apply by making it consume the committed revision through the same coordinator.
7. Clean candidate/old resources only after durable completion; cleanup failure is retriable maintenance, not a failed import after success has been reported.

If preparation fails, discard only candidate resources. If activation or the database transaction fails, keep/reapply the old generation through the same setup scheduler and report failure. On restart, the durable committed revision resolves the journal: old database revision means abandon the candidate and reconstruct the old `config.yaml`; new revision means finalize candidate recovery and compatibility mirrors. Do this before automatic start or refresh. A failed post-commit preference mirror is repaired from the committed revision, not treated as a reason to delete the new profile.

`StoreAction.shakingStore`, provider-cache cleanup, backup, and restore must understand generation references and protect both journal-pinned generations. Profile-owned rules/groups follow the selected profile in the transaction; shared scripts and global rules are not indiscriminately deleted. Migration archives live outside ordinary profile cleanup roots.

Alternative considered: an in-memory rollback after overwriting the existing file. Rejected because app termination and disk-write failures would still leave irrecoverable partial state. SQLite alone is also insufficient because configuration files and runtime routing live outside its transaction.

### 4. Add a prepared-configuration path with detached Core parsing

Add narrowly scoped prepare/activate/discard operations through `CoreController`, `CoreHandlerInterface`, the shared method envelope, and `core/` wrapper handlers. Preparation accepts only repository-owned candidate paths/revisions, returns an opaque handle plus normalized inventory, and owns its resources until activation or discard. Handles are scoped to a Core session and cannot survive a restart or activate another request's candidate.

Use Mihomo's full parser, not `UnmarshalRawConfig`, and reject unsupported adapters/references before live apply. Preparation must not call the existing fallback-on-error `applyConfig`. Final activation uses the already prepared candidate rather than re-fetching potentially different remote content; preserve the previous snapshot until durable commit completes. Extend the same safe path to refresh and routing-mode changes so Home cannot be invalidated by a background bypass. Existing process/service owners still perform start/stop work.

The maintained `core/Clash.Meta` fork will expose a detached preparation capability. This narrowly scoped feature is required because the ordinary full parser temporarily changes live general settings and publishes proxy names before later validation can fail. A wrapper lock cannot protect traffic-processing goroutines from those writes. User approval for this scope adjustment is recorded in `implementation-review.md`.

Detached preparation must use candidate-local parsing settings and explicit resource ownership. It must not publish tunnel mode, resolver/dialer settings, proxy names, provider events, or background work into the active runtime. Activation is the only publication boundary. Keep existing normal apply behavior compatible; do not modify transports or platform lifecycle ownership. Error paths and explicit discard must release partially constructed adapters, providers, and timers, not just successful candidates.

Proxy-provider initialization can start background health checks and close existing connections matching the provider name. Stage required remote provider bytes separately, validate using generation-scoped provider identities/cache paths, and remap generated references consistently while retaining source names for display and custom configuration. Separate candidate provider loading from activation of refresh/health-check scheduling and events. Prepared activation must use the validated resources without another remote fetch. Generation namespacing remains defense in depth, not a substitute for detached parsing.

Activation and teardown must preserve `configMu`/`selectMu` ordering. Do not add coverage instrumentation under `core/`; verify the wrapper and changed fork packages with Go tests and Dart protocol contract tests. Deterministic in-flight tests must assert active settings and names are unchanged during preparation as well as after rejection/discard; final-state-only assertions would miss a temporary direct-routing change. Include late rule failure, colliding provider names, candidate cleanup, and valid prepared activation.

Alternative considered: validate by applying the candidate and switching back on error. Rejected because the current fallback overwrites the working tunnel and provider initialization can disturb existing connections before an error is reported.

Alternative considered: validate in an isolated process. This avoids shared globals during validation, but adds a cross-platform process/service mechanism and cannot transfer prepared in-memory resources directly into the existing Core. The approved detached parser feature preserves the planned prepare/activate contract without that architectural expansion.

### 5. Create managed selection groups with stable identities

Store a typed simple selection (`auto`, `fallback`, or a server identity) separately from the advanced `selectedMap`. Build the inventory from inline proxies and resolved providers, retaining source ordering and provenance. Exclude built-in direct/reject/compatible targets and policy-group containers; preserve transport settings and necessary dialer dependencies.

Generate collision-free internal identifiers for managed `select`, `url-test`, and `fallback` groups. They all use the same eligible server set. Default their empty fallback to rejection, never direct traffic. Reuse the configured health-test URL and Core URL-test/fallback behavior; ordinary reachability failures do not reject an otherwise valid import.

Keep UI labels independent of Core identifiers. If providers contain equal display names, give selectable targets provider-qualified identities and resolve them to unique Core targets, using provider-scoped generated selector aliases where necessary. Do not merge distinct endpoints by label or offer rows that the name-based Core selector cannot address unambiguously. Reject ambiguous duplicate identities inside one source as invalid input. Generated aliases and managed groups stay hidden from advanced source labels unless needed for diagnostics.

For simple routing, generate `mode: global` and set `GLOBAL` to the managed selector. Its selection is Auto, Fallback, or the chosen server. Preserve imported rules/groups and advanced override data in the original source generation. For custom routing, build the effective configuration with the saved advanced mode, source rules, and existing overwrite machinery. Home displays a custom-routing indicator; tapping a simple list entry deliberately switches back to simple routing. Store advanced selections independently so toggling modes does not destroy them.

Refreshes retain a server identity if present, otherwise choose Auto and notify. Scope selection RPCs and their rollback to both the committed profile revision and a selection revision. The older rollback path in `ProxiesAction` must not undo a newer selection. Subscription and provider-content refreshes use the app coordinator to stage and commit a new immutable generation; native timers, file watchers, and direct side-load/update calls must not mutate a prepared generation. A stale provider-loaded event cannot replace a newer profile's catalog.

On 2026-09-21 the user approved pausing automatic server/provider-list refresh while the Flutter app is closed. Resume due refreshes through the coordinator when Flutter returns, retaining normal scheduling while it is alive. The native VPN continues with the committed snapshot, and reachability health checks plus Auto/Fallback failover remain active; this policy pauses content refresh, not traffic or connection monitoring. Do not add a native/headless background commit owner for this change.

Alternative considered: label the first source URL-test/fallback groups as Auto/Fallback and expose one existing group. Rejected because subscriptions may omit those groups, contain several unrelated groups, or route different categories through different choices, conflicting with the confirmed simple-routing behavior.

### 6. Observe actual VPN operation without adding another lifecycle owner

Add a connection presentation model that combines desired intent, configuration readiness, observed service/listener state, traffic-handling mode, and the latest error. Keep it separate from `coreStatusProvider` and the optimistic runtime timer. Animations are local display state and cannot delay errors or rewrite domain state.

On Android, expose `ServiceState.runState` and a snapshot on attach/resume through a typed service observation channel with a monotonic observation revision. Keep `start`/`stop` acknowledgements optimistic. Feed STARTING/STARTED/STOPPING/STOPPED and failure information into Flutter without turning a native callback into new intent. Do not infer state by polling `getRunTime`: its current implementation calls `refresh()`, which rewrites the run-state value and can erase an in-flight transition. Cover permission denial, revoke, Always-on/Quick Settings, service loss, and Flutter reattachment.

On desktop, combine successful profile/listener application with actual TUN/system-proxy outcomes. `ProxyManager` currently logs a false result; expose that result as observed state so Home does not claim a successful connection when OS proxy installation failed. A connected Core IPC transport alone is not sufficient. Keep `DesktopCoreLifecycle`, leases, authorization, and existing Helper fallback behavior intact. Report a working system-proxy fallback as proxy-only, and keep Core readiness/restart diagnostics in Settings.

The maintained Core listener entry points must return their existing bind/creation errors to the wrapper, rather than only logging them. This result-propagation capability supports activation rollback and observed connection state; it does not move listener, process, or service ownership into Flutter. Existing callers may ignore the return value, while the prepared activation path must report failure to its coordinator.

Fresh setup uses Android VPN defaults and requests desktop TUN through the existing authorization flow where supported when the user connects. Preserve migrated platform/access-control preferences. Unavailable TUN can use the existing proxy fallback with an explicit mode label; no OS permission prompt is requested merely to import a URL. Suspension is shown as Suspended. Allow cancel while Connecting, and let all button/tray/tile paths converge through the same latest-intent orchestration.

Alternative considered: relabel `CoreStatus.connected` or `isStartProvider` as Connected. Rejected because the former means Core availability and the latter becomes true before Android VPN permission and binding complete.

### 7. Keep intake platform differences behind a QR adapter

Use camera scanning on Android and a selected-image decoder on all desktop targets. Keep `ScanPage`'s lifecycle/disposal handling, accept the raw decoded payload through the shared URL validator, and latch a successful detection before popping the page. Image picking must return data to the same coordinator rather than invoke an independent import from inside the scanner.

Use a portable image/QR decoding implementation behind the adapter for Windows/Linux; reuse the existing scanner on supported platforms. Decode off the UI thread where supported and bound input image size. Verify the chosen dependency against the repository's Dart/Flutter constraints and real PNG/JPEG fixtures rather than adding a desktop-only runtime exception. The exact decoder package is an implementation choice within this adapter; no new camera plugin or permission model is required.

Alternative considered: hide QR on unsupported desktops. Rejected because the requested import methods should remain available across the shipped application.

### 8. Rehome advanced features without retaining multi-profile behavior

Build Settings from `ToolsView`'s existing destinations and shared settings-row patterns. Include network/DNS/TUN/access rules, custom routing and its group editor, diagnostics/logs/resources, application preferences, appearance/language, hotkeys, about, and backup/restore as applicable. Put file import, refresh, profile URL/details, editing, and configuration export under a single configuration section. Those writers still use staged validation/commit; an editor is not an escape hatch around the one-profile guarantee.

Adapt tray and hotkey navigation destinations to Home or Settings detail routes. Remove profile-switch menus and dashboard-edit entry points that cannot be reached meaningfully. Preserve platform window/header controls and existing localization conventions; add new strings in all four ARBs and generate output rather than hand-editing generated files.

Alternative considered: delete advanced features. Rejected because the user asked to move them into Settings, not remove their functionality.

## Risks / Trade-offs

- **Atomicity crosses files, SQLite, and Core** → Use immutable generations, a durable journal, one serialized commit, and restart tests at each boundary. Successful replacement can reset connections; failed preparation must not.
- **Mihomo parsing/provider initialization has side effects** → Add a narrowly scoped detached preparation feature to the maintained fork, owned by the FlClash wrapper with isolated identities/resources. Test live state during preparation, rejection, and discard. Carry the fork feature across rebases; do not call the legacy apply path as validation.
- **Runtime activation or restoration can fail independently of storage** → Keep the previous generation recoverable, attempt normal lifecycle recovery, and show the actual failure rather than promise uninterrupted service.
- **Flattened selection can hide source routing semantics** → Simple routing is explicit and confirmed by the user; preserve the original source and advanced settings, with a visible custom-mode indicator.
- **Subscription/provider updates can invalidate selections** → Commit validated catalogs by revision, retain stable identities, and fall back to Auto only after a successful refresh.
- **A platform may establish only a proxy, not TUN** → Preserve the existing fallback behavior and display its actual scope. Real permission and OS integration checks remain platform-specific.
- **Migration archives use disk and contain subscription credentials** → Keep them in app-private storage, exclude them from automatic cleanup, and expose an explicit export/recovery action in Settings. Never silently delete old profiles before backup succeeds.
- **The shell rewrite can break focus, back navigation, or desktop chrome** → Extend the existing Home/focus/window-header suites and test narrow/large-text layouts.

## Migration Plan

1. Add backward-compatible storage metadata and readers for immutable generations; regenerate model/Drift output. During upgrade, read the selected legacy ID and ordered profiles before changing preferences or starting Core.
2. Create and verify a durable recovery archive containing the original profile rows, YAML, provider resources, profile-owned rules/groups, and required scripts/settings. Preserve invalid profiles too, so failed validation is not data loss. If archiving fails, retain the original data and publish only the chosen profile while migration awaits retry.
3. Choose the selected locally usable profile or first usable fallback. If none exists, show import and preserve the archive/source files. Do not require an online refresh or promote a profile cleared intentionally by crash recovery into an automatic connection.
4. Commit the selected snapshot and migration marker together, prune surplus active records only after the backup is verified, and reconcile the compatibility preference before auto-start/refresh. Preserve network, access-control, and advanced override preferences. Use simple routing by default; retain the old advanced selection separately and map a uniquely identified prior manual server to the simple selection when possible, otherwise Auto.
5. Apply the same deterministic selection and staged commit to old multi-profile backups. Restore candidate files into request-private staging rather than copying over active files. Non-profile restored settings/data join the final commit/recovery boundary so a failed profile restore cannot partly reconfigure the running app. Allocate fresh script identities, commit shared rows and a schema-5 `pending_restore` publication record with the profile, then publish script files/settings mirrors and clear that record. Recovery retries publication; a pending publication blocks replacement. Compare a shared-library fingerprint at commit so restoration cannot overwrite concurrent library edits. Settings-only backups retain an existing usable profile, or preserve the empty import state when none exists.
6. For rollback to a pre-redesign build, export the untouched migration archive and restore it with that build. Do not claim the old binary can interpret new storage metadata. Keep original source generations/backups until their retention policy is explicitly addressed outside this change.

## Verification Approach

### Import and replacement performance follow-up

Retain both detached Core preparation passes and all journal/rollback integrity checks: they verify different effective configurations and are not interchangeable with latency probes. Stream file checksums to reduce whole-file allocations. Reuse geographic resources from the previous committed generation using sealed `geo-cache.json` entries with a SHA-256 source-URL identity and original fetch timestamp. Check the resource checksum independently before copying into the new generation. Online freshness uses a positive `geo-update-interval` in hours or 24 hours; offline edits can retain old source-matched verified data. Copies never renew timestamps. Unstamped restored/legacy data remains eligible only offline, with fresh download required on a later online refresh. Restore reads both `geo/<name>` and the legacy root name, but writes only `geo/<name>`.

Bound each HTTP resource transfer to 90 seconds with a child cancellation token linked to the operation, while keeping 15-second connect and 30-second send/receive limits. This is a per-transfer limit, not an overall transaction deadline; final Core activation/rollback is still awaited. Keep four provider workers, stop dequeuing after failure, and await already-started workers before cleanup. Do not silently fall back to stale provider/subscription data after a failed fetch.

Add observational request callbacks for stage progress; no second provider or widget owns the transaction. Provider counts are not an overall percentage. Supersession/cancellation fences callbacks, and callback exceptions cannot affect transaction success. Import-panel cancellation holds controls until cleanup completes; final commit disables cancellation/back dismissal. Settings manual refresh uses the same callback. Record stage durations, including repeated validation periods, in one diagnostic summary with no credential-bearing values. Real-device timings are still needed to quantify speedups.

### Post-build reliability review

Use semantic green/gray feedback plus distinct transition and failure treatments, keeping text and icons available for accessibility. Disable repeated UI transitions while retaining explicit startup cancellation. Keep failed teardown visible without pretending the tunnel is gone.

Node latency is transient snapshot-scoped state, not profile or selection data. Reuse bounded probe scheduling and the Core delay protocol with an optional failure code distinguishing probe deadline, unreachable endpoint, and channel/queue failure. Highlight the fastest measured node without sorting modes or changing routing. Reject late results across generation/Core changes and guard batch submissions.

Release feedback exposed a wire-contract risk: `RunObservation` lives outside the packages protected by the Android Gson keep rules. Encode its snapshot/events explicitly with literal keys and state names rather than reflection. Keep native lifecycle ownership unchanged. Flutter coalesces snapshot requests and bounds them to five seconds; missing/malformed/failed replies produce `state_unavailable`, safe Disconnect and a guarded retry. Never infer STOPPED from transport failure. Accepted native observations clear only this status-check error; stale failures cannot replace newer observations.

Use bright green (`#00C853`) for the connected button and status badge, with black foreground for contrast; retain gray/off and distinct transition/error states. Display latency as bold title-sized text on a contrasting small badge. Current node is separate from persisted selection: a read-only Core query resolves GLOBAL/managed/automatic targets against catalog identities, fenced by Core session/generation/configuration revision before and after the read. Reject mismatched applied selection, cycles and missing nodes. A disposable Home observer refreshes five seconds after completion, clears unavailable results after five seconds without overlapping a slow RPC, and pauses outside foreground Home. Profile/connection/routing changes invalidate old results. Custom routing explicitly avoids a single-node claim; the shown node governs new traffic, while existing sessions may retain their earlier outbound.

Android cleanup must not use the runtime timer as proof there are no resources to release. Preserve failed teardown ownership for retry and surface failures through ServiceState observations. Serialize notification publication with stop so coroutine cancellation cannot race a final foreground update. Keep optimistic MethodChannel acknowledgements and native latest-intent arbitration. Android Always-on is independent system policy; document it rather than promising an app override.

Keep unresolved cleanup failure in the native state machine independently of transient observations. New requests clear presentation errors, so checking only the last observation cannot prevent reuse of a partially stopped service. Reject native starts and background preparation while cleanup requires retry, even with a retained timer or after service loss; only successful owned cleanup clears that condition. Explicit Disconnect remains available. Successful delayed cleanup clears only the resolved `stop_failed` error, preserving unrelated configuration/start failures and current-request checks. A later explicit start can then establish the tunnel normally.

Use behavioral failure injection for the risky boundaries: HTTP errors, invalid adapters/references, empty providers, candidate cleanup, disk/DB failures, crash recovery, stale imports/refreshes/selections, and failed runtime restoration. Extend `test/models/profile_save_test.dart`, the provider/database/backup suites, and `test/common/task_test.dart`; add a focused import-coordinator suite and storage migration fixtures.

Extend protocol and native state tests for preparation handles and Android run-state observation, including `test/core/protocol_contract_test.dart`, `test/core/desktop/`, and `android/tests/app/ServiceStateMachineTest.kt`. Use `test/pages/home_test.dart`, `test/views/add_profile_view_test.dart`, and connection-control widget tests for the new user flow. Verify localized labels, semantics, keyboard focus, duplicate QR detections, and long server lists.

Run code generation, localization generation, repository formatting/lint gates, `flutter pub get`, `flutter analyze --no-fatal-infos`, and `flutter test --reporter expanded` during implementation. For changed wrapper/native files run the existing Go, Android JVM/compile, and relevant plugin checks. Device/platform smoke tests must cover Android permission/revoke/reentry and Windows/macOS/Linux TUN or proxy-only operation plus QR image import; record unavailable hosts explicitly.

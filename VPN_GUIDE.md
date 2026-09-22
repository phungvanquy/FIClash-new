# VPN setup and recovery

## Import, select, connect

Open FlClash and import the HTTP(S) subscription/configuration URL supplied by your provider. You can enter it manually, explicitly paste it from the clipboard, or scan a QR code. Android supports camera scanning and QR images; desktop uses a QR image file. If camera permission is denied, use Paste, manual entry, or an image instead. QR images support PNG/JPEG up to 16 MB, 16 megapixels, and 8192 pixels per side.

“VPN token” means the complete subscription URL, including its embedded token. There is no provider-specific short-code decoder or new raw protocol-token importer. Treat the URL, exported YAML, and backups as credentials; do not publish them.

After import, Home shows Auto, Fallback, and the usable servers from the configuration and its providers. Choose a node and press the central circular button. Selection works before connecting and is remembered. Importing alone does not ask for VPN permission or connect a disconnected VPN.

- **Auto** chooses a responsive server using periodic latency checks.
- **Fallback** uses the first healthy server in source order.
- **A server** pins your selection to that server.

Automatic groups do not silently switch to DIRECT when no eligible server is available. If a successful refresh removes your selected server, selection returns to Auto with a notification. Failed refreshes keep the saved catalog and selection; you can reopen it offline.

## Connection status

The circular button connects or disconnects. While connecting, use the separate Cancel action; repeated transition taps are disabled. Status follows native service/listener observations, not merely Core startup or a command acknowledgement. Green means Connected, gray means Disconnected, orange means Connecting, blue means Disconnecting, and red marks a connection error. Text and icons identify the state too. Connecting can include waiting for platform authorization. Connected means the observed VPN/TUN path is active, not that every website or server is reachable. On desktop, **System proxy only** or **Local proxy only** indicates that TUN is not active; those modes do not capture all device traffic. Failed permission/startup, suspended operation, and failed recovery are shown separately. If disconnect cannot be confirmed, retry Disconnect; the app does not report successful disconnection or turn that failure into a reconnect request.

Fresh installations request VPN/TUN defaults when you explicitly connect. Existing platform preferences are preserved during migration. OS permission prompts and platform-specific TUN requirements still apply.

When reopening on Android, Checking connection means the app is waiting for its native state snapshot; it does not assume that a previously running VPN is off.

Closing the Flutter app pauses subscription and provider-content refresh. If the native VPN remains running, it uses the last committed configuration; health checks, Auto, and Fallback continue. Due content refresh resumes when Flutter returns. Choosing Exit/Disconnect or having the operating system stop the native service is different from merely closing Flutter.

## Test server latency

Choose **Test latency** above the server list. Each individual server shows its measured round-trip probe time in milliseconds; lower is better for this test, not a guarantee of download speed. The fastest successful node is marked without moving the list or selecting it. Auto and Fallback remain automatic modes, not individual measurements.

The button shows Testing while the batch runs and cannot launch another batch. Not tested means there is no measurement for this configuration and test URL. Timed out means the probe exceeded its deadline; Unreachable means the probe could not connect or complete; Test failed means the test infrastructure did not return a usable result. Retry after checking your internet access and, if needed, the test URL in Settings. Testing does not connect a disconnected VPN, change the selected node/mode, or close your active traffic sessions. Auto/Fallback's normal health-based choices can still change as designed. Results are session-only and cleared when the configuration generation or test URL changes.

## Disconnecting on Android

Tap **Disconnect** and wait for Disconnected. The app removes its foreground connection notification and releases the tunnel before reporting successful cleanup. A failed cleanup remains visible and retryable. Closing the app or dismissing it from Recents is not a reliable way to disconnect; a running native VPN is allowed to continue. Reopening reads native state rather than assuming the previous button tap succeeded. Force-stopping/killing the process closes its OS-owned descriptors; it is not the normal disconnect procedure.

If cleanup fails, retry **Disconnect** before connecting again. Native starts remain blocked until cleanup succeeds, even if an old connection timer remains. Successful delayed cleanup clears the resolved disconnect error; it does not automatically reconnect.

Android's **Always-on VPN** is separate from FlClash's auto-connect preference: Android can start the service again. To leave it off, open Android Settings → Network & Internet (or Connections) → VPN → FlClash, then disable Always-on VPN. If **Block connections without VPN** is enabled, internet access can remain blocked after disconnecting. Android's Always-on warning notification is different from FlClash's foreground notification and can remain until Always-on is disabled or the VPN reconnects. Menu wording varies by device. See [Android's VPN lifecycle and Always-on guidance](https://developer.android.com/develop/connectivity/vpn).

If the VPN key remains while FlClash says Disconnected with Always-on disabled, check whether another VPN is active in Android settings. If FlClash still appears connected, disconnect it there and report the Android version, app build, displayed state, and whether the key or app notification remained. Do not include subscription URLs or tokens in logs/screenshots. The key icon is managed by Android; this app cannot remove it independently of the tunnel.

## One profile, safe replacement

Use Replace configuration on Home or in Settings to import a new URL. FlClash downloads and validates the candidate and its required resources before activating and committing it. A successful import replaces the sole profile immediately. Fetch, validation, preparation, or storage failure preserves the previous committed profile and selection. A failed activation restores the previous configuration; if restoration itself fails, use Settings' recovery action instead of assuming the VPN is connected.

Connected replacement keeps the current connection intent, but existing sessions may reconnect when the new configuration activates. Disconnecting while an import is pending wins: finishing the import does not reconnect you. Cancelling or submitting a newer import prevents older work from replacing it.

## Settings and routing

The gear opens Settings. Network/DNS options, rules, scripts, diagnostics, appearance, application preferences, backup, and configuration recovery live there.

By default, the selected server, Auto, or Fallback handles traffic captured by the VPN. Custom routing is opt-in under Settings and can use the imported rules, groups, and advanced routing mode. Home indicates when custom routing is active. Choosing a Home node switches back to simple routing without discarding saved custom rules or group selections.

Configuration URL/source editing and profile-specific override editing use staged validation. Override changes stay in a draft until Save; going back discards that draft. Shared rules and scripts are saved library items, not part of that disposable draft. **Apply saved configuration** in basic/advanced configuration rebuilds the active snapshot using saved configuration preferences and libraries; override Save and configuration refresh also incorporate them. A failed rebuild keeps the previous active snapshot. Runtime controls such as system proxy and listener options still use their normal update flow.

File import and original-source export remain available in Settings. Source export contains the original configuration, not the generated managed Auto/Fallback groups.

## Upgrade, backup, restore

Before consolidating an older multi-profile installation, FlClash creates and verifies an app-private recovery archive of its database, settings, profiles, provider resources, scripts, and cached geodata. Offline migration tries the selected usable profile first, then the first usable profile in saved order. If none is usable, Home returns to import while the archive preserves the old data. If the archive cannot be written, old records are not pruned.

Settings can export the migration archive without deleting the retained copy. Routine cleanup does not delete migration archives. Keep an external copy before uninstalling or deleting app data.

New backups include immutable generations and their offline resources. Restoring an old or new backup stages files privately and selects one usable profile. Compatible/override restore strategies govern shared library data, not profile count. Restoring configuration only keeps application settings; restoring all data applies restored settings with the successful profile commit. Failed candidate restore does not partly replace your working profile or settings.

If a process interruption or preference-write failure leaves publication unfinished, the database record and commit journal allow startup or Settings recovery to finish it. Do not delete the application data while recovery is pending. Neither the archive nor the transaction makes a VPN connection immune to OS termination, filesystem corruption, or hardware failure.

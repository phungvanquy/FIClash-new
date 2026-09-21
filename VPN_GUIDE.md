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

The button starts, stops, or cancels a pending connection. Status follows native service/listener observations, not merely Core startup or a start-command acknowledgement. Connecting can include waiting for platform authorization. Connected means the observed VPN/TUN path is active. On desktop, **System proxy only** or **Local proxy only** indicates that TUN is not active; those modes do not capture all device traffic. Failed permission/startup, suspended operation, and failed recovery are shown separately.

Fresh installations request VPN/TUN defaults when you explicitly connect. Existing platform preferences are preserved during migration. OS permission prompts and platform-specific TUN requirements still apply.

Closing the Flutter app pauses subscription and provider-content refresh. If the native VPN remains running, it uses the last committed configuration; health checks, Auto, and Fallback continue. Due content refresh resumes when Flutter returns. Choosing Exit/Disconnect or having the operating system stop the native service is different from merely closing Flutter.

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

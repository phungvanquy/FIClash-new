import 'dart:convert';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

Profile roundTrip(Profile profile) =>
    Profile.fromJson(jsonDecode(jsonEncode(profile)) as Map<String, dynamic>);

void main() {
  const legacy = Profile(
    id: 7,
    label: 'Subscription',
    url: 'https://example.test/config?token=a%2Bb',
    autoUpdateDuration: Duration(hours: 1),
    selectedMap: {'Regional': 'Server A'},
  );

  test('legacy profiles retain existing data without snapshot metadata', () {
    final json = jsonDecode(jsonEncode(legacy)) as Map<String, dynamic>;
    json.remove('snapshot');

    final profile = Profile.fromJson(json);

    expect(profile, legacy);
    expect(profile.snapshot, const ProfileSnapshot());
    expect(profile.snapshot.generation, isNull);
    expect(profile.snapshot.selection, const VpnSelection.auto());
    expect(roundTrip(profile), profile);
  });

  test(
    'committed snapshots preserve catalog identity and both routing modes',
    () {
      const servers = [
        VpnServer(
          id: 'provider-a/server',
          name: 'Auto',
          target: 'managed-a',
          type: 'vless',
          provider: 'provider-a',
        ),
        VpnServer(
          id: 'provider-b/server',
          name: 'Auto',
          target: 'managed-b',
          type: 'ss',
          provider: 'provider-b',
        ),
      ];
      for (final routing in VpnRoutingMode.values) {
        final profile = legacy.copyWith(
          snapshot: ProfileSnapshot(
            revision: 3,
            generation: '0123456789abcdef0123456789abcdef',
            routing: routing,
            selection: const VpnSelection.server('provider-b/server'),
            advancedMode: Mode.rule,
            servers: servers,
          ),
        );

        final restored = roundTrip(profile);

        expect(restored, profile);
        expect(restored.selectedMap, legacy.selectedMap);
        expect(restored.snapshot.servers[1].target, 'managed-b');
        expect(restored.snapshot.selection, isNot(const VpnSelection.auto()));
        expect(() => restored.snapshot.servers.clear(), throwsUnsupportedError);
      }
    },
  );

  test(
    'automatic selections are distinct from servers with matching names',
    () {
      for (final selection in const [
        VpnSelection.auto(),
        VpnSelection.fallback(),
        VpnSelection.server('Auto'),
        VpnSelection.server('Fallback'),
      ]) {
        final profile = legacy.copyWith(
          snapshot: ProfileSnapshot(selection: selection),
        );
        expect(roundTrip(profile).snapshot.selection, selection);
      }
      expect(
        const VpnSelection.server('Fallback'),
        isNot(const VpnSelection.fallback()),
      );
    },
  );

  test('malformed selection metadata is not silently interpreted as Auto', () {
    expect(
      () => VpnSelection.fromJson({'kind': 'server'}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => VpnSelection.fromJson({'kind': 'unknown'}),
      throwsA(
        isA<CheckedFromJsonException>().having(
          (error) => error.key,
          'key',
          'kind',
        ),
      ),
    );
  });
}

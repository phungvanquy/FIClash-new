import 'package:fl_clash/common/vpn_intake.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const url =
      'https://example.test/sub%2fscription?token=a%2bb+c%3D&sig=%252f&x=1&x=2';

  test('manual, paste, QR and installation wrappers preserve URL bytes', () {
    for (final input in [
      url,
      '  $url\n',
      '\t$url\r\n',
      for (final scheme in ['flclash', 'clash', 'clashmeta'])
        '$scheme://install-config?url=${Uri.encodeComponent(url)}&name=Example',
    ]) {
      final result = VpnUrlIntake.parse(input);
      expect(result, isA<VpnUrlAccepted>());
      expect((result as VpnUrlAccepted).url, url);
    }
  });

  test('plain installation URL tokens keep literal plus signs', () {
    final result = VpnUrlIntake.parse(
      'flclash://install-config?url=https://example.test/sub?token=a+b',
    );
    expect(
      (result as VpnUrlAccepted).url,
      'https://example.test/sub?token=a+b',
    );
  });

  test('intake rejects empty, unsupported, malformed and multiple URLs', () {
    for (final input in [
      '',
      ' ',
      'activation-code',
      'vless://token@example.test',
      'file:///config.yaml',
      'https://',
      'https://example.test/a b',
      'https://example.test/%zz',
      'https://example.test:70000/config',
      'https://example.test/a\nhttps://example.test/b',
      'flclash://install-config',
      'flclash://open-profile?url=$url',
      'flclash://install-config?url=https://one.test&url=https://two.test',
      'flclash://install-config?url=https://example.test?token=a&ambiguous=b',
    ]) {
      expect(VpnUrlIntake.parse(input), isA<VpnUrlRejected>(), reason: input);
    }
  });

  test('encoded whitespace and nested URL query values remain valid', () {
    const value = 'https://example.test/a%20b?next=https://example.test/c';
    expect((VpnUrlIntake.parse(value) as VpnUrlAccepted).url, value);
  });

  test(
    'malformed optional subscription metadata cannot throw or erase valid fields',
    () {
      expect(SubscriptionInfo.formHString(''), const SubscriptionInfo());
      expect(
        SubscriptionInfo.formHString(
          'broken; upload=12; download=-3; total=nope; expire=4; upload=bad; ignored=x=y;',
        ),
        const SubscriptionInfo(upload: 12, expire: 4),
      );
    },
  );
}

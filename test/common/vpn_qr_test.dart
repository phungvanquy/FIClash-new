import 'dart:typed_data';
import 'dart:ui' show Locale;

import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

final class _Picked extends PlatformFile {
  _Picked(this.bytes, {this.reportedLength});

  final Uint8List bytes;
  final int? reportedLength;
  int reads = 0;

  @override
  Future<int> length() async => reportedLength ?? bytes.length;

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    return bytes;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Uint8List qrImage(String text, {bool jpeg = false, bool inverted = false}) {
  final matrix = Encoder.encode(text, ErrorCorrectionLevel.h).matrix!;
  const scale = 6;
  const margin = 4;
  final size = (matrix.width + margin * 2) * scale;
  final image = img.Image(width: size, height: size);
  img.fill(
    image,
    color: img.ColorRgb8(
      inverted ? 0 : 255,
      inverted ? 0 : 255,
      inverted ? 0 : 255,
    ),
  );
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) != 1) continue;
      img.fillRect(
        image,
        x1: (x + margin) * scale,
        y1: (y + margin) * scale,
        x2: (x + margin + 1) * scale - 1,
        y2: (y + margin + 1) * scale - 1,
        color: img.ColorRgb8(
          inverted ? 255 : 0,
          inverted ? 255 : 0,
          inverted ? 255 : 0,
        ),
      );
    }
  }
  return jpeg ? img.encodeJpg(image, quality: 92) : img.encodePng(image);
}

void main() {
  setUpAll(() async => AppLocalizations.load(const Locale('en')));

  for (final jpeg in [false, true]) {
    test('decodes ${jpeg ? 'JPEG' : 'PNG'} without a native scanner', () {
      const url = 'https://example.test/config?token=a%2Bb%2Fc';
      expect(decodeVpnQrImage(qrImage(url, jpeg: jpeg)), url);
    });
    test(
      'desktop adapter reads a valid ${jpeg ? 'JPEG' : 'PNG'} image',
      () async {
        const url = 'https://example.test/config?token=unchanged';
        final file = _Picked(qrImage(url, jpeg: jpeg));
        final picker = Picker(desktop: true, pickQrFile: () async => file);
        expect(await picker.pickerConfigQRCode(), url);
        expect(file.reads, 1);
      },
    );
    test('rejects truncated ${jpeg ? 'JPEG' : 'PNG'} and no-code images', () {
      final valid = qrImage('https://example.test/config', jpeg: jpeg);
      expect(
        () => decodeVpnQrImage(Uint8List.sublistView(valid, 0, jpeg ? 2 : 8)),
        throwsA(isA<VpnQrException>()),
      );
      final blank = img.Image(width: 200, height: 200);
      expect(
        () => decodeVpnQrImage(
          jpeg ? img.encodeJpg(blank) : img.encodePng(blank),
        ),
        throwsA(
          isA<VpnQrException>().having(
            (error) => error.reason,
            'reason',
            VpnQrError.noCode,
          ),
        ),
      );
    });
  }

  test('handles inverted images and encoded installation links', () {
    const url = 'https://example.test/config?token=a%2Fb';
    final wrapper = 'clash://install-config?url=${Uri.encodeComponent(url)}';
    expect(decodeVpnQrImage(qrImage(wrapper, inverted: true)), url);
  });

  test('rejects non-URL and multiple-URL QR payloads', () {
    for (final value in ['plain text', 'https://a.test\nhttps://b.test']) {
      expect(
        () => decodeVpnQrImage(qrImage(value)),
        throwsA(
          isA<VpnQrException>().having(
            (error) => error.reason,
            'reason',
            VpnQrError.invalidUrl,
          ),
        ),
      );
    }
  });

  test('rejects invalid and no-code images', () {
    expect(
      () => decodeVpnQrImage(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<VpnQrException>()),
    );
    final blank = img.Image(width: 200, height: 200);
    expect(
      () => decodeVpnQrImage(img.encodePng(blank)),
      throwsA(
        isA<VpnQrException>().having(
          (error) => error.reason,
          'reason',
          VpnQrError.noCode,
        ),
      ),
    );
  });

  test('checks byte and dimension limits before pixel decoding', () {
    expect(
      () => decodeVpnQrImage(Uint8List(maxVpnQrBytes + 1)),
      throwsA(
        isA<VpnQrException>().having(
          (error) => error.reason,
          'reason',
          VpnQrError.tooLarge,
        ),
      ),
    );
    final wide = img.Image(width: 8193, height: 1);
    expect(
      () => decodeVpnQrImage(img.encodePng(wide)),
      throwsA(
        isA<VpnQrException>().having(
          (error) => error.reason,
          'reason',
          VpnQrError.tooLarge,
        ),
      ),
    );
  });

  test(
    'desktop picker cancellation returns without decoding or importing',
    () async {
      final picker = Picker(desktop: true, pickQrFile: () async => null);
      expect(await picker.pickerConfigQRCode(), isNull);
    },
  );

  test('oversized picker metadata is rejected before reading bytes', () async {
    final file = _Picked(Uint8List(0), reportedLength: maxVpnQrBytes + 1);
    final picker = Picker(desktop: true, pickQrFile: () async => file);
    await expectLater(
      picker.pickerConfigQRCode(),
      throwsA(isA<MessageException>()),
    );
    expect(file.reads, 0);
  });
}

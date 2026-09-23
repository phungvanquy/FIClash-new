import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

String _androidAttribute(String source, String element, String attribute) {
  final elementTag = RegExp('<$element\\b[^>]*>').firstMatch(source)!.group(0)!;
  return RegExp(
    'android:$attribute="([^"]+)"',
  ).firstMatch(elementTag)!.group(1)!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TV launcher icons meet density-specific minimum sizes', () async {
    const expectedSizes = {
      'mdpi': 80,
      'hdpi': 120,
      'xhdpi': 160,
      'xxhdpi': 240,
      'xxxhdpi': 320,
    };

    for (final MapEntry(key: density, value: size) in expectedSizes.entries) {
      final file = File(
        'android/app/src/main/res/'
        'mipmap-television-$density/ic_launcher.png',
      );
      expect(file.existsSync(), isTrue, reason: 'missing ${file.path}');

      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final frame = await codec.getNextFrame();
      expect(
        (frame.image.width, frame.image.height),
        (size, size),
        reason: file.path,
      );
      frame.image.dispose();
      codec.dispose();
    }
  });

  test('TV adaptive launcher icon stays centered in the safe zone', () {
    final adaptiveIcon = File(
      'android/app/src/main/res/'
      'mipmap-television-anydpi-v26/ic_launcher.xml',
    ).readAsStringSync();
    expect(
      _androidAttribute(adaptiveIcon, 'foreground', 'drawable'),
      '@drawable/ic_launcher_foreground_tv',
    );
    expect(
      _androidAttribute(adaptiveIcon, 'background', 'drawable'),
      '@color/ic_launcher_background',
    );

    final drawable = File(
      'android/app/src/main/res/drawable/'
      'ic_launcher_foreground_tv.xml',
    ).readAsStringSync();
    expect(
      _androidAttribute(drawable, 'bitmap', 'src'),
      '@drawable/tunnio_launcher',
    );
    expect(_androidAttribute(drawable, 'bitmap', 'gravity'), 'fill');
    final image = img.decodePng(
      File(
        'android/app/src/main/res/drawable-nodpi/tunnio_launcher.png',
      ).readAsBytesSync(),
    )!;
    expect([image.width, image.height], [432, 432]);
    var left = image.width;
    var top = image.height;
    var right = 0;
    var bottom = 0;
    for (final pixel in image) {
      if (pixel.a < 10) continue;
      if (pixel.x < left) left = pixel.x;
      if (pixel.x > right) right = pixel.x;
      if (pixel.y < top) top = pixel.y;
      if (pixel.y > bottom) bottom = pixel.y;
      final x = pixel.x - 216;
      final y = pixel.y - 216;
      expect(x * x + y * y, lessThan(132 * 132));
    }
    expect(right, greaterThan(left));
    expect(bottom, greaterThan(top));
    expect((left + right) / 2, closeTo(216, 8));
    expect((top + bottom) / 2, closeTo(216, 8));
  });
}

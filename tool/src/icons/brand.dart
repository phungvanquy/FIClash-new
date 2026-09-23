import 'dart:io';

import 'package:image/image.dart' as img;

import 'ico.dart';

const _androidApp = 'android/app/src/main/res';
const _androidService = 'android/service/src/main/res';
const _densities = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

img.Image brandIcon(
  img.Image logo,
  int size, {
  double fraction = 1,
  img.Color? background,
  img.Color? tint,
  bool round = false,
}) {
  final result = img.Image(width: size, height: size, numChannels: 4);
  if (background != null) {
    if (round) {
      img.fillCircle(
        result,
        x: size ~/ 2,
        y: size ~/ 2,
        radius: size ~/ 2 - 1,
        color: background,
      );
    } else {
      img.fill(result, color: background);
    }
  }
  final scaled = img.copyResize(
    logo,
    width: (size * fraction).round(),
    interpolation: img.Interpolation.average,
  );
  if (tint != null) {
    for (final pixel in scaled) {
      final alpha =
          pixel.a * ((1 - pixel.luminanceNormalized) * 1.6).clamp(0, 1);
      pixel
        ..r = tint.r
        ..g = tint.g
        ..b = tint.b
        ..a = alpha;
    }
  }
  return img.compositeImage(
    result,
    scaled,
    dstX: (size - scaled.width) ~/ 2,
    dstY: (size - scaled.height) ~/ 2,
  );
}

Future<void> generateBrandIcons(img.Image logo, Directory root) async {
  Future<void> writePng(String path, img.Image image) async {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(img.encodePng(image));
  }

  Future<void> writeIco(String path, List<int> sizes, img.Color? tint) async {
    final file = File('${root.path}/$path');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(
      buildIco([
        for (final size in sizes)
          IcoEntry(
            size: size,
            png: img.encodePng(brandIcon(logo, size, tint: tint)),
          ),
      ]),
    );
  }

  final background = img.ColorRgb8(241, 245, 249);
  await writeIco('windows/runner/resources/app_icon.ico', icoSizes, null);
  await writeIco('assets/images/icon.ico', icoSizes, null);
  for (final size in [16, 32, 64, 128, 256, 512, 1024]) {
    await writePng(
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png',
      brandIcon(logo, size),
    );
  }
  for (final entry in _densities.entries) {
    final density = entry.key;
    for (final variant in ['', '_round']) {
      final base = '$_androidApp/mipmap-$density/ic_launcher$variant';
      await writePng(
        '$base.png',
        brandIcon(
          logo,
          entry.value,
          fraction: .78,
          background: background,
          round: variant.isNotEmpty,
        ),
      );
      final old = File('${root.path}/$base.webp');
      if (await old.exists()) await old.delete();
    }
    final tvBase = '$_androidApp/mipmap-television-$density/ic_launcher';
    await writePng(
      '$tvBase.png',
      brandIcon(
        logo,
        (entry.value * 5 / 3).round(),
        fraction: .78,
        background: background,
      ),
    );
    final old = File('${root.path}/$tvBase.webp');
    if (await old.exists()) await old.delete();
  }
  await writePng(
    '$_androidApp/drawable-nodpi/tunnio_launcher.png',
    brandIcon(logo, 432, fraction: .54),
  );
  await writePng(
    '$_androidApp/drawable-nodpi/tunnio_monochrome.png',
    brandIcon(logo, 432, fraction: .54, tint: img.ColorRgb8(255, 255, 255)),
  );
  await writePng(
    '$_androidService/drawable-nodpi/tunnio_notification.png',
    brandIcon(logo, 96, fraction: .9, tint: img.ColorRgb8(255, 255, 255)),
  );

  final banner = img.Image(width: 320, height: 180, numChannels: 4);
  img.fill(banner, color: background);
  img.compositeImage(banner, brandIcon(logo, 144), dstX: 10, dstY: 18);
  img.drawString(
    banner,
    'Tunnio',
    font: img.arial24,
    x: 178,
    y: 80,
    color: img.ColorRgb8(7, 24, 42),
  );
  await writePng('$_androidApp/mipmap-xhdpi/ic_banner.png', banner);

  final colors = [
    img.ColorRgb8(107, 114, 128),
    img.ColorRgb8(2, 132, 199),
    img.ColorRgb8(0, 150, 90),
  ];
  for (var index = 0; index < colors.length; index++) {
    final name = 'status_${index + 1}';
    for (final scale in [1, 2, 3, 4]) {
      final directory = scale == 1 ? '' : '$scale.0x/';
      await writePng(
        'assets/images/tray/unix/$directory$name.png',
        brandIcon(logo, 18 * scale, tint: colors[index]),
      );
    }
    await writeIco(
      'assets/images/tray/windows/$name.ico',
      trayIcoSizes,
      colors[index],
    );
  }
}

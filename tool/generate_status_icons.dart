import 'dart:io';

import 'package:image/image.dart' as img;

import 'src/icons/brand.dart';

Future<void> main() async {
  final logo = img.decodePng(
    await File('assets/images/icon.png').readAsBytes(),
  );
  if (logo == null || logo.width != logo.height || logo.width < 1024) {
    throw StateError(
      'The app logo must be a square PNG of at least 1024 pixels.',
    );
  }
  await generateBrandIcons(logo, Directory.current);
  stdout.writeln(
    'Generated Tunnio launcher, desktop, notification and tray icons.',
  );
}

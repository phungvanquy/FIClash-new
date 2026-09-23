import 'dart:io';
import 'dart:typed_data';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/dav_client.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:yaml/yaml.dart';

import '../../tool/src/icons/brand.dart';
import '../../tool/src/icons/ico.dart';

String read(String path) => File(path).readAsStringSync();

img.Image readPng(String path) => img.decodePng(File(path).readAsBytesSync())!;

void main() {
  test('display branding does not change storage and service identities', () {
    expect(appName, 'Tunnio');
    expect(legacyAppName, 'FlClash');
    expect(packageName, 'com.follow.clash');
    expect(const Tun().device, 'FlClash');
    expect(Tun.fromJson({}).device, 'FlClash');
    expect(
      DAVClient(const DAVProps(uri: 'https://example.test', user: '')).root,
      '/FlClash',
    );
    expect(appHelperService, 'FlClashHelperService');
    expect(
      PackageInfo(
        appName: 'Tunnio',
        packageName: packageName,
        version: '1.0.0',
        buildNumber: '1',
      ).ua,
      startsWith('FlClash/v1.0.0 clash-verge '),
    );
    expect(read('lib/common/launch.dart'), contains('appName: legacyAppName'));
    expect(
      read('windows/runner/Runner.rc'),
      contains('"ProductName", "clash"'),
    );
    final installer = loadYaml(read('windows/packaging/exe/make_config.yaml'));
    expect(installer['display_name'], 'Tunnio');
    expect(installer['app_id'], '728B3532-C74B-4870-9068-BE70FE12A3E6');
    expect(installer['executable_name'], 'FlClash.exe');
    expect(
      read('macos/Runner/Configs/AppInfo.xcconfig'),
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.follow.clash'),
    );
  });

  test('platform launcher and window labels use Tunnio', () {
    expect(
      read('android/common/src/main/res/values/strings.xml'),
      contains('name="app_name">Tunnio<'),
    );
    expect(
      read('android/app/src/debug/AndroidManifest.xml'),
      contains('Tunnio Debug'),
    );
    expect(
      read('windows/runner/main.cpp'),
      contains('window.Create(L"Tunnio"'),
    );
    expect(
      read('linux/runner/my_application.cc'),
      contains('gtk_window_set_title(window, "Tunnio")'),
    );
    expect(
      read('macos/Runner/Configs/AppInfo.xcconfig'),
      contains('PRODUCT_NAME = Tunnio'),
    );
    for (final format in ['deb', 'rpm', 'appimage']) {
      expect(
        loadYaml(
          read('linux/packaging/$format/make_config.yaml'),
        )['display_name'],
        'Tunnio',
      );
    }
  });

  test(
    'canonical logo is transparent and generated Android layers stay inside safe area',
    () {
      final source = readPng('assets/images/icon.png');
      expect([source.width, source.height], [1024, 1024]);
      expect(source.getPixel(0, 0).a, 0);
      final foreground = readPng(
        'android/app/src/main/res/drawable-nodpi/tunnio_launcher.png',
      );
      expect([foreground.width, foreground.height], [432, 432]);
      for (final pixel in foreground) {
        if (pixel.a < 10) continue;
        final x = pixel.x - 216;
        final y = pixel.y - 216;
        expect(x * x + y * y, lessThan(132 * 132));
      }
      for (final entry in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries) {
        for (final suffix in ['', '_round']) {
          final base =
              'android/app/src/main/res/mipmap-${entry.key}/ic_launcher$suffix';
          final image = readPng('$base.png');
          expect([image.width, image.height], [entry.value, entry.value]);
          expect(File('$base.webp').existsSync(), isFalse);
        }
      }
    },
  );

  test(
    'monochrome rendering retains line details rather than a solid silhouette',
    () {
      final source = img.Image(width: 2, height: 2, numChannels: 4);
      source.setPixelRgba(0, 0, 0, 0, 0, 255);
      source.setPixelRgba(1, 0, 255, 255, 255, 255);
      final icon = brandIcon(source, 2, tint: img.ColorRgb8(0, 200, 83));
      expect(icon.getPixel(0, 0).a, 255);
      expect(icon.getPixel(0, 0).g, 200);
      expect(icon.getPixel(1, 0).a, 0);
      expect(icon.getPixel(1, 1).a, 0);
      expect(source.getPixel(0, 0).g, 0);
    },
  );

  test(
    'Windows ICO contains all shell sizes and macOS has each declared size',
    () {
      final bytes = File(
        'windows/runner/resources/app_icon.ico',
      ).readAsBytesSync();
      final data = ByteData.sublistView(bytes);
      expect(data.getUint16(4, Endian.little), icoSizes.length);
      for (var i = 0; i < icoSizes.length; i++) {
        final dimension = bytes[6 + i * 16];
        expect(dimension == 0 ? 256 : dimension, icoSizes[i]);
      }
      for (final size in [16, 32, 64, 128, 256, 512, 1024]) {
        final icon = readPng(
          'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png',
        );
        expect([icon.width, icon.height], [size, size]);
      }
    },
  );

  test(
    'tray variants keep density sizes, transparency and distinct states',
    () {
      for (final scale in [1, 2, 3, 4]) {
        final directory = scale == 1 ? '' : '$scale.0x/';
        final bytes = <List<int>>[];
        for (final state in [1, 2, 3]) {
          final path = 'assets/images/tray/unix/${directory}status_$state.png';
          final icon = readPng(path);
          expect([icon.width, icon.height], [18 * scale, 18 * scale]);
          expect(icon.getPixel(0, 0).a, 0);
          bytes.add(File(path).readAsBytesSync());
        }
        expect(bytes[0], isNot(bytes[1]));
        expect(bytes[1], isNot(bytes[2]));
      }
    },
  );
}

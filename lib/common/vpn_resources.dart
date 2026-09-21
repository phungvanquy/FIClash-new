import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/models/models.dart';
import 'package:path/path.dart' as p;

import 'constant.dart';
import 'profile_store.dart';
import 'vpn_staging.dart';

class VpnProfileResources {
  const VpnProfileResources(this.store);

  final ProfileGenerationStore store;

  Future<List<int>> provider(
    Profile profile,
    String section,
    String name,
    Map<String, dynamic> definition,
  ) async {
    final directory = switch (section) {
      'proxy-providers' => proxiesProviderDirectoryName,
      'rule-providers' => rulesProviderDirectoryName,
      _ => throw const FormatException('Unknown provider resource type'),
    };
    final generation = profile.snapshot.generation;
    final List<File> candidates;
    if (generation != null) {
      final key = sha256.convert(utf8.encode(name)).toString();
      candidates = [store.resource(generation, 'providers/$section/$key')];
    } else {
      final url = definition['url'];
      final keys = url is String && url.isNotEmpty
          ? ['$name@$url', url]
          : ['$section/$name'];
      candidates = [
        for (final key in keys)
          File(
            p.join(
              store.home.path,
              'profiles',
              providersDirectoryName,
              '${profile.id}',
              directory,
              md5.convert(utf8.encode(key)).toString(),
            ),
          ),
      ];
    }
    for (final file in candidates) {
      final kind = await FileSystemEntity.type(file.path, followLinks: false);
      if (kind == FileSystemEntityType.notFound) continue;
      if (kind != FileSystemEntityType.file) {
        throw const FileSystemException(
          'Provider resource is not a regular file',
        );
      }
      var parent = file.parent;
      while (parent.path != store.home.path) {
        if (!p.isWithin(store.home.path, parent.path) ||
            await FileSystemEntity.type(parent.path, followLinks: false) !=
                FileSystemEntityType.directory) {
          throw const FileSystemException(
            'Provider resource escapes private storage',
          );
        }
        parent = parent.parent;
      }
      return file.readAsBytes();
    }
    throw const VpnLocalResourceUnavailable();
  }
}

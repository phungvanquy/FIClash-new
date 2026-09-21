import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'constant.dart';

class VpnArchiveStore {
  const VpnArchiveStore(this.home);

  final Directory home;

  Directory get recovery => Directory(p.join(home.path, 'recovery'));

  Future<File> create({
    required Map<String, dynamic> settings,
    required Future<void> Function(String path) snapshotDatabase,
  }) async {
    await recovery.create(recursive: true);
    if (await FileSystemEntity.type(recovery.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FileSystemException(
        'Recovery directory is not private storage',
      );
    }
    final staging = await recovery.createTemp('.archive-');
    try {
      final content = await Directory(p.join(staging.path, 'content')).create();
      final database = File(p.join(content.path, backupDatabaseName));
      await snapshotDatabase(database.path);
      await _requireRegularFile(database);
      await File(
        p.join(content.path, configJsonName),
      ).writeAsString(jsonEncode(settings), flush: true);
      for (final name in ['profiles', 'scripts']) {
        final directory = Directory(p.join(home.path, name));
        final kind = await FileSystemEntity.type(
          directory.path,
          followLinks: false,
        );
        if (kind == FileSystemEntityType.notFound) continue;
        if (kind != FileSystemEntityType.directory) {
          throw const FileSystemException('Recovery source contains a link');
        }
        await for (final entity in directory.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is Directory) continue;
          if (entity is! File) {
            throw const FileSystemException('Recovery source contains a link');
          }
          await _copyStable(entity, content);
        }
      }
      for (final name in [
        'GeoSite.dat',
        'GeoIP.dat',
        'Country.mmdb',
        'ASN.mmdb',
      ]) {
        final file = File(p.join(home.path, name));
        if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.notFound) {
          await _copyStable(file, content);
        }
      }
      final files = <String, String>{};
      final paths = <File>[];
      await for (final entity in content.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final name = _relative(entity, content);
        files[name] = await _digest(entity);
        paths.add(entity);
      }
      final manifest = File(p.join(content.path, 'snapshot-manifest.json'));
      await manifest.writeAsString(
        jsonEncode({'version': 1, 'files': files}),
        flush: true,
      );
      final archive = File(p.join(staging.path, 'archive.zip'));
      final encoder = ZipFileEncoder()..create(archive.path);
      try {
        for (final file in [...paths, manifest]) {
          await encoder.addFile(file, _relative(file, content));
        }
      } finally {
        await encoder.close();
      }
      final handle = await archive.open(mode: FileMode.append);
      try {
        await handle.flush();
      } finally {
        await handle.close();
      }
      await verify(archive);
      final published = await archive.rename(
        p.join(recovery.path, '${p.basename(staging.path).substring(1)}.zip'),
      );
      return published;
    } finally {
      await staging.delete(recursive: true);
    }
  }

  Future<Map<String, String>> verify(File file) async {
    await _requireRegularFile(file);
    final input = InputFileStream(file.path);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      final entries = <String, ArchiveFile>{};
      for (final entry in archive.files) {
        if (!entry.isFile ||
            entry.isSymbolicLink ||
            !_safeName(entry.name) ||
            entries.containsKey(entry.name)) {
          throw const FormatException('Invalid recovery archive entry');
        }
        entries[entry.name] = entry;
      }
      final manifest = entries.remove('snapshot-manifest.json');
      if (manifest == null) {
        throw const FormatException('Missing recovery manifest');
      }
      final decoded =
          jsonDecode(utf8.decode(manifest.content)) as Map<String, dynamic>;
      if (decoded['version'] != 1) {
        throw const FormatException('Unsupported recovery manifest');
      }
      final files = Map<String, String>.from(decoded['files'] as Map);
      if (!files.containsKey(backupDatabaseName) ||
          !files.containsKey(configJsonName) ||
          files.length != entries.length) {
        throw const FormatException('Incomplete recovery archive');
      }
      for (final entry in files.entries) {
        final resource = entries[entry.key];
        if (resource == null ||
            sha256.convert(resource.content).toString() != entry.value) {
          throw const FormatException('Recovery archive checksum mismatch');
        }
        resource.clear();
      }
      return Map.unmodifiable(files);
    } finally {
      await input.close();
    }
  }

  Future<void> _copyStable(File source, Directory destination) async {
    await _requireRegularFile(source);
    final target = File(p.join(destination.path, _relative(source, home)));
    await target.parent.create(recursive: true);
    final before = await _digest(source);
    await source.copy(target.path);
    final output = await target.open(mode: FileMode.append);
    try {
      await output.flush();
    } finally {
      await output.close();
    }
    if (before != await _digest(target) || before != await _digest(source)) {
      throw const FileSystemException(
        'Recovery source changed while archiving',
      );
    }
  }

  String _relative(File file, Directory root) {
    final relative = p
        .relative(file.path, from: root.path)
        .split(p.separator)
        .join('/');
    if (!_safeName(relative)) {
      throw const FileSystemException('Recovery path escapes source');
    }
    return relative;
  }

  bool _safeName(String name) =>
      name.isNotEmpty &&
      !name.contains(r'\') &&
      !name.contains(':') &&
      !name
          .split('/')
          .any((part) => part.isEmpty || part == '.' || part == '..');

  Future<void> _requireRegularFile(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FileSystemException(
        'Recovery resource is not a regular file',
      );
    }
  }

  Future<String> _digest(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
}

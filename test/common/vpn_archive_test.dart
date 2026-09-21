import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/native.dart';
import 'package:fl_clash/common/vpn_archive.dart';
import 'package:fl_clash/database/database.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory home;
  late Database database;
  late VpnArchiveStore archives;
  const profile = Profile(
    id: 1,
    label: 'Saved',
    autoUpdateDuration: Duration(hours: 1),
  );
  const settings = {'version': 1, 'currentProfileId': 1};

  setUp(() async {
    home = await Directory.systemTemp.createTemp('vpn-archive-test-');
    database = Database(NativeDatabase(File(p.join(home.path, 'live.sqlite'))));
    archives = VpnArchiveStore(home);
    await database.customStatement('PRAGMA journal_mode = WAL');
    await database.profiles.put(profile.toCompanion(0));
  });

  tearDown(() async {
    await database.close();
    await home.delete(recursive: true);
  });

  Future<File> write(String name, String content) async {
    final file = File(p.join(home.path, name));
    await file.parent.create(recursive: true);
    return file.writeAsString(content, flush: true);
  }

  Future<File> create() => archives.create(
    settings: settings,
    snapshotDatabase: (path) =>
        database.customStatement('VACUUM INTO ?', [path]),
  );

  test(
    'verified archive preserves WAL rows and all offline resources',
    () async {
      await write('profiles/1.yaml', '# token remains private\nproxies: []');
      await write('profiles/providers/1/proxies/provider', 'provider payload');
      await write(
        'profiles/generations/old/effective.yaml',
        'retained snapshot',
      );
      await write('scripts/9.js', 'function main(c) { return c; }');
      await write('GeoSite.dat', 'cached geodata');
      final file = await create();
      final files = await archives.verify(file);
      expect(
        files.keys,
        containsAll([
          'database.sqlite',
          'config.json',
          'profiles/1.yaml',
          'profiles/providers/1/proxies/provider',
          'profiles/generations/old/effective.yaml',
          'scripts/9.js',
          'GeoSite.dat',
        ]),
      );
      final zip = ZipDecoder().decodeBytes(
        await file.readAsBytes(),
        verify: true,
      );
      expect(
        jsonDecode(utf8.decode(zip.findFile('config.json')!.content)),
        settings,
      );
      final exportedDb = File(p.join(home.path, 'exported.sqlite'));
      await exportedDb.writeAsBytes(
        zip.findFile('database.sqlite')!.content,
        flush: true,
      );
      final restored = Database(NativeDatabase(exportedDb));
      try {
        expect(
          (await restored.profilesDao.query().get()).single.label,
          'Saved',
        );
      } finally {
        await restored.close();
      }
      expect(
        (await archives.recovery.list().toList()).map((entry) => entry.path),
        [file.path],
      );
      expect(
        await File(p.join(home.path, 'profiles/1.yaml')).readAsString(),
        '# token remains private\nproxies: []',
      );
    },
  );

  test(
    'archive failure preserves live rows and removes only its scratch directory',
    () async {
      final original = await write('profiles/1.yaml', 'keep');
      await expectLater(
        archives.create(
          settings: settings,
          snapshotDatabase: (_) async {
            throw const FileSystemException('disk full');
          },
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await original.readAsString(), 'keep');
      expect(await database.profilesDao.query().get(), hasLength(1));
      expect(await archives.recovery.list().toList(), isEmpty);
    },
  );

  test(
    'missing profile content remains recoverable as a database row',
    () async {
      final file = await create();
      final files = await archives.verify(file);
      expect(files.keys, contains('database.sqlite'));
      expect(files.keys, isNot(contains('profiles/1.yaml')));
      expect(await database.profilesDao.query().get(), hasLength(1));
    },
  );

  test(
    'symlink resources fail preservation without reading their targets',
    () async {
      final outside = await Directory.systemTemp.createTemp(
        'vpn-archive-outside-',
      );
      addTearDown(() => outside.delete(recursive: true));
      final secret = File(p.join(outside.path, 'secret'));
      await secret.writeAsString('outside');
      await Directory(p.join(home.path, 'profiles')).create();
      await Link(p.join(home.path, 'profiles', '1.yaml')).create(secret.path);
      await expectLater(create(), throwsA(isA<FileSystemException>()));
      expect(await archives.recovery.list().toList(), isEmpty);
      expect(await secret.readAsString(), 'outside');
    },
  );

  test('tampered archive content cannot satisfy the saved manifest', () async {
    final file = await create();
    final decoded = ZipDecoder().decodeBytes(await file.readAsBytes());
    final tampered = Archive();
    for (final entry in decoded.files) {
      tampered.addFile(
        ArchiveFile(
          entry.name,
          entry.content.length,
          entry.name == 'config.json' ? utf8.encode('{}') : entry.content,
        ),
      );
    }
    await file.writeAsBytes(ZipEncoder().encode(tampered), flush: true);
    await expectLater(archives.verify(file), throwsFormatException);
  });
}

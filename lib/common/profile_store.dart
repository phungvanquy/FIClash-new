import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/models/models.dart';
import 'package:path/path.dart' as p;

enum ProfileStoreCheckpoint {
  resourceFlushed,
  journalFlushed,
  journalPublished,
  runtimeFlushed,
  runtimePublished,
  journalRemoved,
}

enum ProfileRecoveryKind { rollback, finalize }

class ProfileCommitJournal {
  const ProfileCommitJournal({
    required this.previous,
    required this.candidate,
    required this.previousRevision,
    this.previousRuntime,
  });

  final Profile? previous;
  final Profile candidate;
  final int previousRevision;
  final List<int>? previousRuntime;

  Map<String, Object?> toJson() => {
    'version': 1,
    'previous': previous?.toJson(),
    'candidate': candidate.toJson(),
    'previousRevision': previousRevision,
    if (previousRuntime != null)
      'previousRuntime': base64Encode(previousRuntime!),
  };

  factory ProfileCommitJournal.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Unsupported profile journal version');
    }
    final journal = ProfileCommitJournal(
      previous: json['previous'] == null
          ? null
          : Profile.fromJson(json['previous'] as Map<String, dynamic>),
      candidate: Profile.fromJson(json['candidate'] as Map<String, dynamic>),
      previousRevision: json['previousRevision'] as int,
      previousRuntime: json['previousRuntime'] == null
          ? null
          : base64Decode(json['previousRuntime'] as String),
    );
    if (journal.previousRevision < 0 ||
        journal.candidate.snapshot.revision != journal.previousRevision + 1 ||
        (journal.previous != null &&
            journal.previous!.snapshot.revision != journal.previousRevision) ||
        !ProfileGenerationStore.isGeneration(
          journal.candidate.snapshot.generation,
        )) {
      throw const FormatException('Inconsistent profile journal');
    }
    return journal;
  }
}

class ProfileRecovery {
  const ProfileRecovery(this.kind, this.journal);

  final ProfileRecoveryKind kind;
  final ProfileCommitJournal journal;

  Profile? get profile => switch (kind) {
    ProfileRecoveryKind.rollback => journal.previous,
    ProfileRecoveryKind.finalize => journal.candidate,
  };
}

class ProfileGenerationStore {
  ProfileGenerationStore(this.home, {this.checkpoint});

  final Directory home;
  final Future<void> Function(ProfileStoreCheckpoint)? checkpoint;
  final _random = Random.secure();
  final Set<String> _allocated = {};

  static final _generationPattern = RegExp(r'^[a-f0-9]{32}$');

  static bool isGeneration(String? value) =>
      value != null && _generationPattern.hasMatch(value);

  Directory get generations =>
      Directory(p.join(home.path, 'profiles', 'generations'));

  File get _journal => File(p.join(home.path, 'profile-commit.json'));

  String _randomId() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Directory directory(String generation) {
    if (!isGeneration(generation)) throw ArgumentError('Invalid generation');
    return Directory(p.join(generations.path, generation));
  }

  Future<String> allocate() async {
    await _ensureDirectory(generations);
    while (true) {
      final generation = _randomId();
      final target = directory(generation);
      if (await FileSystemEntity.type(target.path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        continue;
      }
      await target.create();
      _allocated.add(generation);
      return generation;
    }
  }

  File resource(String generation, String relative) {
    final segments = relative.split('/');
    if (relative.isEmpty ||
        relative.contains(r'\') ||
        relative.contains(':') ||
        p.isAbsolute(relative) ||
        segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
      throw ArgumentError('Invalid generation resource');
    }
    return File(p.joinAll([directory(generation).path, ...segments]));
  }

  Future<void> write(
    String generation,
    String relative,
    List<int> bytes,
  ) async {
    if (!_allocated.contains(generation)) {
      throw StateError('Generation is not owned by this request');
    }
    if (await resource(generation, 'manifest.json').exists()) {
      throw StateError('Generation is sealed');
    }
    final file = resource(generation, relative);
    await _ensureDirectory(file.parent);
    await file.create(exclusive: true);
    await file.writeAsBytes(bytes, flush: true);
    await checkpoint?.call(ProfileStoreCheckpoint.resourceFlushed);
  }

  Future<void> seal(Profile profile) async {
    final generation = profile.snapshot.generation;
    if (!isGeneration(generation) || profile.snapshot.revision <= 0) {
      throw ArgumentError('Invalid generation snapshot');
    }
    final files = <String, String>{};
    await for (final entry in directory(
      generation!,
    ).list(recursive: true, followLinks: false)) {
      if (entry is Link) {
        throw const FileSystemException('Generation contains a symbolic link');
      }
      if (entry is! File) continue;
      final relative = p
          .relative(entry.path, from: directory(generation).path)
          .split(p.separator)
          .join('/');
      files[relative] = sha256.convert(await entry.readAsBytes()).toString();
    }
    if (!files.containsKey('source.yaml') ||
        !files.containsKey('effective.yaml')) {
      throw StateError('Generation content is incomplete');
    }
    await write(
      generation,
      'manifest.json',
      utf8.encode(
        jsonEncode({'version': 1, 'profile': profile.toJson(), 'files': files}),
      ),
    );
  }

  Future<Profile> load(String generation, {bool verify = true}) async {
    final manifest = resource(generation, 'manifest.json');
    await _requireFile(manifest);
    final data =
        jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unsupported generation manifest');
    }
    final profile = Profile.fromJson(data['profile'] as Map<String, dynamic>);
    if (profile.snapshot.generation != generation ||
        profile.snapshot.revision <= 0) {
      throw const FormatException(
        'Generation metadata does not match its path',
      );
    }
    if (verify) {
      final files = Map<String, String>.from(data['files'] as Map);
      if (!files.containsKey('source.yaml') ||
          !files.containsKey('effective.yaml')) {
        throw const FormatException('Incomplete generation manifest');
      }
      for (final entry in files.entries) {
        final file = resource(generation, entry.key);
        await _requireFile(file);
        if (sha256.convert(await file.readAsBytes()).toString() !=
            entry.value) {
          throw const FormatException('Generation resource checksum mismatch');
        }
      }
    }
    return profile;
  }

  Future<File> source(Profile profile) async {
    final generation = profile.snapshot.generation;
    final file = generation == null
        ? File(p.join(home.path, 'profiles', '${profile.id}.yaml'))
        : resource(generation, 'source.yaml');
    await _requireFile(file);
    return file;
  }

  Future<List<VpnServer>> catalog(Profile committed) async {
    final generation = committed.snapshot.generation;
    if (generation == null) return committed.snapshot.servers;
    final staged = await load(generation, verify: false);
    if (staged.id != committed.id ||
        staged.snapshot.revision != committed.snapshot.revision) {
      throw StateError('Catalog does not belong to the committed profile');
    }
    return staged.snapshot.servers;
  }

  Future<void> beginCommit(ProfileCommitJournal journal) async {
    ProfileCommitJournal.fromJson(
      jsonDecode(jsonEncode(journal.toJson())) as Map<String, dynamic>,
    );
    final staged = await load(journal.candidate.snapshot.generation!);
    if (staged.id != journal.candidate.id ||
        staged.snapshot != journal.candidate.snapshot) {
      throw StateError('Journal candidate differs from its sealed snapshot');
    }
    if (await _journal.exists()) {
      throw StateError('An earlier profile commit needs recovery');
    }
    await _atomicWrite(
      _journal,
      utf8.encode(jsonEncode(journal.toJson())),
      ProfileStoreCheckpoint.journalFlushed,
      ProfileStoreCheckpoint.journalPublished,
    );
  }

  Future<ProfileCommitJournal?> pending() async {
    if (!await _journal.exists()) return null;
    await _requireFile(_journal);
    return ProfileCommitJournal.fromJson(
      jsonDecode(await _journal.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<ProfileRecovery?> recovery({
    required int committedRevision,
    required Profile? committed,
  }) async {
    final journal = await pending();
    if (journal == null) return null;
    bool matches(Profile? expected) =>
        expected?.id == committed?.id &&
        expected?.snapshot.generation == committed?.snapshot.generation &&
        (expected?.snapshot.revision ?? 0) == committedRevision;
    if (committedRevision == journal.candidate.snapshot.revision &&
        matches(journal.candidate)) {
      return ProfileRecovery(ProfileRecoveryKind.finalize, journal);
    }
    if (committedRevision == journal.previousRevision &&
        matches(journal.previous)) {
      return ProfileRecovery(ProfileRecoveryKind.rollback, journal);
    }
    throw StateError(
      'Profile journal conflicts with the committed database revision',
    );
  }

  Future<void> publishRuntime(
    Profile profile, {
    List<int>? legacyEffective,
  }) async {
    final generation = profile.snapshot.generation;
    if (generation == null && legacyEffective == null) {
      throw StateError(
        'Legacy runtime must be generated with its app overrides',
      );
    }
    if (generation != null) await load(generation);
    await _atomicWrite(
      File(p.join(home.path, 'config.yaml')),
      generation == null
          ? legacyEffective!
          : await resource(generation, 'effective.yaml').readAsBytes(),
      ProfileStoreCheckpoint.runtimeFlushed,
      ProfileStoreCheckpoint.runtimePublished,
    );
  }

  Future<void> finishCommit(ProfileCommitJournal expected) async {
    final actual = await pending();
    if (actual == null) return;
    if (jsonEncode(actual.toJson()) != jsonEncode(expected.toJson())) {
      throw StateError('A different commit owns the recovery journal');
    }
    await _journal.delete();
    await checkpoint?.call(ProfileStoreCheckpoint.journalRemoved);
  }

  Future<List<int>?> runtimeBytes() async {
    final file = File(p.join(home.path, 'config.yaml'));
    await _checkPath(file.path);
    if (!await file.exists()) return null;
    await _requireFile(file);
    return file.readAsBytes();
  }

  Future<void> restoreRuntimeBytes(List<int>? bytes) async {
    final file = File(p.join(home.path, 'config.yaml'));
    await _checkPath(file.path);
    if (bytes == null) {
      if (await file.exists()) await file.delete();
      return;
    }
    await _atomicWrite(
      file,
      bytes,
      ProfileStoreCheckpoint.runtimeFlushed,
      ProfileStoreCheckpoint.runtimePublished,
    );
  }

  Future<Set<String>> pinnedGenerations(Profile? committed) async {
    final journal = await pending();
    return {
      ?committed?.snapshot.generation,
      ?journal?.previous?.snapshot.generation,
      ?journal?.candidate.snapshot.generation,
    };
  }

  Future<Set<int>> protectedProfileIds(Iterable<int> currentIds) async {
    final journal = await pending();
    return {...currentIds, ?journal?.previous?.id, ?journal?.candidate.id};
  }

  Future<void> discard(String generation, {required Profile? committed}) async {
    if (!_allocated.contains(generation)) {
      throw StateError('Cannot discard an unowned generation');
    }
    if ((await pinnedGenerations(committed)).contains(generation)) {
      throw StateError('Cannot discard a referenced generation');
    }
    final target = directory(generation);
    await _checkPath(target.path);
    if (await target.exists()) await target.delete(recursive: true);
    _allocated.remove(generation);
  }

  Future<void> _atomicWrite(
    File file,
    List<int> bytes,
    ProfileStoreCheckpoint flushed,
    ProfileStoreCheckpoint published,
  ) async {
    await _ensureDirectory(file.parent);
    await _checkPath(file.path);
    final temporary = File('${file.path}.${_randomId()}.tmp');
    await temporary.create(exclusive: true);
    await temporary.writeAsBytes(bytes, flush: true);
    await checkpoint?.call(flushed);
    await temporary.rename(file.path);
    await checkpoint?.call(published);
  }

  Future<void> _ensureDirectory(Directory directory) async {
    await _checkPath(directory.path);
    await directory.create(recursive: true);
    await _checkPath(directory.path);
  }

  Future<void> _requireFile(File file) async {
    await _checkPath(file.path);
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw FileSystemException('Expected a regular profile file', file.path);
    }
  }

  Future<void> _checkPath(String path) async {
    final root = p.normalize(p.absolute(home.path));
    var current = p.normalize(p.absolute(path));
    if (current != root && !p.isWithin(root, current)) {
      throw ArgumentError('Profile path escapes application storage');
    }
    while (true) {
      if (await FileSystemEntity.type(current, followLinks: false) ==
          FileSystemEntityType.link) {
        throw const FileSystemException(
          'Profile path contains a symbolic link',
        );
      }
      if (current == root) return;
      current = p.dirname(current);
    }
  }
}

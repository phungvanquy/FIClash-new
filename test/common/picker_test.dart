import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/common/picker.dart';
import 'package:test/test.dart';

base class _LocalPlatformFile extends PlatformFile {
  _LocalPlatformFile(this._file);

  final File _file;

  @override
  String get name => _file.uri.pathSegments.last;

  @override
  Uri get uri => _file.uri;

  @override
  XFile get xFile => XFile(_file.path);

  @override
  Future<int> length() => _file.length();

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      _file.openRead().map(Uint8List.fromList);
}

class _ExportPicker extends Picker {
  Uri? destination;
  Error? failure;
  Uint8List? exported;

  @override
  Future<Uri?> saveFile(String fileName, Uint8List bytes) async {
    exported = bytes;
    if (failure != null) throw failure!;
    return destination;
  }
}

void main() {
  for (final result in ['success', 'cancel', 'failure']) {
    test(
      'persistent configuration and archive survive export $result',
      () async {
        final directory = await Directory.systemTemp.createTemp('vpn_export_');
        addTearDown(() => directory.delete(recursive: true));
        final source = File('${directory.path}/sealed-source');
        await source.writeAsBytes([1, 2, 3, 4], flush: true);
        final picker = _ExportPicker()
          ..destination = result == 'success'
              ? Uri.file('${directory.path}/exported')
              : null
          ..failure = result == 'failure' ? StateError('export failed') : null;
        final operation = picker.saveFileCopy('vpn-export.zip', source.path);
        if (result == 'failure') {
          await expectLater(operation, throwsStateError);
        } else {
          expect(await operation, picker.destination);
        }
        expect(picker.exported, [1, 2, 3, 4]);
        expect(await source.readAsBytes(), [1, 2, 3, 4]);
      },
    );
  }

  group('PlatformFileExt.readBytes', () {
    test('loads bytes from the picked file path', () async {
      final directory = await Directory.systemTemp.createTemp(
        'fl_clash_picker_test_',
      );
      addTearDown(() => directory.delete(recursive: true));

      final file = File('${directory.path}/profile.yaml');
      await file.writeAsString('mixed-port: 7890');

      final platformFile = _LocalPlatformFile(file);

      final bytes = await platformFile.readBytes();

      expect(String.fromCharCodes(bytes), 'mixed-port: 7890');
    });
  });
}

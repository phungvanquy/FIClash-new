import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fl_clash/common/common.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:image_picker/image_picker.dart';

class Picker {
  Picker({Future<PlatformFile?> Function()? pickQrFile, bool? desktop})
    : _pickQrFile = pickQrFile,
      _desktop = desktop;

  final Future<PlatformFile?> Function()? _pickQrFile;
  final bool? _desktop;
  Future<PlatformFile?> pickerFile() async {
    return FilePicker.pickFile(initialDirectory: await appPath.downloadDirPath);
  }

  Future<Uri?> saveFile(String fileName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    if (!system.isAndroid && uri != null && uri.scheme == 'file') {
      final file = File(uri.toFilePath());
      await file.safeWriteAsBytes(bytes);
    }
    return uri;
  }

  Future<Uri?> saveFileWithPath(String fileName, String localPath) async {
    final localFile = File(localPath);
    if (!await localFile.exists()) {
      await localFile.create(recursive: true);
    }
    final bytes = await localFile.readAsBytes();
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    await localFile.safeDelete();
    return uri;
  }

  Future<Uri?> saveFileCopy(String fileName, String sourcePath) async =>
      saveFile(fileName, await File(sourcePath).readAsBytes());

  Future<String?> pickerConfigQRCode() async {
    try {
      final Uint8List bytes;
      if (_desktop ?? system.isDesktop) {
        final file =
            await (_pickQrFile?.call() ??
                FilePicker.pickFile(
                  type: FileType.custom,
                  allowedExtensions: ['png', 'jpg', 'jpeg'],
                ));
        if (file == null) return null;
        if (await file.length() > maxVpnQrBytes) {
          throw const VpnQrException(VpnQrError.tooLarge);
        }
        bytes = await file.readAsBytes();
      } else {
        final file = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (file == null) return null;
        if (await file.length() > maxVpnQrBytes) {
          throw const VpnQrException(VpnQrError.tooLarge);
        }
        bytes = await file.readAsBytes();
      }
      return await compute(decodeVpnQrImage, bytes);
    } on VpnQrException catch (error) {
      throw MessageException(
        error.reason == VpnQrError.tooLarge
            ? currentAppLocalizations.vpnQrImageTooLarge
            : currentAppLocalizations.pleaseUploadValidQrcode,
      );
    } catch (_) {
      throw MessageException(currentAppLocalizations.pleaseUploadValidQrcode);
    }
  }
}

extension PlatformFileExt on PlatformFile {
  Future<Uint8List> readBytes() {
    return readAsBytes();
  }
}

final picker = Picker();

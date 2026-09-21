import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

import 'vpn_intake.dart';

const maxVpnQrBytes = 16 * 1024 * 1024;
const maxVpnQrPixels = 16 * 1024 * 1024;

enum VpnQrError { invalidImage, noCode, invalidUrl, tooLarge }

class VpnQrException implements Exception {
  const VpnQrException(this.reason);
  final VpnQrError reason;
}

String decodeVpnQrImage(Uint8List bytes) {
  if (bytes.length > maxVpnQrBytes) {
    throw const VpnQrException(VpnQrError.tooLarge);
  }
  try {
    final img.Decoder decoder;
    if (bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71) {
      decoder = img.PngDecoder();
    } else if (bytes.length >= 2 && bytes[0] == 255 && bytes[1] == 216) {
      decoder = img.JpegDecoder();
    } else {
      throw const VpnQrException(VpnQrError.invalidImage);
    }
    final info = decoder.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) {
      throw const VpnQrException(VpnQrError.invalidImage);
    }
    if (info.width > 8192 ||
        info.height > 8192 ||
        info.width * info.height > maxVpnQrPixels) {
      throw const VpnQrException(VpnQrError.tooLarge);
    }
    final decoded = decoder.decodeFrame(0);
    if (decoded == null) throw const VpnQrException(VpnQrError.invalidImage);
    final pixels = Int32List(decoded.width * decoded.height);
    for (final pixel in decoded) {
      final alpha = pixel.aNormalized;
      final red = (pixel.rNormalized * alpha * 255 + 255 * (1 - alpha)).round();
      final green = (pixel.gNormalized * alpha * 255 + 255 * (1 - alpha))
          .round();
      final blue = (pixel.bNormalized * alpha * 255 + 255 * (1 - alpha))
          .round();
      pixels[pixel.y * decoded.width + pixel.x] = red << 16 | green << 8 | blue;
    }
    final source = RGBLuminanceSource(decoded.width, decoded.height, pixels);
    final hints = DecodeHints()..put(DecodeHintType.tryHarder);
    for (final luminance in [source, source.invert()]) {
      try {
        final result = QRCodeReader().decode(
          BinaryBitmap(HybridBinarizer(luminance)),
          hints: hints,
        );
        final parsed = VpnUrlIntake.parse(result.text);
        if (parsed is VpnUrlAccepted) return parsed.url;
        throw const VpnQrException(VpnQrError.invalidUrl);
      } on ReaderException {
        continue;
      }
    }
    throw const VpnQrException(VpnQrError.noCode);
  } on VpnQrException {
    rethrow;
  } catch (_) {
    throw const VpnQrException(VpnQrError.invalidImage);
  }
}

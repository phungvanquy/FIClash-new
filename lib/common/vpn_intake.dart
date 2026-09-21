import 'protocol.dart' show protocolSchemes;

enum VpnIntakeError { empty, invalidUrl, unsupportedScheme, multipleUrls }

sealed class VpnUrlIntake {
  const VpnUrlIntake();

  factory VpnUrlIntake.parse(String input) => _parse(input, allowWrapper: true);

  static VpnUrlIntake _parse(String input, {required bool allowWrapper}) {
    final value = input.trim();
    if (value.isEmpty) return const VpnUrlRejected(VpnIntakeError.empty);
    if (RegExp(r'\s+https?://', caseSensitive: false).hasMatch(value)) {
      return const VpnUrlRejected(VpnIntakeError.multipleUrls);
    }
    if (RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(value) ||
        RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(value) ||
        value.contains(r'\')) {
      return const VpnUrlRejected(VpnIntakeError.invalidUrl);
    }
    try {
      final uri = Uri.parse(value);
      if (allowWrapper && protocolSchemes.contains(uri.scheme)) {
        if (uri.host != 'install-config' ||
            uri.path.isNotEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.hasPort) {
          return const VpnUrlRejected(VpnIntakeError.invalidUrl);
        }
        final urls = <String>[];
        for (final parameter in uri.query.split('&')) {
          final separator = parameter.indexOf('=');
          if (separator < 0) {
            return const VpnUrlRejected(VpnIntakeError.invalidUrl);
          }
          final key = Uri.decodeComponent(parameter.substring(0, separator));
          if (key == 'url') {
            urls.add(Uri.decodeComponent(parameter.substring(separator + 1)));
          } else if (key != 'name') {
            return const VpnUrlRejected(VpnIntakeError.invalidUrl);
          }
        }
        if (urls.length != 1) {
          return VpnUrlRejected(
            urls.isEmpty
                ? VpnIntakeError.invalidUrl
                : VpnIntakeError.multipleUrls,
          );
        }
        return _parse(urls.single, allowWrapper: false);
      }
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return const VpnUrlRejected(VpnIntakeError.unsupportedScheme);
      }
      if (!uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.host.contains(',') ||
          (uri.hasPort && (uri.port < 1 || uri.port > 65535))) {
        return const VpnUrlRejected(VpnIntakeError.invalidUrl);
      }
      return VpnUrlAccepted(value);
    } on FormatException {
      return const VpnUrlRejected(VpnIntakeError.invalidUrl);
    }
  }
}

final class VpnUrlAccepted extends VpnUrlIntake {
  const VpnUrlAccepted(this.url);
  final String url;
}

final class VpnUrlRejected extends VpnUrlIntake {
  const VpnUrlRejected(this.reason);
  final VpnIntakeError reason;
}

import 'package:fl_clash/common/system.dart';
import 'package:proxy/proxy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final proxy = system.isDesktop ? Proxy() : null;

final systemProxyAdapterProvider = Provider<Proxy?>((ref) => proxy);

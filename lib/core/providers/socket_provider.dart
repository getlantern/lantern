// lib/providers/socket_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/ffi/socket_client.dart';

final socketClientProvider = Provider<SocketClient>((ref) {
  return SocketClient(host: '127.0.0.1', port: 9999);
});

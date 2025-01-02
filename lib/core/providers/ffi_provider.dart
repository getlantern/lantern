// lib/providers/ffi_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lantern/core/ffi/ffi_client.dart';

final ffiClientProvider = Provider<FFIClient>((ref) {
  return FFIClient();
});

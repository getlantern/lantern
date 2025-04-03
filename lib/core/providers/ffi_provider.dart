// // lib/providers/ffi_provider.dart

// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:lantern/core/ffi/ffi_client.dart';
// import 'package:lantern/core/services/logger_service.dart';
// import 'package:lantern/core/utils/log_utils.dart';

// final ffiClientProvider = FutureProvider<FFIClient>((ref) async {
//   final baseDir = await LogUtils.getAppLogDirectory();
//   appLogger.debug("Using base directory $baseDir");
//   return FFIClient(baseDir);
// });

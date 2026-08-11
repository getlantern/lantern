import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _SetAppBuildVersionNative = Void Function(Pointer<Utf16> buildVersion);
typedef _SetAppBuildVersionDart = void Function(Pointer<Utf16> buildVersion);

/// Tells WinSparkle which internal build number to compare with the appcast.
///
/// The plugin otherwise compares Lantern's display version (for example,
/// `9.1.20`) while Sparkle on macOS compares the numeric bundle build. Release
/// CI uses that shared build number for both desktop platforms.
void setWinSparkleBuildVersion(String buildVersion) {
  final normalized = buildVersion.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(
      buildVersion,
      'buildVersion',
      'must not be empty',
    );
  }

  final winSparkle = DynamicLibrary.open('WinSparkle.dll');
  final setBuildVersion = winSparkle
      .lookupFunction<_SetAppBuildVersionNative, _SetAppBuildVersionDart>(
        'win_sparkle_set_app_build_version',
      );
  final nativeBuildVersion = normalized.toNativeUtf16();
  try {
    setBuildVersion(nativeBuildVersion);
  } finally {
    calloc.free(nativeBuildVersion);
  }
}

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lantern/lantern/lantern_generated_bindings.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Owns the update transport in the app process, independently of the VPN service.
class DesktopUpdateRelay {
  DesktopUpdateRelay({@visibleForTesting TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  static const _channel = MethodChannel('org.getlantern.lantern/method');
  final TargetPlatform _platform;
  Future<String>? _starting;
  bool _closed = false;

  /// Returns the local feed URL, sharing startup work between callers.
  /// A failed start can be retried.
  Future<String> start(String feedUrl) {
    if (_closed) throw StateError('Update relay is closed');
    return _starting ??= _start(feedUrl).catchError((Object error) {
      _starting = null;
      throw error;
    });
  }

  Future<String> _start(String feedUrl) async {
    final support = await getApplicationSupportDirectory();
    final cacheDir = p.join(support.path, 'update-transport');
    if (_platform == TargetPlatform.macOS) {
      final address = await _channel.invokeMethod<String>('startUpdateRelay', {
        'cacheDir': cacheDir,
        'feedURL': feedUrl,
      });
      if (address == null) {
        throw StateError('Update relay did not return a URL');
      }
      return address;
    }
    if (_platform == TargetPlatform.windows) {
      return Isolate.run(() => _startWindows(cacheDir, feedUrl));
    }
    throw UnsupportedError('Desktop update relay requires macOS or Windows');
  }

  /// Waits for pending startup, then stops the relay. This instance cannot restart.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final starting = _starting;
    if (starting == null) return;
    try {
      await starting;
    } catch (_) {
      return;
    }
    if (_platform == TargetPlatform.macOS) {
      await _channel.invokeMethod<void>('stopUpdateRelay');
    } else if (_platform == TargetPlatform.windows) {
      await Isolate.run(() {
        _windowsBindings().stopUpdateRelay();
      });
    }
  }
}

LanternBindings _windowsBindings() {
  final directory = p.dirname(Platform.resolvedExecutable);
  for (final relative in [
    'liblantern.dll',
    'bin/liblantern.dll',
    'bin/windows/liblantern.dll',
  ]) {
    final file = p.join(directory, relative);
    if (File(file).existsSync()) {
      return LanternBindings(DynamicLibrary.open(file));
    }
  }
  throw StateError('Lantern native library was not found');
}

String _startWindows(String cacheDir, String feedUrl) {
  final bindings = _windowsBindings();
  final cache = cacheDir.toNativeUtf8();
  final feed = feedUrl.toNativeUtf8();
  try {
    final response = bindings.startUpdateRelay(cache.cast(), feed.cast());
    if (response == nullptr) {
      throw StateError('Update relay did not return a URL');
    }
    try {
      final value = response.cast<Utf8>().toDartString();
      if (value.startsWith('{')) {
        throw StateError('Update relay failed: ${jsonDecode(value)['error']}');
      }
      return value;
    } finally {
      bindings.freeCString(response);
    }
  } finally {
    calloc.free(cache);
    calloc.free(feed);
  }
}

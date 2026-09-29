import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
        _windowsLibrary().lookupFunction<Void Function(), void Function()>(
          'stopUpdateRelay',
        )();
      });
    }
  }
}

DynamicLibrary _windowsLibrary() {
  final directory = p.dirname(Platform.resolvedExecutable);
  for (final relative in [
    'liblantern.dll',
    'bin/liblantern.dll',
    'bin/windows/liblantern.dll',
  ]) {
    final file = p.join(directory, relative);
    if (File(file).existsSync()) return DynamicLibrary.open(file);
  }
  throw StateError('Lantern native library was not found');
}

String _startWindows(String cacheDir, String feedUrl) {
  final library = _windowsLibrary();
  final start = library
      .lookupFunction<
        Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>),
        Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)
      >('startUpdateRelay');
  final free = library
      .lookupFunction<
        Void Function(Pointer<Utf8>),
        void Function(Pointer<Utf8>)
      >('freeCString');
  final cache = cacheDir.toNativeUtf8();
  final feed = feedUrl.toNativeUtf8();
  try {
    final response = start(cache, feed);
    if (response == nullptr) {
      throw StateError('Update relay did not return a URL');
    }
    try {
      final value = response.toDartString();
      if (value.startsWith('{')) {
        throw StateError('Update relay failed: ${jsonDecode(value)['error']}');
      }
      return value;
    } finally {
      free(response);
    }
  } finally {
    calloc.free(cache);
    calloc.free(feed);
  }
}

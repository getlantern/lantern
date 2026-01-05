import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:lantern/core/models/entity/app_data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_icon_provider.g.dart';

const _channelPrefix = 'org.getlantern.lantern';
const MethodChannel _methodChannel = MethodChannel('$_channelPrefix/method');

String stableAppId(AppData a) {
  if (Platform.isWindows || Platform.isMacOS) return a.appPath;
  return a.bundleId;
}

@riverpod
class AppIconCache extends _$AppIconCache {
  @override
  Map<String, Uint8List> build() => const {};

  Uint8List? get(String key) => state[key];

  void put(String key, Uint8List bytes) {
    state = {...state, key: bytes};
  }
}

@riverpod
Future<Uint8List?> appIconBytes(Ref ref, AppData app) async {
  final id = stableAppId(app);
  if (id.isEmpty) return null;

  final cacheNotifier = ref.read(appIconCacheProvider.notifier);
  final cached = ref.read(appIconCacheProvider)[id];
  if (cached != null) return cached;

  // If native stream already provided bytes, cache them
  final existing = app.iconBytes;
  if (existing != null && existing.isNotEmpty) {
    cacheNotifier.put(id, existing);
    return existing;
  }

  // macOS: request PNG bytes from Swift on-demand
  if (Platform.isMacOS) {
    final bytes = await _methodChannel.invokeMethod<Uint8List>(
      'appIconBytes',
      {
        'iconPath': app.iconPath,
        'appPath': app.appPath,
        'sizePx': 48,
      },
    );
    if (bytes != null && bytes.isNotEmpty) {
      cacheNotifier.put(id, bytes);
    }
    return bytes;
  }

  return null;
}

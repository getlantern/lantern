import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

@immutable
class AppIconKey {
  final String id;
  final String iconPath;
  final String appPath;
  final Uint8List? existingBytes;

  const AppIconKey({
    required this.id,
    required this.iconPath,
    required this.appPath,
    required this.existingBytes,
  });

  @override
  bool operator ==(Object other) =>
      other is AppIconKey &&
      other.id == id &&
      other.iconPath == iconPath &&
      other.appPath == appPath;

  @override
  int get hashCode => Object.hash(id, iconPath, appPath);
}

@Riverpod(keepAlive: true)
class AppIconCache extends _$AppIconCache {
  @override
  Map<String, Uint8List> build() => const {};

  Uint8List? get(String key) => state[key];

  void put(String key, Uint8List bytes) {
    state = {...state, key: bytes};
  }
}

@Riverpod(keepAlive: true)
Future<Uint8List?> appIconBytes(Ref ref, AppIconKey k) async {
  if (k.id.isEmpty) return null;

  final cache = ref.watch(appIconCacheProvider);
  final cacheNotifier = ref.read(appIconCacheProvider.notifier);

  final cached = cache[k.id];
  if (cached != null) return cached;

  final existing = k.existingBytes;
  if (existing != null && existing.isNotEmpty) {
    cacheNotifier.put(k.id, existing);
    return existing;
  }

  if (Platform.isMacOS) {
    final bytes = await _methodChannel.invokeMethod<Uint8List>(
      'appIconBytes',
      {
        'iconPath': k.iconPath,
        'appPath': k.appPath,
        'sizePx': 48,
      },
    );
    if (bytes != null && bytes.isNotEmpty) {
      cacheNotifier.put(k.id, bytes);
    }
    return bytes;
  }

  return null;
}

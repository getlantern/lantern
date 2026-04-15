import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lantern/core/services/injection_container.dart';
import 'package:lantern/core/services/logger_service.dart';
import 'package:lantern/core/utils/storage_utils.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_icon_provider.g.dart';

const _channelPrefix = 'org.getlantern.lantern';
const MethodChannel _methodChannel = MethodChannel('$_channelPrefix/method');
const _iconCacheDirName = 'app-icons';

const int _fnvOffset64 = 0xcbf29ce484222325;
const int _fnvPrime64 = 0x100000001b3;
const int _fnvMask64 = 0xffffffffffffffff;

@immutable
class AppIconKey {
  final String id;
  final String iconPath;
  final String appPath;

  final Uint8List? existingBytes;
  final int existingBytesLength;
  final int existingBytesHash;

  AppIconKey({
    required this.id,
    required this.iconPath,
    required this.appPath,
    required this.existingBytes,
  }) : existingBytesLength = existingBytes?.length ?? 0,
       existingBytesHash = _hashBytes(existingBytes);

  static int _hashBytes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return 0;
    }

    var hash = _fnvOffset64;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * _fnvPrime64) & _fnvMask64;
    }
    return hash;
  }

  @override
  bool operator ==(Object other) =>
      other is AppIconKey &&
      other.id == id &&
      other.iconPath == iconPath &&
      other.appPath == appPath &&
      other.existingBytesLength == existingBytesLength &&
      other.existingBytesHash == existingBytesHash;

  @override
  int get hashCode => Object.hash(
    id,
    iconPath,
    appPath,
    existingBytesLength,
    existingBytesHash,
  );
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
    unawaited(_writeCachedIconToDisk(k, existing));
    return existing;
  }

  final diskCached = await _readCachedIconFromDisk(k);
  if (diskCached != null && diskCached.isNotEmpty) {
    cacheNotifier.put(k.id, diskCached);
    return diskCached;
  }

  final fetched = await _loadIconBytesForRow(k);
  if (fetched != null && fetched.isNotEmpty) {
    cacheNotifier.put(k.id, fetched);
    unawaited(_writeCachedIconToDisk(k, fetched));
    return fetched;
  }

  return null;
}

Future<Uint8List?> _loadIconBytesForRow(AppIconKey k) async {
  if (k.iconPath.isEmpty && k.appPath.isEmpty) {
    return null;
  }

  if (Platform.isWindows) {
    try {
      if (!sl.isRegistered<LanternService>()) {
        return null;
      }
      await sl.isReady<LanternService>();
      final lanternService = sl<LanternService>();
      return await lanternService.loadInstalledAppIconBytes(
        appPath: k.appPath,
        iconPath: k.iconPath,
      );
    } catch (e, st) {
      appLogger.error('Failed to load app icon bytes from Windows core', e, st);
      return null;
    }
  }

  if (Platform.isMacOS) {
    final bytes = await _methodChannel.invokeMethod<Uint8List>('appIconBytes', {
      'iconPath': k.iconPath,
      'appPath': k.appPath,
      'sizePx': 48,
    });
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }
  }

  return null;
}

Future<Uint8List?> _readCachedIconFromDisk(AppIconKey k) async {
  try {
    final file = await _iconCacheFileForKey(_diskCacheKey(k));
    if (!await file.exists()) {
      return null;
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return null;
    }
    return bytes;
  } catch (e, st) {
    appLogger.error('Failed to read cached app icon bytes', e, st);
    return null;
  }
}

Future<void> _writeCachedIconToDisk(AppIconKey k, Uint8List bytes) async {
  if (bytes.isEmpty) {
    return;
  }
  try {
    final file = await _iconCacheFileForKey(_diskCacheKey(k));
    await file.writeAsBytes(bytes, flush: false);
  } catch (e, st) {
    appLogger.error('Failed to write cached app icon bytes', e, st);
  }
}

Future<File> _iconCacheFileForKey(String cacheKey) async {
  final appDir = await AppStorageUtils.getAppDirectory();
  final cacheDir = Directory(p.join(appDir.path, _iconCacheDirName));
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }
  return File(p.join(cacheDir.path, '$cacheKey.png'));
}

String _diskCacheKey(AppIconKey k) {
  final source = '${k.id}|${k.appPath}|${k.iconPath}';
  var hash = _fnvOffset64;
  for (final codeUnit in utf8.encode(source)) {
    hash ^= codeUnit;
    hash = (hash * _fnvPrime64) & _fnvMask64;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

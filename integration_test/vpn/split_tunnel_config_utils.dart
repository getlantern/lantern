import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

const windowsPublicSplitTunnelPath =
    r'C:\Users\Public\Lantern\data\split-tunnel.json';
const macSharedSplitTunnelPath = '/Users/Shared/Lantern/split-tunnel.json';

List<String> splitTunnelRuleFileCandidates() {
  final candidates = <String>{};

  if (Platform.isWindows) {
    candidates.add(windowsPublicSplitTunnelPath);

    final programData = Platform.environment['ProgramData'];
    if (programData != null && programData.isNotEmpty) {
      candidates.add('$programData\\Lantern\\data\\split-tunnel.json');
    }

    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      candidates.add('$localAppData\\Lantern\\data\\split-tunnel.json');
    }
  } else if (Platform.isMacOS) {
    candidates.add(macSharedSplitTunnelPath);

    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      candidates.add(
        '$home/Library/Application Support/org.getlantern.lantern/split-tunnel.json',
      );
    }
  } else if (Platform.isLinux) {
    final xdgDataHome = Platform.environment['XDG_DATA_HOME'];
    if (xdgDataHome != null && xdgDataHome.isNotEmpty) {
      candidates.add('$xdgDataHome/org.getlantern.lantern/split-tunnel.json');
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      candidates.add(
        '$home/.local/share/org.getlantern.lantern/split-tunnel.json',
      );
    }
  }

  return candidates.toList(growable: false);
}

Future<MapEntry<String, String>?> readSplitTunnelConfigFromDisk() async {
  final candidates = splitTunnelRuleFileCandidates();
  if (candidates.isEmpty) {
    return null;
  }

  for (final path in candidates) {
    final file = File(path);
    if (!await file.exists()) {
      continue;
    }
    try {
      final content = await file.readAsString();
      return MapEntry(path, content);
    } catch (error) {
      debugPrint('Split tunnel config read failed at "$path": $error');
    }
  }

  return null;
}

Future<void> printSplitTunnelConfigSnapshot(String stage) async {
  final snapshot = await readSplitTunnelConfigFromDisk();
  if (snapshot == null) {
    debugPrint(
      'Split tunnel config snapshot [$stage]: file not found. '
      'Checked: ${splitTunnelRuleFileCandidates().join(', ')}',
    );
    return;
  }

  final content = snapshot.value.trim();
  debugPrint(
    'Split tunnel config snapshot [$stage] (${snapshot.key}): '
    '${content.isEmpty ? '(empty file)' : content}',
  );
}

bool splitTunnelConfigContainsDomainSuffix(
  String content, {
  required String domain,
}) {
  return _containsRuleEntry(
    content,
    key: 'domain_suffix',
    expectedSubstring: domain,
  );
}

bool splitTunnelConfigContainsProcessPath(
  String content, {
  required String processPathFragment,
}) {
  return _containsRuleEntry(
    content,
    key: 'process_path',
    expectedSubstring: processPathFragment,
  );
}

Future<bool> waitForDomainPersistenceInSplitTunnelConfig({
  required String domain,
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final snapshot = await readSplitTunnelConfigFromDisk();
    final content = snapshot?.value ?? '';
    if (splitTunnelConfigContainsDomainSuffix(content, domain: domain)) {
      return true;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

Future<bool> waitForProcessPathPersistenceInSplitTunnelConfig({
  required String processPathFragment,
  required Duration timeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    final snapshot = await readSplitTunnelConfigFromDisk();
    final content = snapshot?.value ?? '';
    if (splitTunnelConfigContainsProcessPath(
      content,
      processPathFragment: processPathFragment,
    )) {
      return true;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

bool _containsRuleEntry(
  String content, {
  required String key,
  required String expectedSubstring,
}) {
  final normalizedNeedle = expectedSubstring.trim().toLowerCase();
  if (normalizedNeedle.isEmpty) {
    return false;
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(content);
  } catch (_) {
    return false;
  }

  return _containsRuleEntryInNode(
    decoded,
    key: key,
    normalizedNeedle: normalizedNeedle,
  );
}

bool _containsRuleEntryInNode(
  dynamic node, {
  required String key,
  required String normalizedNeedle,
}) {
  if (node is Map) {
    for (final entry in node.entries) {
      final entryKey = entry.key.toString();
      final value = entry.value;
      if (entryKey == key &&
          _ruleValueContainsNeedle(value, normalizedNeedle)) {
        return true;
      }
      if (_containsRuleEntryInNode(
        value,
        key: key,
        normalizedNeedle: normalizedNeedle,
      )) {
        return true;
      }
    }
    return false;
  }

  if (node is List) {
    for (final item in node) {
      if (_containsRuleEntryInNode(
        item,
        key: key,
        normalizedNeedle: normalizedNeedle,
      )) {
        return true;
      }
    }
  }

  return false;
}

bool _ruleValueContainsNeedle(dynamic value, String normalizedNeedle) {
  if (value is String) {
    return value.toLowerCase().contains(normalizedNeedle);
  }
  if (value is List) {
    for (final item in value) {
      if (_ruleValueContainsNeedle(item, normalizedNeedle)) {
        return true;
      }
    }
    return false;
  }
  return false;
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:path/path.dart' as p;

import '../utils/widget_wait_utils.dart';

Future<void> revealBypassedApp(WidgetTester tester, Finder row) async {
  final scrollable = find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  // Selected apps are above the picker and can be offstage after adding one.
  position.jumpTo(position.minScrollExtent);
  await tester.pump();
  await WidgetWaitUtils.waitForFinder(
    tester,
    row,
    timeout: const Duration(seconds: 20),
    reason: 'Manually selected executable was not shown in the bypass list',
  );
  await tester.ensureVisible(row);
  await tester.pump(const Duration(milliseconds: 200));
  expect(
    find
        .descendant(of: row, matching: find.byType(AppIconButton))
        .hitTestable(),
    findsOneWidget,
  );
}

List<String> splitTunnelRuleFileCandidates({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final programData = env['ProgramData'];
  final candidates = <String>{
    // Read the daemon's active file before any leftover client configuration.
    if (programData != null && programData.isNotEmpty)
      p.windows.join(programData, 'Lantern', 'split-tunnel.json'),
    r'C:\Users\Public\Lantern\data\split-tunnel.json',
  };
  for (final variable in ['PUBLIC', 'ProgramData', 'LOCALAPPDATA']) {
    final directory = env[variable];
    if (directory != null && directory.isNotEmpty) {
      candidates.add(
        p.windows.join(directory, 'Lantern', 'data', 'split-tunnel.json'),
      );
    }
  }
  return candidates.toList(growable: false);
}

Future<MapEntry<String, String>?> readSplitTunnelConfigFromDisk({
  Iterable<String>? paths,
}) async {
  if (paths == null && !Platform.isWindows) return null;
  for (final path in paths ?? splitTunnelRuleFileCandidates()) {
    final file = File(path);
    if (!await file.exists()) continue;
    try {
      return MapEntry(path, await file.readAsString());
    } on FileSystemException catch (error) {
      debugPrint('Split tunnel config read failed at "$path": $error');
    }
  }
  return null;
}

/// Read exact values from nested rules, not matching text elsewhere in the file.
/// A missing or malformed rule set is not evidence that a rule was removed.
Set<String>? splitTunnelRuleValues(String content, String field) {
  final Object? decoded;
  try {
    decoded = jsonDecode(content);
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic> || decoded['rules'] is! List) {
    return null;
  }
  final values = <String>{};
  void visit(Object? node) {
    if (node is Map<String, dynamic>) {
      final items = node[field];
      if (items is String) {
        values.add(items);
      } else if (items is List) {
        values.addAll(items.whereType<String>());
      }
      visit(node['rules']);
    } else if (node is List) {
      node.forEach(visit);
    }
  }

  visit(decoded['rules']);
  return values;
}

Future<bool> waitForSplitTunnelRule({
  required String field,
  required String value,
  bool present = true,
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final snapshot = await readSplitTunnelConfigFromDisk();
    final values = snapshot == null
        ? null
        : splitTunnelRuleValues(snapshot.value, field);
    if (values != null &&
        values.any((item) => item.toLowerCase() == value.toLowerCase()) ==
            present) {
      return true;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}

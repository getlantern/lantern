import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:lantern/core/common/app_buttons.dart';
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/core/widgets/search_bar.dart';
import 'package:lantern/features/split_tunneling/apps_split_tunneling.dart';
import 'package:lantern/lantern/lantern_service.dart';
import 'package:path/path.dart' as p;

import '../utils/widget_wait_utils.dart';

T requireSplitTunnelResult<T>(Either<Failure, T> result, String operation) =>
    result.fold(
      (failure) => fail('$operation: ${failure.error}'),
      (value) => value,
    );

Future<void> restoreSplitTunnelSnapshot(
  LanternService service,
  SplitTunnelState saved,
) async {
  final opposite = saved.policy == SplitTunnelPolicy.bypass
      ? 'include'
      : 'exclude';
  requireSplitTunnelResult(
    await service.switchSplitTunnelPolicy(opposite),
    'Reset smoke selections',
  );
  requireSplitTunnelResult(
    await service.switchSplitTunnelPolicy(saved.policy.wireValue),
    'Restore split-tunnel mode',
  );
  for (final entry in saved.filters.entries) {
    for (final selector in entry.value) {
      requireSplitTunnelResult(
        await service.addSplitTunnelItem(entry.key, selector),
        'Restore split-tunnel selection',
      );
    }
  }
  requireSplitTunnelResult(
    await service.setSplitTunnelingEnabled(saved.enabled),
    'Restore split-tunnel enabled state',
  );
}

Future<void> expectInstalledApp(
  WidgetTester tester, {
  required String query,
  required Finder row,
}) async {
  final searchBar = find.byType(AppSearchBar);
  final searchButton = find
      .descendant(of: searchBar, matching: find.byType(IconButton))
      .last;
  final searchField = find.descendant(
    of: searchBar,
    matching: find.byType(TextField),
  );
  expect(searchField, findsNothing);
  await tester.tap(searchButton);
  try {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(searchField, query);
    await tester.pump(const Duration(milliseconds: 200));
    final scrollable = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    position.jumpTo(position.minScrollExtent);
    await tester.pump();
    await tester.scrollUntilVisible(
      row,
      250,
      scrollable: scrollable,
      maxScrolls: 20,
    );
    expect(
      tester.widget<AppRow>(row).enabled,
      isFalse,
      reason: 'Expected an Installed Apps row, not a saved bypass',
    );
    expect(
      find
          .descendant(of: row, matching: find.byType(AppIconButton))
          .hitTestable(),
      findsOneWidget,
    );
  } finally {
    await tester.tap(searchButton);
    await tester.pump(const Duration(milliseconds: 200));
  }
}

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

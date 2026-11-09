import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show AppTheme;
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/core/utils/failure.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/features/split_tunneling/split_tunneling.dart';

class _Snapshot extends SplitTunnel {
  _Snapshot({this.supported = true, this.policy = SplitTunnelPolicy.bypass});
  final bool supported;
  final SplitTunnelPolicy policy;
  final switches = <SplitTunnelPolicy>[];
  Failure? failure;
  @override
  Future<SplitTunnelState> build() async =>
      SplitTunnelState(enabled: true, policy: policy, supported: supported);
  @override
  Future<Failure?> switchPolicy(SplitTunnelPolicy next) async {
    switches.add(next);
    if (failure == null) {
      state = AsyncData(
        SplitTunnelState(enabled: true, policy: next, supported: true),
      );
    }
    return failure;
  }
}

Future<void> _pump(WidgetTester tester, _Snapshot notifier) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [splitTunnelProvider.overrideWith(() => notifier)],
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.appTheme(),
          home: const SplitTunneling(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('older daemon disables Include only', (tester) async {
    final notifier = _Snapshot(supported: false);
    await _pump(tester, notifier);
    final tile = find.byKey(const Key('split_tunneling.mode.include'));
    expect(tester.widget<ListTile>(tile).enabled, isFalse);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(notifier.switches, isEmpty);
  });

  for (final policy in SplitTunnelPolicy.values) {
    testWidgets(
      '${policy.name} switch requires confirmation and can be cancelled',
      (tester) async {
        final target = policy == SplitTunnelPolicy.bypass
            ? SplitTunnelPolicy.includeOnly
            : SplitTunnelPolicy.bypass;
        final notifier = _Snapshot(policy: policy);
        await _pump(tester, notifier);
        final tile = find.byKey(
          Key('split_tunneling.mode.${target.wireValue}'),
        );
        await tester.tap(tile);
        await tester.pumpAndSettle();
        expect(notifier.switches, isEmpty);
        await tester.tap(find.byKey(const Key('split_tunneling.mode.cancel')));
        await tester.pumpAndSettle();
        expect(notifier.switches, isEmpty);
        await tester.tap(tile);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('split_tunneling.mode.confirm')));
        await tester.pumpAndSettle();
        expect(notifier.switches, [target]);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );
  }

  testWidgets('mutation failure is visible and current mode remains selected', (
    tester,
  ) async {
    final notifier = _Snapshot()
      ..failure = Failure(
        error: 'failed',
        localizedErrorMessage: 'Unable to apply mode',
      );
    await _pump(tester, notifier);
    await tester.tap(find.byKey(const Key('split_tunneling.mode.include')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('split_tunneling.mode.confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Unable to apply mode'), findsOneWidget);
    final selected = find.descendant(
      of: find.byKey(const Key('split_tunneling.mode.exclude')),
      matching: find.byIcon(Icons.radio_button_checked),
    );
    expect(selected, findsOneWidget);
  });
}

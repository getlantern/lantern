import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show AppTheme;
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/features/split_tunneling/split_tunneling.dart';

class _Snapshot extends SplitTunnel {
  _Snapshot(this.policy);
  final SplitTunnelPolicy policy;
  @override
  Future<SplitTunnelState> build() async =>
      SplitTunnelState(enabled: true, policy: policy);
}

void main() {
  for (final policy in SplitTunnelPolicy.values) {
    testWidgets('${policy.name} is shown on both rows, with no picker', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            splitTunnelProvider.overrideWith(() => _Snapshot(policy)),
          ],
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
      for (final (tile, label) in [
        ('split_tunneling.apps_tile', policy.appsLabelKey),
        ('split_tunneling.websites_tile', policy.sitesLabelKey),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(Key(tile)),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      for (final mode in SplitTunnelPolicy.values) {
        expect(
          find.byKey(Key('split_tunneling.mode.${mode.wireValue}')),
          findsNothing,
        );
      }
    });
  }
}

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/common.dart' show AppTheme;
import 'package:lantern/core/models/split_tunnel_state.dart';
import 'package:lantern/features/split_tunneling/provider/split_tunnel_notifier.dart';
import 'package:lantern/features/split_tunneling/split_tunnel_mode_picker.dart';
import 'package:lantern/features/split_tunneling/split_tunneling.dart';

class _Snapshot extends SplitTunnel {
  _Snapshot(this.policy, {this.enabled = true});
  final SplitTunnelPolicy policy;
  final bool enabled;
  @override
  Future<SplitTunnelState> build() async =>
      SplitTunnelState(enabled: enabled, policy: policy);
}

Future<void> _pump(WidgetTester tester, _Snapshot snapshot) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [splitTunnelProvider.overrideWith(() => snapshot)],
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
  for (final policy in SplitTunnelPolicy.values) {
    testWidgets('${policy.name} is selected in the mode picker', (
      tester,
    ) async {
      await _pump(tester, _Snapshot(policy));
      for (final mode in SplitTunnelPolicy.values) {
        final tile = find.byKey(Key('split_tunneling.mode.${mode.wireValue}'));
        expect(
          find.descendant(of: tile, matching: find.text(mode.labelKey)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tile, matching: find.text(mode.descriptionKey)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: tile,
            matching: find.byIcon(Icons.radio_button_checked),
          ),
          mode == policy ? findsOneWidget : findsNothing,
        );
      }
      expect(
        find.byKey(const Key('split_tunneling.apps_tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('split_tunneling.websites_tile')),
        findsOneWidget,
      );
    });
  }

  testWidgets('the mode picker is hidden while split tunneling is off', (
    tester,
  ) async {
    await _pump(tester, _Snapshot(SplitTunnelPolicy.bypass, enabled: false));
    expect(
      find.byKey(const Key('split_tunneling.enable_toggle')),
      findsOneWidget,
    );
    expect(find.byType(SplitTunnelModePicker), findsNothing);
    expect(find.byKey(const Key('split_tunneling.apps_tile')), findsNothing);
  });
}

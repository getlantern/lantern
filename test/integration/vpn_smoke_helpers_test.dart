import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_dialog.dart';
import 'package:lantern/core/common/app_eum.dart';
import 'package:lantern/core/common/app_theme.dart';

import '../../integration_test/vpn/vpn_smoke_helpers.dart';

void main() {
  testWidgets('connect smoke confirms the VPN conflict dialog', (tester) async {
    await _showVpnPage(tester, conflict: true);
    await tester.tap(find.byKey(const Key('vpn.toggle')));

    await VpnStateFinders().waitFor(
      tester,
      expected: const [VPNStatus.connected],
      timeout: const Duration(seconds: 2),
      reason: 'Connect anyway did not start the VPN',
      allowVpnConflict: true,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('connect smoke also works without a VPN conflict', (
    tester,
  ) async {
    await _showVpnPage(tester, conflict: false);
    await tester.tap(find.byKey(const Key('vpn.toggle')));

    await VpnStateFinders().waitFor(
      tester,
      expected: const [VPNStatus.connected],
      timeout: const Duration(seconds: 2),
      reason: 'VPN did not connect',
      allowVpnConflict: true,
    );
  });

  testWidgets('waiting for disconnect does not confirm a VPN conflict', (
    tester,
  ) async {
    await _showVpnPage(tester, conflict: true);
    await tester.tap(find.byKey(const Key('vpn.toggle')));

    await VpnStateFinders().waitFor(
      tester,
      expected: const [VPNStatus.disconnected],
      timeout: const Duration(seconds: 2),
      reason: 'VPN should remain disconnected',
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}

Future<void> _showVpnPage(WidgetTester tester, {required bool conflict}) async {
  var state = VPNStatus.disconnected;
  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: const Size(390, 844),
      child: MaterialApp(
        theme: AppTheme.appTheme(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                Text(state.name, key: Key('vpn.status.${state.name}')),
                TextButton(
                  key: const Key('vpn.toggle'),
                  onPressed: () {
                    void connect() =>
                        setState(() => state = VPNStatus.connected);
                    if (!conflict) {
                      connect();
                      return;
                    }
                    AppDialog.vpnConflictDialog(
                      context: context,
                      onConnectAnyway: () {
                        Navigator.of(context).pop();
                        connect();
                      },
                    );
                  },
                  child: const Text('Connect'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/features/action_mode/provider/action_mode_tab_visible_notifier.dart';
import 'package:lantern/features/home/home_route_current.dart';

class _Reporter extends HookConsumerWidget {
  const _Reporter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useReportHomeRouteCurrent(context, ref);
    return const SizedBox();
  }
}

void main() {
  testWidgets('reports false while a route covers it, true once popped', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(navigatorKey: navigator, home: const _Reporter()),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(homeRouteCurrentProvider), isTrue);

    navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Text('settings')),
    );
    await tester.pumpAndSettle();
    expect(container.read(homeRouteCurrentProvider), isFalse);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(container.read(homeRouteCurrentProvider), isTrue);
  });
}

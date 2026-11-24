import 'package:flutter/material.dart' hide BackButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/core/widgets/custom_app_bar.dart';
import 'package:lantern/core/widgets/search_bar.dart';

void main() {
  tearDown(() {
    PlatformUtils.isTv = false;
    PlatformUtils.debugTvShell = null;
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => Consumer(
                builder: (context, ref, _) => Scaffold(
                  appBar: AppSearchBar(
                    ref: ref,
                    title: 'Apps',
                    hintText: 'Search',
                  ),
                  body: const SizedBox(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('in the TV shell the bar matches CustomAppBar', (tester) async {
    PlatformUtils.isTv = true;
    PlatformUtils.debugTvShell = true;
    await pump(tester);
    final bar = tester.widget<AppSearchBar>(find.byType(AppSearchBar));
    expect(bar.preferredSize.height, tvToolbarHeight);
    expect(bar.leading, isA<BackButton>(),
        reason: 'the shared arrow sits in the leading slot');
    expect(find.byIcon(Icons.arrow_back_ios), findsNothing);
  });

  testWidgets('elsewhere the bar keeps its own arrow', (tester) async {
    await pump(tester);
    final bar = tester.widget<AppSearchBar>(find.byType(AppSearchBar));
    expect(bar.preferredSize.height, kToolbarHeight);
    expect(bar.leading, isNull);
    expect(find.byIcon(Icons.arrow_back_ios), findsOneWidget);
  });
}

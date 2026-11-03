import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/common.dart';

void main() {
  tearDown(() => PlatformUtils.isTv = false);

  testWidgets('on TV an external link is shown as a QR code to scan', (
    tester,
  ) async {
    PlatformUtils.isTv = true;
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: mobileSize,
        child: MaterialApp(
          theme: AppTheme.appTheme(),
          home: const Scaffold(body: Text('host')),
        ),
      ),
    );
    final context = tester.element(find.text('host'));
    UrlUtils.tryLaunchExternalUrl(context, Uri.parse('https://lantern.io/x'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tv.link.qr')), findsOneWidget);
    expect(find.text('https://lantern.io/x'), findsOneWidget);
    expect(find.text('open_on_another_device'.i18n), findsOneWidget);
  });

  test('off TV showLinkOnTv declines so the link launches normally', () async {
    expect(await UrlUtils.showLinkOnTv(null, 'https://lantern.io'), isFalse);
  });
}

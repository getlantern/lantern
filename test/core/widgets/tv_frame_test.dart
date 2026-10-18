import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/core/widgets/tv_frame.dart';

void main() {
  tearDown(() => PlatformUtils.isTv = false);

  Future<Size> childSize(WidgetTester tester) async {
    late Size size;
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      TvFrame(
        child: Builder(
          builder: (context) {
            size = MediaQuery.sizeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return size;
  }

  testWidgets('TV narrows the layout to a centered column', (tester) async {
    PlatformUtils.isTv = true;
    expect(await childSize(tester), const Size(tvContentMaxWidth, 540));
  });

  testWidgets('other devices keep the full screen', (tester) async {
    expect(await childSize(tester), const Size(960, 540));
  });
}

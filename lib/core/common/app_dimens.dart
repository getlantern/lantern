import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lantern/core/common/cap_scaling.dart';
import 'package:lantern/core/utils/platform_utils.dart';

const double iconSize = 24;
double font16 = 16.sp;
double font18 = 18.sp;

BorderRadius defaultBorderRadius = BorderRadius.circular(16.0.r);
EdgeInsets defaultPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 16);
const double defaultSize = 16.0;
const double size24 = 24.0;
const gap16 = SizedBox(height: 16);

// Window settings
const desktopWindowMinSize = Size(390, 750);
const desktopWindowSize = Size(390, 800);
const mobileSize = Size(360, 690);

/// Width of the centered phone-style column on TVs (landscape, ~960x540dp).
const double tvContentMaxWidth = 480;

/// Short screens get the compact layout from engineering#3046 (tighter
/// padding, pill upsell, combined rows). Desktop min height is 750.
bool isSmallScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 600;

/// Narrow-width phones (e.g. iPhone 12 mini at 375dp); width-based, unlike
/// [isSmallScreen].
bool isNarrowScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width <= 380;

Size designSizeFor(BuildContext context) {
  final s = MediaQuery.sizeOf(context);

  // TVs: TvFrame narrows the layout, but ScreenUtil measures the full View,
  // so design against the View's size to keep scaling at 1:1.
  if (PlatformUtils.isTv) {
    final view = View.of(context);
    return view.physicalSize / view.devicePixelRatio;
  }

  if (PlatformUtils.isDesktop) return desktopWindowSize;

  // tablets: don't scale up (use 1:1)
  if (isTabletSize(s)) return s;

  return mobileSize;
}

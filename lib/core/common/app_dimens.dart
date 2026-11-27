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

/// The TV two-panel shell (lib/core/widgets/tv_shell.dart) on its 960x540dp
/// canvas: 48/27dp safe margins, the logo-and-switch panel on the left, a
/// 1dp divider, then the screen's panel from [tvRightPanelX] to the right
/// safe margin (459dp wide at 960).
const double tvSafeMarginH = 48;
const double tvSafeMarginV = 27;
const double tvLeftPanelWidth = 340;
const double tvPanelGap = 32;
const double tvRightPanelX =
    tvSafeMarginH + tvLeftPanelWidth + tvPanelGap + 1 + tvPanelGap;

/// Header height in the TV shell: no status bar above it.
const double tvToolbarHeight = 44;

/// Width of the screen's panel in the TV shell, measured from the view so it
/// is right even where the shell has narrowed MediaQuery to the panel.
double tvRightPanelWidth(BuildContext context) {
  final view = View.of(context);
  final width = view.physicalSize.width / view.devicePixelRatio;
  return width - tvRightPanelX - tvSafeMarginH;
}

/// Short screens get the compact layout from engineering#3046 (tighter
/// padding, pill upsell, combined rows). Desktop min height is 750. The TV
/// shell's panel is 513dp tall but shows the regular rows (the Figma TV
/// frames), with the pill upsell chosen on its own.
bool isSmallScreen(BuildContext context) =>
    !PlatformUtils.tvShellEnabled && MediaQuery.sizeOf(context).height < 600;

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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const double kTabletShortestSide = 600;

/// Tablet heuristic used across the app
bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= kTabletShortestSide;

bool isTabletSize(Size size) => size.shortestSide >= kTabletShortestSide;

double spCap(BuildContext context, double base) {
  // phone: use sp, tablet: cap to base
  final scaled = base.sp;
  return isTablet(context) ? math.min(scaled, base) : scaled;
}

double hCap(BuildContext context, double base) {
  final scaled = base.h;
  return isTablet(context) ? math.min(scaled, base) : scaled;
}

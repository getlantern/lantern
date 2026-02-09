import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;

double spCap(BuildContext context, double base) {
  // phone: use sp, tablet: cap to base
  final scaled = base.sp;
  return isTablet(context) ? math.min(scaled, base) : scaled;
}

double hCap(BuildContext context, double base) {
  final scaled = base.h;
  return isTablet(context) ? math.min(scaled, base) : scaled;
}

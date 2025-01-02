import 'dart:math';

import 'package:flutter/material.dart';

const double borderRadius = 8;
const double activeIconSize = 8;
const double iconSize = 24;
const double badgeSize = 36;
const double messageBarHeight = 59;
const double scrollBarRadius = 50;

const forceRTL = false;

bool isLTR(BuildContext context) =>
    !forceRTL && Directionality.of(context) == TextDirection.ltr;

Widget mirrorLTR({required BuildContext context, required Widget child}) =>
    Transform(
      alignment: Alignment.center,
      transform: Matrix4.rotationY(isLTR(context) ? 0 : pi),
      child: child,
    );

bool shouldScroll({
  required BuildContext context,
  required int numElements,
  required double elHeight,
}) {
  var height = MediaQuery.of(context).size.height;
  var padding = MediaQuery.of(context).padding;
  var safeHeight = height - padding.top - padding.bottom;
  var topBarHeight = elHeight;

  // TODO: needs to be tested
  return safeHeight - topBarHeight < numElements * elHeight;
}

double calculateStickerHeight(BuildContext context, int messageCount) {
  final conversationInnerHeight = MediaQuery.of(context).size.height -
      100.0 -
      100.0; // rough approximation for inner height - top bar height - message bar height
  final messageHeight =
      60.0; // rough approximation of how much space a message takes up, including paddings
  final minStickerHeight = 353.0;
  return max(
    minStickerHeight,
    conversationInnerHeight - ((messageCount - 1) * messageHeight),
  );
}

double appBarHeight = 56.0;

double defaultWarningBarHeight = 30.0;

BorderRadius defaultBorderRadius = BorderRadius.circular(6.0);

// From https://raw.githubusercontent.com/lekanbar/custom_rounded_rectangle_border/master/lib/custom_rounded_rectangle_border.dart,
// modified for null safety.

import 'dart:math';

import 'package:flutter/material.dart';

/// A rectangular border with rounded corners.
///
/// Typically used with [ShapeDecoration] to draw a box with a rounded
/// rectangle for which each side/corner has different specifications such as color, width....
///
///
/// See also:
///
///  * [RoundedRectangleBorder], which is similar to this class, but with less options to control the appearance of each side/corner.
///  * [BorderSide], which is used to describe each side of the box.
///  * [Border], which, when used with [BoxDecoration], can also
///    describe a rounded rectangle.
class CRoundedRectangleBorder extends ShapeBorder {
  /// Creates a custom rounded rectangle border.
  /// Custom meaning that every single side/corner is controlled individually
  /// which grants the possibility to leave out borders, give each border a different color...
  ///
  /// The arguments must not be null.
  const CRoundedRectangleBorder({
    this.startSide,
    this.endSide,
    this.topSide,
    this.bottomSide,
    this.topStartCornerSide,
    this.topEndCornerSide,
    this.bottomStartCornerSide,
    this.bottomEndCornerSide,
    this.borderRadius = BorderRadius.zero,
  });

  /// The style for the start side border.
  final BorderSide? startSide;

  /// The style for the end side border.
  final BorderSide? endSide;

  /// The style for the top side border.
  final BorderSide? topSide;

  /// The style for the bottom side border.
  final BorderSide? bottomSide;

  /// The style for the top start corner side border.
  final BorderSide? topStartCornerSide;

  /// The style for the top end corner side border.
  final BorderSide? topEndCornerSide;

  /// The style for the bottom start corner side border.
  final BorderSide? bottomStartCornerSide;

  /// The style for the bottom end corner side border.
  final BorderSide? bottomEndCornerSide;

  /// The radii for each corner.
  final BorderRadiusGeometry borderRadius;

  bool isRTL(TextDirection? textDirection) =>
      TextDirection.rtl == textDirection;

  BorderSide? leftSide(TextDirection? textDirection) =>
      isRTL(textDirection) ? endSide : startSide;

  BorderSide? rightSide(TextDirection? textDirection) =>
      isRTL(textDirection) ? startSide : endSide;

  BorderSide? topLeftCornerSide(TextDirection? textDirection) =>
      isRTL(textDirection) ? topEndCornerSide : topStartCornerSide;

  BorderSide? topRightCornerSide(TextDirection? textDirection) =>
      isRTL(textDirection) ? topStartCornerSide : topEndCornerSide;

  BorderSide? bottomLeftCornerSide(TextDirection? textDirection) =>
      isRTL(textDirection) ? bottomEndCornerSide : bottomStartCornerSide;

  BorderSide? bottomRightCornerSide(TextDirection? textDirection) =>
      isRTL(textDirection) ? bottomStartCornerSide : bottomEndCornerSide;

  BorderRadius borderRadiusResolved(TextDirection? textDirection) =>
      borderRadius.resolve(textDirection ?? TextDirection.ltr);

  double get biggestWidth => max(
        max(
          max(
            max(
              max(
                max(
                  max(topSide?.width ?? 0.0, endSide?.width ?? 0.0),
                  bottomSide?.width ?? 0.0,
                ),
                startSide?.width ?? 0.0,
              ),
              bottomEndCornerSide?.width ?? 0.0,
            ),
            bottomStartCornerSide?.width ?? 0.0,
          ),
          topEndCornerSide?.width ?? 0.0,
        ),
        topStartCornerSide?.width ?? 0.0,
      );

  @override
  EdgeInsetsGeometry get dimensions {
    return EdgeInsetsDirectional.all(biggestWidth);
  }

  @override
  ShapeBorder scale(double t) {
    return CRoundedRectangleBorder(
      topSide: topSide?.scale(t),
      startSide: startSide?.scale(t),
      bottomSide: bottomSide?.scale(t),
      endSide: endSide?.scale(t),
      topStartCornerSide: topStartCornerSide?.scale(t),
      topEndCornerSide: topEndCornerSide?.scale(t),
      bottomStartCornerSide: bottomStartCornerSide?.scale(t),
      bottomEndCornerSide: bottomEndCornerSide?.scale(t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  ShapeBorder lerpFrom(ShapeBorder? a, double t) {
    if (a is CRoundedRectangleBorder) {
      return CRoundedRectangleBorder(
        topSide:
            topSide == null ? null : BorderSide.lerp(a.topSide!, topSide!, t),
        startSide: startSide == null
            ? null
            : BorderSide.lerp(a.startSide!, startSide!, t),
        bottomSide: bottomSide == null
            ? null
            : BorderSide.lerp(a.bottomSide!, bottomSide!, t),
        endSide:
            endSide == null ? null : BorderSide.lerp(a.endSide!, endSide!, t),
        topStartCornerSide: topStartCornerSide == null
            ? null
            : BorderSide.lerp(a.topStartCornerSide!, topStartCornerSide!, t),
        topEndCornerSide: topEndCornerSide == null
            ? null
            : BorderSide.lerp(a.topEndCornerSide!, topEndCornerSide!, t),
        bottomStartCornerSide: bottomStartCornerSide == null
            ? null
            : BorderSide.lerp(
                a.bottomStartCornerSide!,
                bottomStartCornerSide!,
                t,
              ),
        bottomEndCornerSide: bottomEndCornerSide == null
            ? null
            : BorderSide.lerp(a.bottomEndCornerSide!, bottomEndCornerSide!, t),
        borderRadius:
            BorderRadiusGeometry.lerp(a.borderRadius, borderRadius, t)!,
      );
    }
    return super.lerpFrom(a, t)!;
  }

  @override
  ShapeBorder lerpTo(ShapeBorder? b, double t) {
    if (b is CRoundedRectangleBorder) {
      return CRoundedRectangleBorder(
        topSide:
            topSide == null ? null : BorderSide.lerp(topSide!, b.topSide!, t),
        startSide: startSide == null
            ? null
            : BorderSide.lerp(startSide!, b.startSide!, t),
        bottomSide: bottomSide == null
            ? null
            : BorderSide.lerp(bottomSide!, b.bottomSide!, t),
        endSide:
            endSide == null ? null : BorderSide.lerp(endSide!, b.endSide!, t),
        topStartCornerSide: topStartCornerSide == null
            ? null
            : BorderSide.lerp(topStartCornerSide!, b.topStartCornerSide!, t),
        topEndCornerSide: topEndCornerSide == null
            ? null
            : BorderSide.lerp(topEndCornerSide!, b.topEndCornerSide!, t),
        bottomStartCornerSide: bottomStartCornerSide == null
            ? null
            : BorderSide.lerp(
                bottomStartCornerSide!,
                b.bottomStartCornerSide!,
                t,
              ),
        bottomEndCornerSide: bottomEndCornerSide == null
            ? null
            : BorderSide.lerp(bottomEndCornerSide!, b.bottomEndCornerSide!, t),
        borderRadius:
            BorderRadiusGeometry.lerp(borderRadius, b.borderRadius, t)!,
      );
    }
    return super.lerpTo(b, t)!;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..addRRect(
        borderRadius.resolve(textDirection).toRRect(rect).deflate(biggestWidth),
      );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(borderRadius.resolve(textDirection).toRRect(rect));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    var borderRadius = borderRadiusResolved(textDirection);
    Paint? paint;

    paint = createPaintForBorder(topLeftCornerSide(textDirection));
    if (borderRadius.topLeft.x != 0.0 && paint != null) {
      canvas.drawArc(
        rectForCorner(
          topLeftCornerSide(textDirection)?.width,
          rect.topLeft,
          borderRadius.topLeft,
          1,
          1,
        ),
        pi / 2 * 2,
        pi / 2,
        false,
        paint,
      );
    }

    paint = createPaintForBorder(topSide);
    if (paint != null) {
      canvas.drawLine(
        rect.topLeft +
            Offset(
              borderRadius.topLeft.x +
                  (borderRadius.topLeft.x == 0
                      ? (leftSide(textDirection)?.width ?? 0.0)
                      : 0.0),
              (topSide?.width ?? 0.0) / 2,
            ),
        rect.topRight +
            Offset(-borderRadius.topRight.x, (topSide?.width ?? 0.0) / 2),
        paint,
      );
    }

    paint = createPaintForBorder(topRightCornerSide(textDirection));
    if (borderRadius.topRight.x != 0.0 && paint != null) {
      canvas.drawArc(
        rectForCorner(
          topRightCornerSide(textDirection)?.width,
          rect.topRight,
          borderRadius.topRight,
          -1,
          1,
        ),
        pi / 2 * 3,
        pi / 2,
        false,
        paint,
      );
    }

    paint = createPaintForBorder(rightSide(textDirection));
    if (paint != null) {
      canvas.drawLine(
        rect.topRight +
            Offset(
              -1 * (rightSide(textDirection)?.width ?? 0.0) / 2,
              borderRadius.topRight.y +
                  (borderRadius.topRight.x == 0
                      ? (topSide?.width ?? 0.0)
                      : 0.0),
            ),
        rect.bottomRight +
            Offset(
              -1 * (rightSide(textDirection)?.width ?? 0.0) / 2,
              -borderRadius.bottomRight.y,
            ),
        paint,
      );
    }

    paint = createPaintForBorder(bottomRightCornerSide(textDirection));
    if (borderRadius.bottomRight.x != 0.0 && paint != null) {
      canvas.drawArc(
        rectForCorner(
          bottomRightCornerSide(textDirection)?.width,
          rect.bottomRight,
          borderRadius.bottomRight,
          -1,
          -1,
        ),
        pi / 2 * 0,
        pi / 2,
        false,
        paint,
      );
    }

    paint = createPaintForBorder(bottomSide);
    if (paint != null) {
      canvas.drawLine(
        rect.bottomRight +
            Offset(
              -borderRadius.bottomRight.x -
                  (borderRadius.bottomRight.x == 0
                      ? (rightSide(textDirection)?.width ?? 0.0)
                      : 0.0),
              -1 * (bottomSide?.width ?? 0.0) / 2,
            ),
        rect.bottomLeft +
            Offset(
              borderRadius.bottomLeft.x,
              -1 * (bottomSide?.width ?? 0.0) / 2,
            ),
        paint,
      );
    }

    paint = createPaintForBorder(bottomLeftCornerSide(textDirection));
    if (borderRadius.bottomLeft.x != 0.0 && paint != null) {
      canvas.drawArc(
        rectForCorner(
          bottomLeftCornerSide(textDirection)?.width,
          rect.bottomLeft,
          borderRadius.bottomLeft,
          1,
          -1,
        ),
        pi / 2 * 1,
        pi / 2,
        false,
        paint,
      );
    }

    paint = createPaintForBorder(leftSide(textDirection));
    if (paint != null) {
      canvas.drawLine(
        rect.bottomLeft +
            Offset(
              (leftSide(textDirection)?.width ?? 0.0) / 2,
              -borderRadius.bottomLeft.y -
                  (borderRadius.bottomLeft.x == 0
                      ? (bottomSide?.width ?? 0.0)
                      : 0.0),
            ),
        rect.topLeft +
            Offset(
              (leftSide(textDirection)?.width ?? 0.0) / 2,
              borderRadius.topLeft.y,
            ),
        paint,
      );
    }
  }

  Rect rectForCorner(
    double? sideWidth,
    Offset offset,
    Radius radius,
    num signX,
    num signY,
  ) {
    sideWidth ??= 0.0;
    var d = sideWidth / 2;
    var borderRadiusX = radius.x - d;
    var borderRadiusY = radius.y - d;
    var rect = Rect.fromPoints(
      offset + Offset(signX.sign * d, signY.sign * d),
      offset +
          Offset(signX.sign * d, signY.sign * d) +
          Offset(
            signX.sign * 2 * borderRadiusX,
            signY.sign * 2 * borderRadiusY,
          ),
    );

    return rect;
  }

  Paint? createPaintForBorder(BorderSide? side) {
    if (side == null) {
      return null;
    }

    return Paint()
      ..style = PaintingStyle.stroke
      ..color = side.color
      ..strokeWidth = side.width;
  }
}

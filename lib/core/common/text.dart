import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lantern/core/common/colors.dart';
import 'package:lantern/core/utils/add_nonbreaking_spaces.dart';

class CText extends StatelessWidget {
  late final String text;
  final CTextStyle style;
  final TextAlign? textAlign;
  late final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;

  /// A replacement for Text that includes the ability to auto-scale text and
  /// smartly place ellipses for single-line text (workaround for
  /// Flutter bug https://github.com/flutter/flutter/issues/18761).
  ///
  /// To auto-scale text, make sure to supply a style that includes a
  /// minFontSize in addition to a fontSize.
  ///
  /// To get smart ellipses, make sure to specify maxLines = 1.
  CText(
    String text, {
    required this.style,
    this.textAlign,
    TextOverflow? overflow,
    this.maxLines,
    this.softWrap,
  }) {
    // Workaround for https://github.com/flutter/flutter/issues/18761
    this.text = maxLines == 1 ? addNonBreakingSpaces(text) : text;
    this.overflow =
        overflow ?? (maxLines != null ? TextOverflow.ellipsis : null);
  }

  @override
  Widget build(BuildContext context) {
    if (style.minFontSize == null) {
      // Can't do special auto-scaling, just return regular Text
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        overflow: overflow,
        maxLines: maxLines,
        softWrap: softWrap,
      );
    }

    // autoscale
    // NOTE: this can clash with IntrinsicWidth - see more here https://github.com/leisim/auto_size_text/issues/77
    // Slack discussion https://wdynhnkxvsdx.slack.com/archives/C01K9DJ1ES2/p1643380315934109?thread_ts=1643317647.162100&cid=C01K9DJ1ES2
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final fontSize = _fontSizeFor(context, constraints.maxWidth);
        // scale height to keep line height the same even though font size changed
        var newLineHeight = style.lineHeight;
        if (style.fontSize != null) {
          newLineHeight = style.lineHeight * fontSize / style.fontSize!;
        }
        return Text(
          text,
          style: style.copiedWith(
            fontSize: fontSize,
            minFontSize: 0,
            lineHeight: newLineHeight,
          ),
          textAlign: textAlign,
          overflow: overflow,
          maxLines: maxLines,
          softWrap: softWrap,
        );
      },
    );
  }

  double _fontSizeFor(BuildContext context, double maxWidth) {
    final maxFontSize = style.fontSize!;

    var textPainter = TextPainter(
      maxLines: 1,
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
    );
    textPainter.layout();
    final widthRatio = maxWidth / textPainter.width;
    if (widthRatio >= 1) {
      // we've got enough room
      return maxFontSize;
    }
    // Need to scale down, rounded down by to the nearest even font size
    final targetSize = (widthRatio * maxFontSize / 2).floor() * 2;
    return max(targetSize.toDouble(), style.minFontSize!);
  }
}

/// Extends TextStyle to support a minFontSize for responsive text rendering.
///
/// If minFontSize is set, CustomTextStyle requires that fontSize and height
/// also be set and that fontSize be greater than minFontSize.
///
/// Instead of height, this takes a more useful lineHeight, which sets the
/// height to lineHeight / fontSize.
class CTextStyle extends TextStyle {
  final double? minFontSize;
  final double lineHeight;

  CTextStyle({
    bool inherit = true,
    Color? color,
    Color? backgroundColor,
    required double fontSize,
    required this.lineHeight,
    this.minFontSize,
    FontWeight fontWeight = FontWeight.w400,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    TextLeadingDistribution? leadingDistribution,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    String? debugLabel,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    String? package,
  }) : super(
          inherit: inherit,
          color: color ?? black,
          backgroundColor: backgroundColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          letterSpacing: letterSpacing,
          wordSpacing: wordSpacing,
          textBaseline: textBaseline,
          height: lineHeight / fontSize,
          leadingDistribution: leadingDistribution,
          locale: locale,
          foreground: foreground,
          background: background,
          shadows: shadows,
          fontFeatures: fontFeatures,
          decoration: decoration,
          decorationColor: decorationColor,
          decorationStyle: decorationStyle,
          decorationThickness: decorationThickness,
          debugLabel: debugLabel,
          fontFamily: fontFamily,
        ) {
    assert(
      (minFontSize ?? 0) <= fontSize,
      'fontSize $fontSize, minFontSize is $minFontSize, please set minFontSize to something less than or equal to fontSize',
    );
  }

  CTextStyle get short => copiedWith(lineHeight: fontSize);

  CTextStyle get italic => copiedWith(fontStyle: FontStyle.italic);

  CTextStyle copiedWith({
    bool? inherit,
    Color? color,
    Color? backgroundColor,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    double? fontSize,
    double? lineHeight,
    double? minFontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    TextLeadingDistribution? leadingDistribution,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<Shadow>? shadows,
    List<FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    String? debugLabel,
  }) {
    String? newDebugLabel;
    assert(
      () {
        if (this.debugLabel != null) {
          newDebugLabel = debugLabel ?? '(${this.debugLabel}).copyWith';
        }
        return true;
      }(),
    );
    return CTextStyle(
      inherit: inherit ?? this.inherit,
      color: this.foreground == null && foreground == null
          ? color ?? this.color
          : null,
      backgroundColor: this.background == null && background == null
          ? backgroundColor ?? this.backgroundColor
          : null,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      fontSize: fontSize ?? this.fontSize!,
      lineHeight: lineHeight ?? this.lineHeight,
      minFontSize: minFontSize ?? this.minFontSize,
      fontWeight: fontWeight ?? this.fontWeight!,
      fontStyle: fontStyle ?? this.fontStyle,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      textBaseline: textBaseline ?? this.textBaseline,
      leadingDistribution: leadingDistribution ?? this.leadingDistribution,
      locale: locale ?? this.locale,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      shadows: shadows ?? this.shadows,
      fontFeatures: fontFeatures ?? this.fontFeatures,
      decoration: decoration ?? this.decoration,
      decorationColor: decorationColor ?? this.decorationColor,
      decorationStyle: decorationStyle ?? this.decorationStyle,
      decorationThickness: decorationThickness ?? this.decorationThickness,
      debugLabel: newDebugLabel,
    );
  }
}

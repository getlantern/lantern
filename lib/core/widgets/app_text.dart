import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';

class HeaderText extends StatelessWidget {
  final String text;
  final TextAlign? textAlign;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final int? maxLines;
  final TextOverflow? overflow;

  const HeaderText(
    this.text, {
    super.key,
    this.textAlign,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Text(
      text,
      style: textTheme.labelLarge?.copyWith(color: AppColors.gray8),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

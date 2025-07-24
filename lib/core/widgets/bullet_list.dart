// Bullet point info rows
import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class BulletList extends StatelessWidget {
  final List<String> items;
  final Color? bulletColor;
  final TextStyle? textStyle;

  const BulletList({
    super.key,
    required this.items,
    this.bulletColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7, left: 16.0),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: bulletColor ?? AppColors.gray8,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: textStyle ?? textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

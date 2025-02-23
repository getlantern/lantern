import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_text_styles.dart';

class AppVersion extends StatelessWidget {
  final String version;

  const AppVersion({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Lantern Version',
            style: AppTestStyles.bodyMedium.copyWith(
              height: 23 / 14,
              letterSpacing: 0,
            ),
          ),
          Text(
            version,
            style: AppTestStyles.titleSmall.copyWith(
              height: 20 / 14,
              letterSpacing: 0,
              color: Color(0xFF005F61),
            ),
          ),
        ],
      ),
    );
  }
}

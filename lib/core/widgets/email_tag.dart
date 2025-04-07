import 'package:flutter/material.dart';

import '../common/app_colors.dart';
import '../common/common.dart';

class EmailTag extends StatelessWidget {
  final String email;

  const EmailTag({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        color: AppColors.blue1,
        border: Border.all(
          width: 1,
          color: AppColors.gray3,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          AppImage(
            path: AppImagePaths.email,
          ),
          const SizedBox(width: 8),
          Text(email)
        ],
      ),
    );
  }
}

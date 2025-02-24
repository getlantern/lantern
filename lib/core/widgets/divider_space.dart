import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_dimens.dart';

import '../common/app_colors.dart';

class DividerSpace extends StatelessWidget {
  const DividerSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppColors.gray2,
      height: 1,
    );
  }
}

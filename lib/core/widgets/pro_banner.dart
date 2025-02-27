import 'package:flutter/material.dart';

import '../common/common.dart';

class ProBanner extends StatelessWidget {
  final String? title;

  const ProBanner({
    super.key,
     this.title,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
     return Container(
      padding: EdgeInsets.all(defaultSize),
      decoration: BoxDecoration(
          color: AppColors.yellow1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.yellow4, width: 1)),
      child: Column(
        children: [
          Text(
            title??"Get unlimited data, no ads, and faster speeds!",
            style: textTheme.labelLarge!.copyWith(
              color: AppColors.gray9,
            ),
          ),
          SizedBox(height: 8),
          ProButton(
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

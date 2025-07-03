import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:lantern/core/widgets/pro_button.dart';

import '../common/common.dart';

class ProBanner extends StatelessWidget {
  final String? title;

  final double topMargin;

  const ProBanner({
    super.key,
    this.title,
    this.topMargin = 16,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: EdgeInsets.only(top: topMargin),
      padding: EdgeInsets.all(defaultSize),
      decoration: BoxDecoration(
          color: AppColors.yellow1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.yellow4, width: 1)),
      child: Column(
        children: [
          AutoSizeText(
            title ?? "Get unlimited data, no ads, and faster speeds!",
            maxLines: 1,
            minFontSize: 14,
            maxFontSize: 16,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium!.copyWith(
              color: AppColors.gray9,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          ProButton(
            onPressed: () {
              appRouter.push(Plans());
            },
          ),
        ],
      ),
    );
  }
}

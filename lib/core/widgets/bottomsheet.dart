import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';
import 'package:lantern/core/widgets/divider_space.dart';

typedef BottomSheetBuilder = Function(
    BuildContext context, ScrollController scrollController);

void showAppBottomSheet({
  required BuildContext context,
  required BottomSheetBuilder builder,
  required String title,
  double scrollControlDisabledMaxHeightRatio =.75
}) {
  final textTheme = Theme.of(context).textTheme.headlineSmall;
  showModalBottomSheet(
    context: context,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    backgroundColor: AppColors.white,
    scrollControlDisabledMaxHeightRatio:scrollControlDisabledMaxHeightRatio,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: true,
        initialChildSize: 1,
        minChildSize: 0.85,
        snap: true,
        builder: (BuildContext context, ScrollController scrollController) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  style: textTheme!.copyWith(
                    color: AppColors.blue10,
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: DividerSpace(),
              ),
              builder(context, scrollController),
            ],
          );
          return builder(context, scrollController);
        },
      );
    },
  );
}

// return Column(
// mainAxisSize: MainAxisSize.min,
// mainAxisAlignment: MainAxisAlignment.start,
// crossAxisAlignment: CrossAxisAlignment.start,
// children: <Widget>[
// Padding(
// padding: const EdgeInsets.symmetric(horizontal: 16),
// child: Text(
// 'language'.i18n,
// style: textTheme!.copyWith(
// color: AppColors.blue10,
// ),
// ),
// ),
// Padding(
// padding:
// const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
// child: DividerSpace(),
// ),
// Expanded(
// child: LanguageListView(
// scrollController: scrollController,
// ),
// ),
// ],
// );

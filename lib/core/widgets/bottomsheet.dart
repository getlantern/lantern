import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/widgets/divider_space.dart';

typedef BottomSheetBuilder = Function(
    BuildContext context, ScrollController scrollController);

void showAppBottomSheet(
    {required BuildContext context,
    required BottomSheetBuilder builder,
    required String title,
    double scrollControlDisabledMaxHeightRatio = .75}) {
  // backgroundColor and shape come from bottomSheetTheme in app_theme.dart
  showModalBottomSheet(
    context: context,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
    builder: (context) {
      return DraggableScrollableSheet(
        expand: true,
        initialChildSize: 1,
        minChildSize: 0.85,
        builder: (BuildContext context, ScrollController scrollController) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                        color: context.textPrimary,
                      ),
                ),
              ),
              DividerSpace(padding: EdgeInsets.only(top: 16)),
              builder(context, scrollController),
            ],
          );
        },
      );
    },
  );
}

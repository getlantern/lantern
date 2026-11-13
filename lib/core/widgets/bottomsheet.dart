import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/widgets/app_focusable.dart';
import 'package:lantern/core/widgets/divider_space.dart';

typedef BottomSheetBuilder = Function(
    BuildContext context, ScrollController scrollController);

/// A modal sheet with the app's title, optional [subtitle] and divider, then
/// [builder]'s content. By default it opens at [scrollControlDisabledMaxHeightRatio]
/// of the screen and the content scrolls inside; with [fitContent] it is only
/// as tall as its content, up to that same ratio, so a short list leaves no
/// dead space below it.
void showAppBottomSheet({
  required BuildContext context,
  required BottomSheetBuilder builder,
  required String title,
  Widget? subtitle,
  double scrollControlDisabledMaxHeightRatio = .75,
  Color? backgroundColor,
  bool fitContent = false,
}) {
  // backgroundColor (unless given) and shape come from bottomSheetTheme in
  // app_theme.dart
  showModalBottomSheet(
    context: context,
    backgroundColor: backgroundColor,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
    builder: (context) {
      focusFirstOnTv(context);
      if (fitContent) {
        return _ContentSheet(title: title, subtitle: subtitle, builder: builder);
      }
      return DraggableScrollableSheet(
        expand: true,
        initialChildSize: 1,
        minChildSize: 0.85,
        builder: (BuildContext context, ScrollController scrollController) =>
            _sheetColumn(
              context,
              title: title,
              subtitle: subtitle,
              child: builder(context, scrollController),
            ),
      );
    },
  );
}

Widget _sheetColumn(
  BuildContext context, {
  required String title,
  required Widget? subtitle,
  required Widget child,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall!.copyWith(color: context.textPrimary),
        ),
      ),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: subtitle,
        ),
      DividerSpace(padding: EdgeInsets.only(top: 16)),
      child,
    ],
  );
}

/// The content-sized sheet: it owns the scroll controller the content scrolls
/// with once it is taller than the sheet's maximum.
class _ContentSheet extends StatefulWidget {
  const _ContentSheet({
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final String title;
  final Widget? subtitle;
  final BottomSheetBuilder builder;

  @override
  State<_ContentSheet> createState() => _ContentSheetState();
}

class _ContentSheetState extends State<_ContentSheet> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _sheetColumn(
    context,
    title: widget.title,
    subtitle: widget.subtitle,
    child: widget.builder(context, _scrollController),
  );
}

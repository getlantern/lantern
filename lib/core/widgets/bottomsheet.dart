import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/common/app_semantic_colors.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/core/widgets/app_focusable.dart';
import 'package:lantern/core/widgets/divider_space.dart';
import 'package:lantern/core/widgets/tv_shell.dart';

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
  //
  // In the TV shell the sheet is confined to the screen's panel (Figma
  // "Server Locations / Bottom sheet open"): the modal's own surface and drag
  // handle span the whole screen, so they are dropped and drawn inside the
  // panel-wide box instead, while the modal barrier still dims everything.
  // Opened from a full-screen route (no panel), the box sits under that
  // route's centred column instead.
  final tvShell = PlatformUtils.tvShellEnabled;
  final inPanel =
      tvShell && context.findAncestorWidgetOfExactType<TvShell>() != null;
  showModalBottomSheet(
    context: context,
    backgroundColor: tvShell ? Colors.transparent : backgroundColor,
    // Material 3 caps a sheet at 640dp and centres it; the panel-wide box
    // below needs the whole width to sit over the screen's panel.
    constraints: tvShell
        ? const BoxConstraints(maxWidth: double.infinity)
        : null,
    isDismissible: true,
    enableDrag: !tvShell,
    showDragHandle: !tvShell,
    scrollControlDisabledMaxHeightRatio: scrollControlDisabledMaxHeightRatio,
    builder: (context) {
      focusFirstOnTv(context);
      final Widget content;
      if (fitContent) {
        content = _ContentSheet(
          title: title,
          subtitle: subtitle,
          builder: builder,
        );
      } else {
        content = DraggableScrollableSheet(
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
      }
      if (!tvShell) return content;
      return _tvPanelSheet(context, backgroundColor, content, inPanel: inPanel);
    },
  );
}

Widget _tvPanelSheet(
  BuildContext context,
  Color? backgroundColor,
  Widget child, {
  required bool inPanel,
}) {
  final sheetTheme = Theme.of(context).bottomSheetTheme;
  // The modal's own sheet spans the whole width and swallows taps even
  // where it is transparent, so a tap beside the box dismisses here; the
  // box keeps its taps to itself.
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => Navigator.of(context).pop(),
    child: Align(
      alignment: inPanel ? Alignment.bottomRight : Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(right: inPanel ? tvSafeMarginH : 0),
        child: SizedBox(
          width: inPanel ? tvRightPanelWidth(context) : tvContentMaxWidth,
          child: GestureDetector(
            onTap: () {},
            child: Material(
              key: const Key('bottomsheet.tv_box'),
              color:
                  backgroundColor ??
                  sheetTheme.modalBackgroundColor ??
                  sheetTheme.backgroundColor,
              shape: sheetTheme.shape,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
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

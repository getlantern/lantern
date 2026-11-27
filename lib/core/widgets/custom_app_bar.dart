import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';
import 'package:lantern/core/common/app_dimens.dart';
import 'package:lantern/core/common/app_image_paths.dart';
import 'package:lantern/core/utils/platform_utils.dart';
import 'package:lantern/core/widgets/app_focusable.dart';

class CustomAppBar extends AppBar {
  @override
  final Widget? title;
  @override
  final Widget? leading;

  // This field shadows AppBar's, so off TV a null leading leaves Material's
  // implied back button in charge, as it always has. The TV shell gives the
  // arrow its own widget (focusable, never the first focus) on a slimmer
  // bar, since there is no status bar above it.
  CustomAppBar({
    super.key,
    required this.title,
    Widget? leading,
    super.actions,
    super.actionsPadding,
    super.backgroundColor,
  }) : leading =
           leading ??
           (PlatformUtils.tvShellEnabled ? const BackButton() : null),
       super(
         title: title,
         leading: leading ?? const BackButton(),
         toolbarHeight: PlatformUtils.tvShellEnabled
             ? tvToolbarHeight
             : kToolbarHeight,
         elevation: 0,
       );

  @override
  Size get preferredSize => Size.fromHeight(
    PlatformUtils.tvShellEnabled ? tvToolbarHeight : kToolbarHeight,
  );
}

class BackButton extends StatelessWidget {
  final Color? color;
  final double size;

  /// What the arrow does; pops the route when null.
  final VoidCallback? onPressed;

  const BackButton({super.key, this.color, this.size = 24, this.onPressed});

  @override
  Widget build(BuildContext context) {
    // Like Material's implied button, nothing to go back to means no arrow,
    // unless the caller gave it something else to do.
    if (PlatformUtils.tvShellEnabled &&
        onPressed == null &&
        !(ModalRoute.of(context)?.canPop ?? false)) {
      return const SizedBox.shrink();
    }
    // A TV screen opens on its first row, not on the arrow (the remote's
    // Back does the same); the arrow is still reachable with Up.
    return TvNotInitialFocus(
      child: IconButton(
        // The glyph points back, which in a right-to-left locale is right.
        icon: Transform.flip(
          flipX: Directionality.of(context) == TextDirection.rtl,
          child: AppImage(
            path: AppImagePaths.arrowBack,
            width: size,
            height: size,
            color: color ?? Theme.of(context).iconTheme.color,
          ),
        ),
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        splashRadius: 24,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      ),
    );
  }
}

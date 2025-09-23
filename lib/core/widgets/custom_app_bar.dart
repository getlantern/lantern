import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_asset.dart';

class CustomAppBar extends AppBar {
  @override
  final Widget? title;
  @override
  final Widget? leading;

  CustomAppBar({
    super.key,
    required this.title,
    this.leading,
    super.actions,
    super.actionsPadding,
    super.backgroundColor,
  }) : super(
          title: title,
          leading: leading ?? const BackButton(),
          elevation: 0,
        );

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class BackButton extends StatelessWidget {
  final Color? color;
  final double size;

  const BackButton({super.key, this.color, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: AppImage(
        path: 'assets/icons/arrow_back.svg',
        width: size,
        height: size,
        color: color ?? Theme.of(context).iconTheme.color,
      ),
      onPressed: () => Navigator.of(context).maybePop(),
      splashRadius: 24,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
    );
  }
}

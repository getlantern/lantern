import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lantern/core/common/app_asset.dart';

class CustomAppBar extends AppBar {
  final Widget? title;
  final Widget? leading;

  CustomAppBar({
    super.key,
    required this.title,
    this.leading,
    super.actions,
    super.actionsPadding,
    super.backgroundColor,
  }) : super(
          title: title.runtimeType == String
              ? Text(title as String)
              : title as Widget,
          leading: leading ?? const BackButton(),
          elevation: 0,
        );

  @override
  Size get preferredSize => Size.fromHeight(80);
}

class BackButton extends StatelessWidget {
  final Color? color;
  final double size;

  const BackButton({Key? key, this.color, this.size = 24}) : super(key: key);

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

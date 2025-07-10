import 'package:flutter/material.dart';
import 'package:lantern/core/common/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Object title;
  final Widget? leading;

  const CustomAppBar({
    super.key,
    required this.title,
    // super.actions,
    // super.actionsPadding,
    this.leading,
    // super.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      color: AppColors.white,
      child: Stack(
        children: [
          // Pin title & icon to bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Row(
              children: [
                if (leading != null) leading!,
                title.runtimeType == String
                    ? Expanded(
                        child: Text(
                          title as String,
                        ),
                      )
                    : title as Widget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(80);
}

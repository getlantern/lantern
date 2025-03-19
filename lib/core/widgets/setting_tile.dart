import 'package:flutter/material.dart';

import '../common/common.dart';

class SettingTile extends StatelessWidget {
  final String label;
  final String value;

  final Widget? child;

  final String icon;

  final List<Widget> actions;

  final VoidCallback? onTap;

  const SettingTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.actions,
    this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      splashColor: AppColors.gray2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 24,
                  child: AppImage(path: icon),
                ),
                SizedBox(width: 8),
                Text(label,
                    style:
                        textTheme.labelLarge!.copyWith(color: AppColors.gray7)),
              ],
            ),
            Row(
              children: [
                SizedBox(width: 32.0),
                if (child != null)
                  child!
                else
                  Text(value,
                      style: textTheme.titleMedium!
                          .copyWith(color: AppColors.gray9)),
                Spacer(),
                ...actions
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

import '../common/app_asset.dart';
import '../common/app_dimens.dart';
import '../common/app_semantic_colors.dart';
import '../extensions/string.dart';
import 'app_focusable.dart';

class SettingTile extends StatelessWidget {
  final Key? tileKey;
  final String label;
  final String? subtitle;
  final String value;
  final Widget? child;
  final dynamic icon;
  final List<Widget> actions;
  final VoidCallback? onTap;
  final Color? subtitleColor;

  /// A short status line under [subtitle], shown as given.
  final String? note;
  final Color? noteColor;

  const SettingTile({
    super.key,
    this.tileKey,
    required this.label,
    required this.value,
    required this.icon,
    required this.actions,
    this.onTap,
    this.child,
    this.subtitle,
    this.subtitleColor,
    this.note,
    this.noteColor,
  });

  @override
  Widget build(BuildContext context) {
    final smallScreen = isSmallScreen(context);
    return TvFocusRing(
      borderRadius: BorderRadius.circular(16),
      builder: (context, focusNode) => InkWell(
        key: tileKey,
        focusNode: focusNode,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: context.bgCallout,
        child: _body(context, smallScreen),
      ),
    );
  }

  Widget _body(BuildContext context, bool smallScreen) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: smallScreen ? 8 : 10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SizedBox(
                width: 24,
                child: icon is String ? AppImage(path: icon) : icon as Widget,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: smallScreen ? null : 1,
                  overflow: smallScreen
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: textTheme.labelLarge!.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(width: 32.0),
              if (child != null)
                Expanded(child: child!)
              else
                Expanded(
                  child: AutoSizeText(
                    value,
                    maxLines: smallScreen ? null : 1,
                    maxFontSize: 16,
                    minFontSize: 14,
                    style: textTheme.titleMedium!.copyWith(
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ...actions,
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 32.0),
              child: Text(
                subtitle!.capitalize,
                style: textTheme.labelLarge!.copyWith(
                  color: subtitleColor ?? context.textSecondary,
                ),
              ),
            ),
          if (note != null && note!.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 32.0),
              child: Text(
                note!,
                style: textTheme.labelLarge!.copyWith(
                  color: noteColor ?? context.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

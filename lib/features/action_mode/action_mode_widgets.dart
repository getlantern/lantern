import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/setting_tile.dart';
import 'package:lantern/core/widgets/switch_button.dart';

class ActionModeStatusCard extends StatelessWidget {
  const ActionModeStatusCard({
    super.key,
    required this.status,
    required this.enabled,
    required this.ready,
    required this.busy,
    required this.hasError,
    required this.activeCount,
    required this.totalCount,
    required this.onToggle,
    this.onInfo,
    this.onTotalTap,
  });

  final String status;
  final bool enabled, ready, busy, hasError;
  final int activeCount, totalCount;
  final VoidCallback onToggle;

  /// Reopens the Action Mode explainer from the icon beside the status.
  final VoidCallback? onInfo;

  /// Makes the total row tappable, with a chevron.
  final VoidCallback? onTotalTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusColor = hasError
        ? context.statusErrorText
        : ready
        ? (Theme.of(context).brightness == Brightness.dark
              ? AppColors.green3
              : AppColors.green6)
        : context.textTertiary;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Label over value like SettingTile, with the switch centred on
          // the whole block rather than on the value line.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 24,
                            child: AppImage(path: AppImagePaths.globGrid),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'smc_status_label'.i18n,
                            style: textTheme.labelLarge!.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                          if (onInfo != null)
                            IconButton(
                              key: const Key('action-mode.info'),
                              tooltip: 'about_unbounded'.i18n,
                              onPressed: onInfo,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              iconSize: 20,
                              icon: AppImage(
                                path: AppImagePaths.info,
                                width: 20,
                                height: 20,
                                color: context.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 32),
                          Flexible(
                            child: Text(
                              status,
                              style: textTheme.titleMedium?.copyWith(
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  key: const Key('action-mode.toggle'),
                  label: 'unbounded'.i18n,
                  toggled: enabled,
                  enabled: !busy,
                  child: AbsorbPointer(
                    absorbing: busy,
                    child: SwitchButton(
                      value: enabled,
                      onChanged: (_) {
                        if (!busy) onToggle();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const DividerSpace(),
          SettingTile(
            label: 'action_mode_helping_now'.i18n,
            value: peopleCountLabel(activeCount),
            icon: AppImagePaths.actionModePerson,
            actions: const [],
          ),
          const DividerSpace(),
          SettingTile(
            tileKey: const Key('action-mode.total-helped'),
            label: 'action_mode_total_helped'.i18n,
            subtitle: "view_advanced_stats".i18n,
            subtitleColor: context.textTertiary,
            value: peopleCountLabel(totalCount),
            icon: AppImagePaths.actionModePeople,
            onTap: onTotalTap,
            actions: [AppImage(path: AppImagePaths.arrowForward)],
          ),
        ],
      ),
    );
  }
}

/// "1 person", "5 people", "11,238 people".
String peopleCountLabel(int count) => count == 1
    ? 'advanced_stats_one_person'.i18n
    : 'advanced_stats_people'.i18n.fill([
        NumberFormat.decimalPattern().format(count),
      ]);

/// Desktop uses a horizontal pill strip; mobile uses a bottom navigation pill.
class ActionModeNavigation extends StatelessWidget {
  const ActionModeNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.vpnActive,
    required this.actionActive,
    required this.desktop,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool vpnActive, actionActive, desktop;

  /// Used by both the desktop strip and its AppBar so neither clips the label.
  static double desktopHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'unbounded'.i18n,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // Eight pixels of vertical padding on each side of the pill.
    final height = math.max(56.0, painter.height + 16);
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) => Container(
    height: desktop
        ? desktopHeight(context)
        : 64 + math.max(0, MediaQuery.textScalerOf(context).scale(14) - 14) * 2,
    padding: desktop
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
        : const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: context.bgElevated,
      borderRadius: BorderRadius.circular(desktop ? 0 : 9999),
      border: desktop ? null : Border.all(color: context.borderDefault),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 2; i++)
          Expanded(
            child: desktop
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final painter = TextPainter(
                        text: TextSpan(
                          text: (i == 0 ? 'vpn' : 'unbounded').i18n,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                        maxLines: 1,
                      )..layout();
                      // Icon, gaps, status dot, and the pill's inner padding.
                      final contentWidth = painter.width.ceilToDouble() + 56;
                      painter.dispose();
                      final preferredInset =
                          20 /
                          math.max(
                            1,
                            MediaQuery.textScalerOf(context).scale(14) / 14,
                          );
                      final inset = math.min(
                        preferredInset,
                        math.max(
                          0.0,
                          (constraints.maxWidth - contentWidth) / 2,
                        ),
                      );
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: inset),
                        child: _item(context, i),
                      );
                    },
                  )
                : _item(context, i),
          ),
      ],
    ),
  );

  Widget _item(BuildContext context, int index) {
    final selected = selectedIndex == index;
    final active = index == 0 ? vpnActive : actionActive;
    final color = selected
        ? context.actionTabbarSelectedText
        : context.actionTabbarDisabledText;
    final label = (index == 0 ? 'vpn' : 'unbounded').i18n;
    final icon = AppImage(
      path: index == 0
          ? (selected ? AppImagePaths.vpnKeyFill : AppImagePaths.vpnKey)
          : (selected ? AppImagePaths.handshakeFill : AppImagePaths.handshake),
      width: 24,
      height: 24,
      color: color,
    );
    final caption = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (!desktop && index == 1)
          Icon(
            Icons.sensors,
            size: 20,
            color: active ? AppColors.green6 : context.textDisabled,
          )
        else
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.green6 : context.textDisabled,
            ),
          ),
      ],
    );
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? context.actionTabbarBg : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
          side: BorderSide(
            color: selected ? context.actionTabbarBorder : Colors.transparent,
          ),
        ),
        child: InkWell(
          key: Key('action-mode.nav.$index'),
          borderRadius: BorderRadius.circular(9999),
          onTap: () => onSelected(index),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: desktop ? 4 : 8),
            child: desktop
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(width: 8),
                      Flexible(child: caption),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [icon, caption],
                  ),
          ),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lantern/core/common/common.dart';
import 'package:lantern/core/widgets/switch_button.dart';

/// Scrolls on small screens and with large accessibility text instead of
/// squeezing the globe or overflowing the controls.
class ActionModePanel extends StatelessWidget {
  const ActionModePanel({
    super.key,
    required this.globe,
    required this.statusCard,
    required this.autoEnable,
    required this.onAbout,
  });
  final Widget globe;
  final Widget statusCard;
  final Widget autoEnable;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.bgSurface,
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            children: [
              Material(
                color: context.bgElevated,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: context.borderDefault),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onAbout,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Tooltip(
                          message: 'about_unbounded'.i18n,
                          child: const AppImage(
                            path: AppImagePaths.info,
                            width: 24,
                            height: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'smc_intro'.i18n,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: context.textSecondary,
                                  height: 16 / 12,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: math.max(180, constraints.maxHeight - 336),
                child: globe,
              ),
              statusCard,
              const SizedBox(height: 8),
              autoEnable,
            ],
          ),
        );
      },
    ),
  );
}

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
  });
  final String status;
  final bool enabled, ready, busy, hasError;
  final int activeCount, totalCount;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyLarge;
    return AppCard(
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const AppImage(
                    path: AppImagePaths.glob,
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${'smc_status_label'.i18n}: '),
                          TextSpan(
                            text: status,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: hasError
                                  ? context.statusErrorText
                                  : ready
                                  ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.green3
                                        : AppColors.green6)
                                  : context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      style: body,
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
          ),
          Divider(height: 1, color: context.borderDefault),
          _ImpactRow(
            icon: AppImagePaths.actionModePerson,
            label: 'smc_stat_active_now'.i18n,
            value: activeCount,
          ),
          Divider(height: 1, color: context.borderDefault),
          _ImpactRow(
            icon: AppImagePaths.actionModePeople,
            label: 'smc_stat_total_helped'.i18n,
            value: totalCount,
          ),
        ],
      ),
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final String icon, label;
  final int value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 56),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AppImage(path: icon, width: 24, height: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          const SizedBox(width: 12),
          Text(
            '$value',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.textLink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}

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
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: desktop
                    ? 20 /
                          math.max(
                            1,
                            MediaQuery.textScalerOf(context).scale(14) / 14,
                          )
                    : 0,
              ),
              child: _item(context, i),
            ),
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
